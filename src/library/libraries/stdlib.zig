// This file implements the Lux standard library

const std = @import("std");
const builtin = @import("builtin");
const lux = @import("../main.zig");

const whitespace = [_]u8{
    0x09, // horizontal tab
    0x0A, // line feed
    0x0B, // vertical tab
    0x0C, // form feed
    0x0D, // carriage return
    0x20, // space
};

const root = @import("root");

const milliTimestamp = if (builtin.os.tag == .freestanding)
    if (@hasDecl(root, "milliTimestamp"))
        root.milliTimestamp
    else
        @compileError("Please provide milliTimestamp in the root file for freestanding targets!")
else
    std.time.milliTimestamp;

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

test "stdlib.install" {
    var pool = lux.runtime.ObjectPool([_]type{}).init(std.testing.allocator);
    defer pool.deinit();

    var env = try lux.runtime.Environment.init(std.testing.allocator, &empty_compile_unit, pool.interface());
    defer env.deinit();

    // TODO: Reinsert this
    try env.installModule(@This(), lux.runtime.Context.null_pointer);
}

pub fn Sleep(env: *lux.runtime.Environment, call_context: lux.runtime.Context, args: []const lux.runtime.Value) anyerror!lux.runtime.AsyncFunctionCall {
    _ = call_context;

    if (args.len != 1)
        return error.InvalidArgs;
    const seconds = try args[0].toNumber();

    const Context = struct {
        allocator: std.mem.Allocator,
        end_time: f64,
    };

    const ptr = try env.allocator.create(Context);
    ptr.* = Context{
        .allocator = env.allocator,
        .end_time = @intToFloat(f64, milliTimestamp()) + 1000.0 * seconds,
    };

    return lux.runtime.AsyncFunctionCall{
        .context = lux.runtime.Context.make(*Context, ptr),
        .destructor = struct {
            fn dtor(exec_context: lux.runtime.Context) void {
                const ctx = exec_context.cast(*Context);
                ctx.allocator.destroy(ctx);
            }
        }.dtor,
        .execute = struct {
            fn execute(exec_context: lux.runtime.Context) anyerror!?lux.runtime.Value {
                const ctx = exec_context.cast(*Context);

                if (ctx.end_time < @intToFloat(f64, milliTimestamp())) {
                    return .void;
                } else {
                    return null;
                }
            }
        }.execute,
    };
}

pub fn Yield(env: *lux.runtime.Environment, call_context: lux.runtime.Context, args: []const lux.runtime.Value) anyerror!lux.runtime.AsyncFunctionCall {
    _ = call_context;

    if (args.len != 0)
        return error.InvalidArgs;

    const Context = struct {
        allocator: std.mem.Allocator,
        end: bool,
    };

    const ptr = try env.allocator.create(Context);
    ptr.* = Context{
        .allocator = env.allocator,
        .end = false,
    };

    return lux.runtime.AsyncFunctionCall{
        .context = lux.runtime.Context.make(*Context, ptr),
        .destructor = struct {
            fn dtor(exec_context: lux.runtime.Context) void {
                const ctx = exec_context.cast(*Context);
                ctx.allocator.destroy(ctx);
            }
        }.dtor,
        .execute = struct {
            fn execute(exec_context: lux.runtime.Context) anyerror!?lux.runtime.Value {
                const ctx = exec_context.cast(*Context);

                if (ctx.end) {
                    return .void;
                } else {
                    ctx.end = true;
                    return null;
                }
            }
        }.execute,
    };
}

pub fn Length(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = env;
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;
    return switch (args[0]) {
        .string => |str| lux.runtime.Value.initNumber(@intToFloat(f64, str.contents.len)),
        .array => |arr| lux.runtime.Value.initNumber(@intToFloat(f64, arr.contents.len)),
        else => error.TypeMismatch,
    };
}

pub fn SubString(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = context;
    if (args.len < 2 or args.len > 3)
        return error.InvalidArgs;
    if (args[0] != .string)
        return error.TypeMismatch;
    if (args[1] != .number)
        return error.TypeMismatch;
    if (args.len == 3 and args[2] != .number)
        return error.TypeMismatch;

    const str = args[0].string;
    const start = try args[1].toInteger(usize);
    if (start >= str.contents.len)
        return lux.runtime.Value.initString(env.allocator, "");

    const sliced = if (args.len == 3)
        str.contents[start..][0..std.math.min(str.contents.len - start, try args[2].toInteger(usize))]
    else
        str.contents[start..];

    return try lux.runtime.Value.initString(env.allocator, sliced);
}
pub fn Trim(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;
    if (args[0] != .string)
        return error.TypeMismatch;
    const str = args[0].string;

    return try lux.runtime.Value.initString(
        env.allocator,
        std.mem.trim(u8, str.contents, &whitespace),
    );
}

pub fn TrimLeft(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;
    if (args[0] != .string)
        return error.TypeMismatch;
    const str = args[0].string;

    return try lux.runtime.Value.initString(
        env.allocator,
        std.mem.trimLeft(u8, str.contents, &whitespace),
    );
}

pub fn TrimRight(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;
    if (args[0] != .string)
        return error.TypeMismatch;
    const str = args[0].string;

    return try lux.runtime.Value.initString(
        env.allocator,
        std.mem.trimRight(u8, str.contents, &whitespace),
    );
}

pub fn IndexOf(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = env;
    _ = context;
    if (args.len != 2)
        return error.InvalidArgs;
    if (args[0] == .string) {
        if (args[1] != .string)
            return error.TypeMismatch;
        const haystack = args[0].string.contents;
        const needle = args[1].string.contents;

        return if (std.mem.indexOf(u8, haystack, needle)) |index|
            lux.runtime.Value.initNumber(@intToFloat(f64, index))
        else
            .void;
    } else if (args[0] == .array) {
        const haystack = args[0].array.contents;
        for (haystack) |val, i| {
            if (val.eql(args[1]))
                return lux.runtime.Value.initNumber(@intToFloat(f64, i));
        }
        return .void;
    } else {
        return error.TypeMismatch;
    }
}

pub fn LastIndexOf(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = env;
    _ = context;
    if (args.len != 2)
        return error.InvalidArgs;
    if (args[0] == .string) {
        if (args[1] != .string)
            return error.TypeMismatch;
        const haystack = args[0].string.contents;
        const needle = args[1].string.contents;

        return if (std.mem.lastIndexOf(u8, haystack, needle)) |index|
            lux.runtime.Value.initNumber(@intToFloat(f64, index))
        else
            .void;
    } else if (args[0] == .array) {
        const haystack = args[0].array.contents;

        var i: usize = haystack.len;
        while (i > 0) {
            i -= 1;
            if (haystack[i].eql(args[1]))
                return lux.runtime.Value.initNumber(@intToFloat(f64, i));
        }
        return .void;
    } else {
        return error.TypeMismatch;
    }
}

pub fn Byte(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = env;
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;
    if (args[0] != .string)
        return error.TypeMismatch;
    const value = args[0].string.contents;
    if (value.len > 0)
        return lux.runtime.Value.initNumber(@intToFloat(f64, value[0]))
    else
        return .void;
}

pub fn Chr(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;
    const val = try args[0].toInteger(u8);

    return try lux.runtime.Value.initString(
        env.allocator,
        &[_]u8{val},
    );
}

pub fn NumToString(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = context;
    if (args.len < 1 or args.len > 2)
        return error.InvalidArgs;
    var buffer: [256]u8 = undefined;

    const slice = if (args.len == 2) blk: {
        const base = try args[1].toInteger(u8);

        const val = try args[0].toInteger(isize);
        const len = std.fmt.formatIntBuf(&buffer, val, base, .upper, std.fmt.FormatOptions{});

        break :blk buffer[0..len];
    } else blk: {
        var stream = std.io.fixedBufferStream(&buffer);

        const val = try args[0].toNumber();
        try std.fmt.formatFloatDecimal(val, .{}, stream.writer());

        break :blk stream.getWritten();
    };
    return try lux.runtime.Value.initString(env.allocator, slice);
}

pub fn StringToNum(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = env;
    _ = context;
    if (args.len < 1 or args.len > 2)
        return error.InvalidArgs;
    const str = try args[0].toString();

    if (args.len == 2) {
        const base = try args[1].toInteger(u8);

        const text = if (base == 16) blk: {
            var tmp = str;
            if (std.mem.startsWith(u8, tmp, "0x"))
                tmp = tmp[2..];
            if (std.mem.endsWith(u8, tmp, "h"))
                tmp = tmp[0 .. tmp.len - 1];
            break :blk tmp;
        } else str;

        const val = try std.fmt.parseInt(isize, text, base); // return .void;

        return lux.runtime.Value.initNumber(@intToFloat(f64, val));
    } else {
        const val = std.fmt.parseFloat(f64, str) catch return .void;
        return lux.runtime.Value.initNumber(val);
    }
}

pub fn Split(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = context;
    if (args.len < 2 or args.len > 3)
        return error.InvalidArgs;

    const input = try args[0].toString();
    const separator = try args[1].toString();
    const removeEmpty = if (args.len == 3) try args[2].toBoolean() else false;

    var items = std.ArrayList(lux.runtime.Value).init(env.allocator);
    defer {
        for (items.items) |*i| {
            i.deinit();
        }
        items.deinit();
    }

    var iter = std.mem.split(u8, input, separator);
    while (iter.next()) |slice| {
        if (!removeEmpty or slice.len > 0) {
            var val = try lux.runtime.Value.initString(env.allocator, slice);
            errdefer val.deinit();

            try items.append(val);
        }
    }

    return lux.runtime.Value.fromArray(lux.runtime.Array{
        .allocator = env.allocator,
        .contents = items.toOwnedSlice(),
    });
}

pub fn Join(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = context;
    if (args.len < 1 or args.len > 2)
        return error.InvalidArgs;

    const array = try args[0].toArray();
    const separator = if (args.len == 2) try args[1].toString() else "";

    for (array.contents) |item| {
        if (item != .string)
            return error.TypeMismatch;
    }

    var result = std.ArrayList(u8).init(env.allocator);
    defer result.deinit();

    for (array.contents) |item, i| {
        if (i > 0) {
            try result.appendSlice(separator);
        }
        try result.appendSlice(try item.toString());
    }

    return lux.runtime.Value.fromString(lux.runtime.String.initFromOwned(
        env.allocator,
        result.toOwnedSlice(),
    ));
}

pub fn Array(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = context;
    if (args.len < 1 or args.len > 2)
        return error.InvalidArgs;

    const length = try args[0].toInteger(usize);
    const init_val = if (args.len > 1) args[1] else .void;

    var arr = try lux.runtime.Array.init(env.allocator, length);
    for (arr.contents) |*item| {
        item.* = try init_val.clone();
    }
    return lux.runtime.Value.fromArray(arr);
}

pub fn Range(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = context;
    if (args.len < 1 or args.len > 2)
        return error.InvalidArgs;

    if (args.len == 2) {
        const start = try args[0].toInteger(usize);
        const length = try args[1].toInteger(usize);

        var arr = try lux.runtime.Array.init(env.allocator, length);
        for (arr.contents) |*item, i| {
            item.* = lux.runtime.Value.initNumber(@intToFloat(f64, start + i));
        }
        return lux.runtime.Value.fromArray(arr);
    } else {
        const length = try args[0].toInteger(usize);
        var arr = try lux.runtime.Array.init(env.allocator, length);
        for (arr.contents) |*item, i| {
            item.* = lux.runtime.Value.initNumber(@intToFloat(f64, i));
        }
        return lux.runtime.Value.fromArray(arr);
    }
}

pub fn Slice(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = context;
    if (args.len != 3)
        return error.InvalidArgs;

    const array = try args[0].toArray();
    const start = try args[1].toInteger(usize);
    const length = try args[2].toInteger(usize);

    // Out of bounds
    if (start >= array.contents.len)
        return lux.runtime.Value.fromArray(try lux.runtime.Array.init(env.allocator, 0));

    const actual_length = std.math.min(length, array.contents.len - start);

    var arr = try lux.runtime.Array.init(env.allocator, actual_length);
    errdefer arr.deinit();

    for (arr.contents) |*item, i| {
        item.* = try array.contents[start + i].clone();
    }

    return lux.runtime.Value.fromArray(arr);
}

pub fn DeltaEqual(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = env;
    _ = context;
    if (args.len != 3)
        return error.InvalidArgs;
    const a = try args[0].toNumber();
    const b = try args[1].toNumber();
    const delta = try args[2].toNumber();
    return lux.runtime.Value.initBoolean(@fabs(a - b) < delta);
}

pub fn Floor(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = env;
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;
    return lux.runtime.Value.initNumber(@floor(try args[0].toNumber()));
}

pub fn Ceiling(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = env;
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;
    return lux.runtime.Value.initNumber(@ceil(try args[0].toNumber()));
}

pub fn Round(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = env;
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;
    return lux.runtime.Value.initNumber(@round(try args[0].toNumber()));
}

pub fn Sin(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = env;
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;
    return lux.runtime.Value.initNumber(@sin(try args[0].toNumber()));
}

pub fn Cos(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = env;
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;
    return lux.runtime.Value.initNumber(@cos(try args[0].toNumber()));
}

pub fn Tan(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = env;
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;
    return lux.runtime.Value.initNumber(@tan(try args[0].toNumber()));
}

pub fn Atan(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = env;
    _ = context;
    if (args.len == 1) {
        return lux.runtime.Value.initNumber(
            std.math.atan(try args[0].toNumber()),
        );
    } else if (args.len == 2) {
        return lux.runtime.Value.initNumber(std.math.atan2(
            f64,
            try args[0].toNumber(),
            try args[1].toNumber(),
        ));
    } else {
        return error.InvalidArgs;
    }
}

pub fn Sqrt(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = env;
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;
    return lux.runtime.Value.initNumber(std.math.sqrt(try args[0].toNumber()));
}

pub fn Pow(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = env;
    _ = context;
    if (args.len != 2)
        return error.InvalidArgs;
    return lux.runtime.Value.initNumber(std.math.pow(
        f64,
        try args[0].toNumber(),
        try args[1].toNumber(),
    ));
}

pub fn Log(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = env;
    _ = context;
    if (args.len == 1) {
        return lux.runtime.Value.initNumber(
            std.math.log10(try args[0].toNumber()),
        );
    } else if (args.len == 2) {
        return lux.runtime.Value.initNumber(std.math.log(
            f64,
            try args[1].toNumber(),
            try args[0].toNumber(),
        ));
    } else {
        return error.InvalidArgs;
    }
}

pub fn Exp(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = env;
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;
    return lux.runtime.Value.initNumber(@exp(try args[0].toNumber()));
}

pub fn Timestamp(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = env;
    _ = context;
    if (args.len != 0)
        return error.InvalidArgs;
    return lux.runtime.Value.initNumber(@intToFloat(f64, milliTimestamp()) / 1000.0);
}

pub fn TypeOf(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;
    return lux.runtime.Value.initString(env.allocator, switch (args[0]) {
        .void => "void",
        .boolean => "boolean",
        .string => "string",
        .number => "number",
        .object => "object",
        .array => "array",
        .enumerator => "enumerator",
    });
}

pub fn ToString(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = context;

    if (args.len != 1)
        return error.InvalidArgs;

    var str = try std.fmt.allocPrint(env.allocator, "{}", .{args[0]});

    return lux.runtime.Value.fromString(lux.runtime.String.initFromOwned(env.allocator, str));
}

pub fn HasFunction(env: *const lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = context;
    switch (args.len) {
        1 => {
            var name = try args[0].toString();
            return lux.runtime.Value.initBoolean(env.functions.get(name) != null);
        },
        2 => {
            var obj = try args[0].toObject();
            var name = try args[1].toString();

            const maybe_method = try env.objectPool.getMethod(obj, name);
            return lux.runtime.Value.initBoolean(maybe_method != null);
        },
        else => return error.InvalidArgs,
    }
}

pub fn Serialize(env: *lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;

    const value = args[0];

    var string_buffer = std.ArrayList(u8).init(env.allocator);
    defer string_buffer.deinit();

    try value.serialize(string_buffer.writer());

    return lux.runtime.Value.fromString(lux.runtime.String.initFromOwned(env.allocator, string_buffer.toOwnedSlice()));
}

pub fn Deserialize(env: *lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = context;
    if (args.len != 1)
        return error.InvalidArgs;

    const serialized_string = try args[0].toString();

    var stream = std.io.fixedBufferStream(serialized_string);

    return try lux.runtime.Value.deserialize(stream.reader(), env.allocator);
}

pub fn Random(env: *lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = context;
    _ = env;

    var lower: f64 = 0;
    var upper: f64 = 1;

    switch (args.len) {
        0 => {},
        1 => upper = try args[0].toNumber(),
        2 => {
            lower = try args[0].toNumber();
            upper = try args[1].toNumber();
        },
        else => return error.InvalidArgs,
    }

    var result: f64 = undefined;
    {
        random_mutex.lock();
        defer random_mutex.unlock();

        if (random == null) {
            random = std.rand.DefaultPrng.init(@bitCast(u64, @intToFloat(f64, milliTimestamp())));
        }

        result = lower + (upper - lower) * random.?.random().float(f64);
    }

    return lux.runtime.Value.initNumber(result);
}

pub fn RandomInt(env: *lux.runtime.Environment, context: lux.runtime.Context, args: []const lux.runtime.Value) !lux.runtime.Value {
    _ = context;
    _ = env;

    var lower: i32 = 0;
    var upper: i32 = std.math.maxInt(i32);

    switch (args.len) {
        0 => {},
        1 => upper = try args[0].toInteger(i32),
        2 => {
            lower = try args[0].toInteger(i32);
            upper = try args[1].toInteger(i32);
        },
        else => return error.InvalidArgs,
    }

    var result: i32 = undefined;
    {
        random_mutex.lock();
        defer random_mutex.unlock();

        if (random == null) {
            random = std.rand.DefaultPrng.init(@bitCast(u64, @intToFloat(f64, milliTimestamp())));
        }

        result = random.?.random().intRangeLessThan(i32, lower, upper);
    }

    return lux.runtime.Value.initInteger(i32, result);
}

var random_mutex = std.Thread.Mutex{};
var random: ?std.rand.DefaultPrng = null;
