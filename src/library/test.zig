// this path is mainly to provide a neat test environment

const lux = @import("main.zig");

comptime {
    _ = lux;
}

pub const ObjectPool = lux.runtime.ObjectPool(.{});
