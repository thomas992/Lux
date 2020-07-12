// Import all runtime namespaces
usingnamespace @import("runtime/value.zig");
usingnamespace @import("runtime/ir.zig");
usingnamespace @import("runtime/compile_unit.zig");
usingnamespace @import("runtime/decoder.zig");
usingnamespace @import("runtime/named_global.zig");
usingnamespace @import("runtime/disassembler.zig");
usingnamespace @import("runtime/environment.zig");
usingnamespace @import("runtime/vm.zig");
usingnamespace @import("runtime/context.zig");
usingnamespace @import("runtime/strings.zig");

// Export the stdlib as `lola.std`:
pub const std = @import("stdlib/main.zig");