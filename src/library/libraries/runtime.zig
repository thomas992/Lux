// This file implements the Lux Runtime Library.

const std = @import("std");
const builtin = @import("builtin");
const lux = @import("../main.zig");
const root = @import("root");

const GlobalObjectPool = if (builtin.is_test)
    // we need to do a workaround here for testing purposes
    lux.runtime.ObjectPool([_]type{
        LuxList,
        LuxDictionary,
    })
else if (@hasDecl(root, "ObjectPool"))
    root.ObjectPool
else
    @compileError("Please define and use a global ObjectPool type to use the runtime classes.");

comptime {
    if (builtin.is_test) {
        const T = lux.runtime.ObjectPool([_]type{
            LuxList,
            LuxDictionary,
        });

        if (!T.serializable)
            @compileError("Both LuxList and LuxDictionary must be serializable!");
    }
}

/// empty compile unit for testing purposes
const empty_compile_unit = lux.CompileUnit{
    .arena = std.heap.ArenaAllocator.init(std.testing.failing_allocator),
    .comment = "empty compile unit",
    .globalCount = 0,
    .temporaryCount = 0,
    .code = "",
    .functions = &[0]lux.CompileUnit.Function{},
    .debugSymbols = &[0]lux.CompileUnit.DebugSymbol{},
};

test "runtime.install" {
    var pool = GlobalObjectPool.init(std.testing.allocator);
    defer pool.deinit();

    var env = try lux.runtime.Environment.init(std.testing.allocator, &empty_compile_unit, pool.interface());
    defer env.deinit();

    try env.installModule(@This(), lux.runtime.Context.null_pointer);
}

// fn Sleep(call_context: lux.runtime.Context, args: []const lux.runtime.Value) anyerror!lux.runtime.AsyncFunctionCall {
//     const allocator = call_context.get(std.mem.Allocator);

//     if (args.len != 1)
//         return error.InvalidArgs;
//     const seconds = try args[0].toNumber();

//     const Context = struct {
//         allocator: std.mem.Allocator,
//         end_time: f64,
//     };

//     const ptr = try allocator.create(Context);
//     ptr.* = Context{
//         .allocator = allocator,
//         .end_time = @intToFloat(f64, std.time.milliTimestamp()) + 1000.0 * seconds,
//     };

//     return lux.runtime.AsyncFunctionCall{
//         .context = lux.runtime.Context.init(Context, ptr),
//         .destructor = struct {
//             fn dtor(exec_context: lux.runtime.Context) void {
//                 const ctx = exec_context.get(Context);
//                 ctx.allocator.destroy(ctx);
//             }
//         }.dtor,
//         .execute = struct {
//             fn execute(exec_context: lux.runtime.Context) anyerror!?lux.runtime.Value {
//                 const ctx = exec_context.get(Context);

//                 if (ctx.end_time < @intToFloat(f64, std.time.milliTimestamp())) {
//                     return .void;
//                 } else {
//                     return null;
//                 }
//             }
//         }.execute,
//     };
// }

pub fn Print(environment: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) anyerror!lux.runtime.Value {
    _ = environment;
    _ = context;

    var stdout = std.io.getStdOut().writer();
    for (args) |value| {
        switch (value) {
            .string => |str| try stdout.writeAll(str.contents),
            else => try stdout.print("{}", .{value}),
        }
    }
    try stdout.writeAll("\n");
    return .void;
}

pub fn Exit(environment: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) anyerror!lux.runtime.Value {
    _ = environment;
    _ = context;

    if (args.len != 1)
        return error.InvalidArgs;

    const status = try args[0].toInteger(u8);
    std.process.exit(status);
}

pub fn ReadFile(environment: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) anyerror!lux.runtime.Value {
    _ = environment;
    _ = context;

    if (args.len != 1)
        return error.InvalidArgs;

    const path = try args[0].toString();

    var file = std.fs.cwd().openFile(path, .{ .mode = .read_only }) catch return .void;
    defer file.close();

    // 2 GB
    var contents = try file.readToEndAlloc(environment.allocator, 2 << 30);

    return lux.runtime.Value.fromString(lux.runtime.String.initFromOwned(environment.allocator, contents));
}

pub fn FileExists(environment: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) anyerror!lux.runtime.Value {
    _ = environment;
    _ = context;

    if (args.len != 1)
        return error.InvalidArgs;

    const path = try args[0].toString();

    var file = std.fs.cwd().openFile(path, .{ .mode = .read_only }) catch return lux.runtime.Value.initBoolean(false);
    file.close();

    return lux.runtime.Value.initBoolean(true);
}

pub fn WriteFile(environment: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) anyerror!lux.runtime.Value {
    _ = environment;
    _ = context;

    if (args.len != 2)
        return error.InvalidArgs;

    const path = try args[0].toString();
    const value = try args[1].toString();

    var file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    try file.writeAll(value);

    return .void;
}

pub fn CreateList(environment: *lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) anyerror!lux.runtime.Value {
    _ = context;
    if (args.len > 1)
        return error.InvalidArgs;

    if (args.len > 0) _ = try args[0].toArray();

    const list = try environment.allocator.create(LuxList);
    errdefer environment.allocator.destroy(list);

    list.* = LuxList{
        .allocator = environment.allocator,
        .data = std.ArrayList(lux.runtime.Value).init(environment.allocator),
    };

    if (args.len > 0) {
        const array = args[0].toArray() catch unreachable;

        errdefer list.data.deinit();
        try list.data.resize(array.contents.len);

        for (list.data.items) |*item| {
            item.* = .void;
        }

        errdefer for (list.data.items) |*item| {
            item.deinit();
        };
        for (list.data.items) |*item, index| {
            item.* = try array.contents[index].clone();
        }
    }

    return lux.runtime.Value.initObject(
        try environment.objectPool.castTo(GlobalObjectPool).createObject(list),
    );
}

pub fn CreateDictionary(environment: *lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) anyerror!lux.runtime.Value {
    _ = context;
    if (args.len != 0)
        return error.InvalidArgs;

    const list = try environment.allocator.create(LuxDictionary);
    errdefer environment.allocator.destroy(list);

    list.* = LuxDictionary{
        .allocator = environment.allocator,
        .data = std.ArrayList(LuxDictionary.KV).init(environment.allocator),
    };

    return lux.runtime.Value.initObject(
        try environment.objectPool.castTo(GlobalObjectPool).createObject(list),
    );
}

pub const LuxList = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    data: std.ArrayList(lux.runtime.Value),

    pub fn getMethod(self: *Self, name: []const u8) ?lux.runtime.Function {
        inline for (comptime std.meta.declarations(funcs)) |decl| {
            if (std.mem.eql(u8, name, decl.name)) {
                return lux.runtime.Function{
                    .syncUser = .{
                        .context = lux.runtime.Context.make(*Self, self),
                        .call = @field(funcs, decl.name),
                        .destructor = null,
                    },
                };
            }
        }
        return null;
    }

    pub fn destroyObject(self: *Self) void {
        for (self.data.items) |*item| {
            item.deinit();
        }
        self.data.deinit();
        self.allocator.destroy(self);
    }

    pub fn serializeObject(writer: lux.runtime.OutputStream.Writer, object: *Self) !void {
        try writer.writeIntLittle(u32, @intCast(u32, object.data.items.len));
        for (object.data.items) |item| {
            try item.serialize(writer);
        }
    }

    pub fn deserializeObject(allocator: std.mem.Allocator, reader: lux.runtime.InputStream.Reader) !*Self {
        const item_count = try reader.readIntLittle(u32);
        var list = try allocator.create(Self);
        list.* = Self{
            .allocator = allocator,
            .data = std.ArrayList(lux.runtime.Value).init(allocator),
        };
        errdefer list.destroyObject(); // this will also free memory!

        try list.data.resize(item_count);

        // sane init to make destroyObject not explode
        // (deinit a void value is a no-op)
        for (list.data.items) |*item| {
            item.* = .void;
        }

        for (list.data.items) |*item| {
            item.* = try lux.runtime.Value.deserialize(reader, allocator);
        }

        return list;
    }

    const funcs = struct {
        fn Add(environment: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) anyerror!lux.runtime.Value {
            _ = environment;
            const list = context.cast(*Self);
            if (args.len != 1)
                return error.InvalidArgs;

            var cloned = try args[0].clone();
            errdefer cloned.deinit();

            try list.data.append(cloned);

            return .void;
        }

        fn Remove(environment: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) anyerror!lux.runtime.Value {
            _ = environment;
            const list = context.cast(*Self);
            if (args.len != 1)
                return error.InvalidArgs;

            const value = args[0];

            var src_index: usize = 0;
            var dst_index: usize = 0;
            while (src_index < list.data.items.len) : (src_index += 1) {
                const eql = list.data.items[src_index].eql(value);
                if (eql) {
                    // When the element is equal, we destroy and remove it.
                    // std.debug.print("deinit {} ({})\n", .{
                    //     src_index,
                    //     list.data.items[src_index],
                    // });
                    list.data.items[src_index].deinit();
                } else {
                    // Otherwise, we move the object to the front of the list skipping
                    // the already removed elements.
                    // std.debug.print("move {} ({}) → {} ({})\n", .{
                    //     src_index,
                    //     list.data.items[src_index],
                    //     dst_index,
                    //     list.data.items[dst_index],
                    // });
                    if (src_index > dst_index) {
                        list.data.items[dst_index] = list.data.items[src_index];
                    }
                    dst_index += 1;
                }
            }
            // note:
            // we don't need to deinit() excess values here as we moved them
            // above, so they are "twice" in the list.
            list.data.shrinkRetainingCapacity(dst_index);

            return .void;
        }

        fn RemoveAt(environment: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) anyerror!lux.runtime.Value {
            _ = environment;
            const list = context.cast(*Self);
            if (args.len != 1)
                return error.InvalidArgs;

            const index = try args[0].toInteger(usize);

            if (index < list.data.items.len) {
                list.data.items[index].deinit();
                std.mem.copy(
                    lux.runtime.Value,
                    list.data.items[index..],
                    list.data.items[index + 1 ..],
                );
                list.data.shrinkRetainingCapacity(list.data.items.len - 1);
            }

            return .void;
        }

        fn GetCount(environment: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) anyerror!lux.runtime.Value {
            _ = environment;
            const list = context.cast(*Self);
            if (args.len != 0)
                return error.InvalidArgs;
            return lux.runtime.Value.initInteger(usize, list.data.items.len);
        }

        fn GetItem(environment: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) anyerror!lux.runtime.Value {
            _ = environment;
            const list = context.cast(*Self);
            if (args.len != 1)
                return error.InvalidArgs;
            const index = try args[0].toInteger(usize);
            if (index >= list.data.items.len)
                return error.OutOfRange;

            return try list.data.items[index].clone();
        }

        fn SetItem(environment: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) anyerror!lux.runtime.Value {
            _ = environment;
            const list = context.cast(*Self);
            if (args.len != 2)
                return error.InvalidArgs;
            const index = try args[0].toInteger(usize);
            if (index >= list.data.items.len)
                return error.OutOfRange;

            var cloned = try args[1].clone();

            list.data.items[index].replaceWith(cloned);

            return .void;
        }

        fn ToArray(environment: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) anyerror!lux.runtime.Value {
            _ = environment;
            const list = context.cast(*Self);
            if (args.len != 0)
                return error.InvalidArgs;

            var array = try lux.runtime.Array.init(list.allocator, list.data.items.len);
            errdefer array.deinit();

            for (array.contents) |*item, index| {
                item.* = try list.data.items[index].clone();
            }

            return lux.runtime.Value.fromArray(array);
        }

        fn IndexOf(environment: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) anyerror!lux.runtime.Value {
            _ = environment;
            const list = context.cast(*Self);
            if (args.len != 1)
                return error.InvalidArgs;

            for (list.data.items) |item, index| {
                if (item.eql(args[0]))
                    return lux.runtime.Value.initInteger(usize, index);
            }

            return .void;
        }

        fn Resize(environment: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) anyerror!lux.runtime.Value {
            _ = environment;
            const list = context.cast(*Self);
            if (args.len != 1)
                return error.InvalidArgs;

            const new_size = try args[0].toInteger(usize);
            const old_size = list.data.items.len;

            if (old_size > new_size) {
                for (list.data.items[new_size..]) |*item| {
                    item.deinit();
                }
                list.data.shrinkAndFree(new_size);
            } else if (new_size > old_size) {
                try list.data.resize(new_size);
                for (list.data.items[old_size..]) |*item| {
                    item.* = .void;
                }
            }

            return .void;
        }

        fn Clear(environment: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) anyerror!lux.runtime.Value {
            _ = environment;
            const list = context.cast(*Self);
            if (args.len != 0)
                return error.InvalidArgs;

            for (list.data.items) |*item| {
                item.deinit();
            }
            list.data.shrinkAndFree(0);

            return .void;
        }
    };
};

pub const LuxDictionary = struct {
    const Self = @This();

    const KV = struct {
        key: lux.runtime.Value,
        value: lux.runtime.Value,

        fn deinit(self: *KV) void {
            self.key.deinit();
            self.value.deinit();
            self.* = undefined;
        }
    };

    allocator: std.mem.Allocator,
    data: std.ArrayList(KV),

    pub fn getMethod(self: *Self, name: []const u8) ?lux.runtime.Function {
        inline for (comptime std.meta.declarations(funcs)) |decl| {
            if (std.mem.eql(u8, name, decl.name)) {
                return lux.runtime.Function{
                    .syncUser = .{
                        .context = lux.runtime.Context.make(*Self, self),
                        .call = @field(funcs, decl.name),
                        .destructor = null,
                    },
                };
            }
        }
        return null;
    }

    pub fn destroyObject(self: *Self) void {
        for (self.data.items) |*item| {
            item.deinit();
        }
        self.data.deinit();
        self.allocator.destroy(self);
    }

    pub fn serializeObject(writer: lux.runtime.OutputStream.Writer, object: *Self) !void {
        try writer.writeIntLittle(u32, @intCast(u32, object.data.items.len));
        for (object.data.items) |item| {
            try item.key.serialize(writer);
            try item.value.serialize(writer);
        }
    }

    pub fn deserializeObject(allocator: std.mem.Allocator, reader: lux.runtime.InputStream.Reader) !*Self {
        const item_count = try reader.readIntLittle(u32);
        var list = try allocator.create(Self);
        list.* = Self{
            .allocator = allocator,
            .data = std.ArrayList(KV).init(allocator),
        };
        errdefer list.destroyObject(); // this will also free memory!

        try list.data.resize(item_count);

        // sane init to make destroyObject not explode
        // (deinit a void value is a no-op)
        for (list.data.items) |*item| {
            item.* = KV{
                .key = .void,
                .value = .void,
            };
        }

        for (list.data.items) |*item| {
            item.key = try lux.runtime.Value.deserialize(reader, allocator);
            item.value = try lux.runtime.Value.deserialize(reader, allocator);
        }

        return list;
    }

    const funcs = struct {
        fn Set(environment: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) anyerror!lux.runtime.Value {
            const dict = context.cast(*Self);
            if (args.len != 2)
                return error.InvalidArgs;

            if (args[1] == .void) {
                // short-circuit a argument `void` to a call to `Remove(key)`
                var result = try Remove(environment, context, args[0..1]);
                result.deinit();
                return .void;
            }

            var value = try args[1].clone();
            errdefer value.deinit();

            for (dict.data.items) |*item| {
                if (item.key.eql(args[0])) {
                    item.value.replaceWith(value);
                    return .void;
                }
            }

            var key = try args[0].clone();
            errdefer key.deinit();

            try dict.data.append(KV{
                .key = key,
                .value = value,
            });

            return .void;
        }

        fn Get(environment: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) anyerror!lux.runtime.Value {
            _ = environment;
            const dict = context.cast(*Self);
            if (args.len != 1)
                return error.InvalidArgs;

            for (dict.data.items) |item| {
                if (item.key.eql(args[0])) {
                    return try item.value.clone();
                }
            }

            return .void;
        }

        fn Contains(environment: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) anyerror!lux.runtime.Value {
            _ = environment;
            const dict = context.cast(*Self);
            if (args.len != 1)
                return error.InvalidArgs;

            for (dict.data.items) |item| {
                if (item.key.eql(args[0])) {
                    return lux.runtime.Value.initBoolean(true);
                }
            }

            return lux.runtime.Value.initBoolean(false);
        }

        fn Remove(environment: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) anyerror!lux.runtime.Value {
            _ = environment;
            const dict = context.cast(*Self);
            if (args.len != 1)
                return error.InvalidArgs;

            for (dict.data.items) |*item, index| {
                if (item.key.eql(args[0])) {

                    // use a fast swap-remove here
                    item.deinit();
                    const last_index = dict.data.items.len - 1;
                    dict.data.items[index] = dict.data.items[last_index];
                    dict.data.shrinkRetainingCapacity(last_index);

                    return lux.runtime.Value.initBoolean(true);
                }
            }
            return lux.runtime.Value.initBoolean(false);
        }

        fn Clear(environment: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) anyerror!lux.runtime.Value {
            _ = environment;
            const dict = context.cast(*Self);
            if (args.len != 0)
                return error.InvalidArgs;
            for (dict.data.items) |*item| {
                item.deinit();
            }
            dict.data.shrinkAndFree(0);
            return .void;
        }

        fn GetCount(environment: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) anyerror!lux.runtime.Value {
            _ = environment;
            const dict = context.cast(*Self);
            if (args.len != 0)
                return error.InvalidArgs;
            return lux.runtime.Value.initInteger(usize, dict.data.items.len);
        }

        fn GetKeys(environment: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) anyerror!lux.runtime.Value {
            _ = environment;
            const dict = context.cast(*Self);
            if (args.len != 0)
                return error.InvalidArgs;
            var arr = try lux.runtime.Array.init(dict.allocator, dict.data.items.len);
            errdefer arr.deinit();

            for (dict.data.items) |item, index| {
                arr.contents[index].replaceWith(try item.key.clone());
            }

            return lux.runtime.Value.fromArray(arr);
        }

        fn GetValues(environment: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) anyerror!lux.runtime.Value {
            _ = environment;
            const dict = context.cast(*Self);
            if (args.len != 0)
                return error.InvalidArgs;
            var arr = try lux.runtime.Array.init(dict.allocator, dict.data.items.len);
            errdefer arr.deinit();

            for (dict.data.items) |item, index| {
                arr.contents[index].replaceWith(try item.value.clone());
            }

            return lux.runtime.Value.fromArray(arr);
        }
    };
};
