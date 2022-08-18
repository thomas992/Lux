const std = @import("std");
const lux = @import("lux");

////
// Multi-environment communication example:
// In this example, we have three scripts:
// server.lux:   Exporting a simple key-value store
// client-a.lux: Writes "Hello, World!" into the store in server
// client-b.lux: Reads the message from the server and prints it
//
// Real world application:
// This shows the inter-environment communication capabilities of Lux,
// which is useful for games with interactive computer systems that need
// to interact with each other in a user-scriptable way.
//
// Each computer is its own environment, providing a simple script.
// Computers/Environments can communicate via a object interface, exposing
// other computers as a Lux object and allowing those environments to
// communicate with each other.
//

pub const ObjectPool = lux.runtime.ObjectPool([_]type{
    lux.libs.runtime.LuxDictionary,
    lux.libs.runtime.LuxList,

    // Environment is a non-serializable object. If you need to serialize a whole VM state with cross-references,
    // provide your own wrapper implementation
    lux.runtime.Environment,
});

pub fn main() anyerror!u8 {
    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_state.deinit();

    const allocator = gpa_state.allocator();

    var diagnostics = lux.compiler.Diagnostics.init(allocator);
    defer {
        for (diagnostics.messages.items) |msg| {
            std.debug.print("{}\n", .{msg});
        }
        diagnostics.deinit();
    }

    var server_unit = (try lux.compiler.compile(allocator, &diagnostics, "server.lux", @embedFile("server.lux"))) orelse return 1;
    defer server_unit.deinit();

    var client_a_unit = (try lux.compiler.compile(allocator, &diagnostics, "client-a.lux", @embedFile("client-a.lux"))) orelse return 1;
    defer client_a_unit.deinit();

    var client_b_unit = (try lux.compiler.compile(allocator, &diagnostics, "client-b.lux", @embedFile("client-b.lux"))) orelse return 1;
    defer client_b_unit.deinit();

    var pool = ObjectPool.init(allocator);
    defer pool.deinit();

    var server_env = try lux.runtime.Environment.init(allocator, &server_unit, pool.interface());
    defer server_env.deinit();

    var client_a_env = try lux.runtime.Environment.init(allocator, &client_a_unit, pool.interface());
    defer client_a_env.deinit();

    var client_b_env = try lux.runtime.Environment.init(allocator, &client_b_unit, pool.interface());
    defer client_b_env.deinit();

    for ([_]*lux.runtime.Environment{ &server_env, &client_a_env, &client_b_env }) |env| {
        try env.installModule(lux.libs.std, lux.runtime.Context.null_pointer);
        try env.installModule(lux.libs.runtime, lux.runtime.Context.null_pointer);
    }

    var server_obj_handle = try pool.createObject(&server_env);

    // Important: The environment is stored in the ObjectPool,
    // but will be destroyed earlier by us, so we have to remove it
    // from the pool before we destroy `server_env`!
    defer pool.destroyObject(server_obj_handle);

    const getServerFunction = lux.runtime.Function{
        .syncUser = .{
            .context = lux.runtime.Context.make(*lux.runtime.ObjectHandle, &server_obj_handle),
            .call = struct {
                fn call(
                    environment: *lux.runtime.Environment,
                    context: lux.runtime.Context,
                    args: []const lux.runtime.Value,
                ) anyerror!lux.runtime.Value {
                    _ = environment;
                    _ = args;
                    return lux.runtime.Value.initObject(context.cast(*lux.runtime.ObjectHandle).*);
                }
            }.call,
            .destructor = null,
        },
    };

    try client_a_env.installFunction("GetServer", getServerFunction);
    try client_b_env.installFunction("GetServer", getServerFunction);

    // First, initialize the server and let it initialize `storage`.
    {
        var vm = try lux.runtime.VM.init(allocator, &server_env);
        defer vm.deinit();

        const result = try vm.execute(null);
        if (result != .completed)
            return error.CouldNotCompleteCode;
    }

    // Then, let Client A execute
    {
        var vm = try lux.runtime.VM.init(allocator, &client_a_env);
        defer vm.deinit();

        const result = try vm.execute(null);
        if (result != .completed)
            return error.CouldNotCompleteCode;
    }

    // Then, let Client B execute
    {
        var vm = try lux.runtime.VM.init(allocator, &client_b_env);
        defer vm.deinit();

        const result = try vm.execute(null);
        if (result != .completed)
            return error.CouldNotCompleteCode;
    }

    return 0;
}
