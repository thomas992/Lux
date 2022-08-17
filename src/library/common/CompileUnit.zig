const std = @import("std");

const utility = @import("utility.zig");

// Import modules to reduce file size
// usingnamespace @import("value.zig");

/// A compiled piece of code, provides the building blocks for
/// an environment. Note that a compile unit must be instantiated
/// into an environment to be executed.
pub const CompileUnit = @This();

/// Description of a script function.
pub const Function = struct {
    name: []const u8,
    entryPoint: u32,
    localCount: u16,
};

/// A mapping of which code portion belongs to which
/// line in the source code.
/// Lines are valid from offset until the next available symbol.
pub const DebugSymbol = struct {
    /// Offset of the symbol from the start of the compiled code.
    offset: u32,

    /// The line number, starting at 1.
    sourceLine: u32,

    /// The offset into the line, starting at 1.
    sourceColumn: u16,
};

arena: std.heap.ArenaAllocator,

/// Freeform file structure comment. This usually contains the file name of the compile file.
comment: []const u8,

/// Number of global (persistent) variables stored in the environment
globalCount: u16,

/// Number of temporary (local) variables in the global scope.
temporaryCount: u16,

/// The compiled binary code.
code: []u8,

/// Array of function definitions
functions: []const Function,

/// Sorted array of debug symbols
debugSymbols: []const DebugSymbol,

/// Loads a compile unit from a data stream.
pub fn loadFromStream(allocator: std.mem.Allocator, stream: anytype) !CompileUnit {
    // var inStream = file.getInStream();
    // var stream = &inStream.stream;
    var header: [8]u8 = undefined;
    stream.readNoEof(&header) catch |err| switch (err) {
        error.EndOfStream => return error.InvalidFormat, // file is too short!
        else => return err,
    };
    if (!std.mem.eql(u8, &header, "Lux\xB9\x40\x80\x5A"))
        return error.InvalidFormat;
    const version = try stream.readIntLittle(u32);
    if (version != 1)
        return error.UnsupportedVersion;

    var comment: [256]u8 = undefined;
    try stream.readNoEof(&comment);

    var unit = CompileUnit{
        .arena = std.heap.ArenaAllocator.init(allocator),
        .globalCount = undefined,
        .temporaryCount = undefined,
        .code = undefined,
        .functions = undefined,
        .debugSymbols = undefined,
        .comment = undefined,
    };
    errdefer unit.arena.deinit();

    unit.comment = try unit.arena.allocator().dupe(u8, utility.clampFixedString(&comment));

    unit.globalCount = try stream.readIntLittle(u16);
    unit.temporaryCount = try stream.readIntLittle(u16);

    const functionCount = try stream.readIntLittle(u16);
    const codeSize = try stream.readIntLittle(u32);
    const numSymbols = try stream.readIntLittle(u32);

    if (functionCount > codeSize or numSymbols > codeSize) {
        // It is not reasonable to have multiple functions per
        // byte of code.
        // The same is valid for debug symbols.
        return error.CorruptedData;
    }

    const functions = try unit.arena.allocator().alloc(Function, functionCount);
    const code = try unit.arena.allocator().alloc(u8, codeSize);
    const debugSymbols = try unit.arena.allocator().alloc(DebugSymbol, numSymbols);

    for (functions) |*fun| {
        var name: [128]u8 = undefined;
        try stream.readNoEof(&name);

        const entryPoint = try stream.readIntLittle(u32);
        const localCount = try stream.readIntLittle(u16);

        fun.* = Function{
            .name = try unit.arena.allocator().dupe(u8, utility.clampFixedString(&name)),
            .entryPoint = entryPoint,
            .localCount = localCount,
        };
    }
    unit.functions = functions;

    try stream.readNoEof(code);
    unit.code = code;

    for (debugSymbols) |*sym| {
        const offset = try stream.readIntLittle(u32);
        const sourceLine = try stream.readIntLittle(u32);
        const sourceColumn = try stream.readIntLittle(u16);
        sym.* = DebugSymbol{
            .offset = offset,
            .sourceLine = sourceLine,
            .sourceColumn = sourceColumn,
        };
    }
    std.sort.sort(DebugSymbol, debugSymbols, {}, struct {
        fn lessThan(context: void, lhs: DebugSymbol, rhs: DebugSymbol) bool {
            _ = context;
            return lhs.offset < rhs.offset;
        }
    }.lessThan);
    unit.debugSymbols = debugSymbols;

    return unit;
}

/// Saves a compile unit to a data stream.
pub fn saveToStream(self: CompileUnit, stream: anytype) !void {
    try stream.writeAll("Lux\xB9\x40\x80\x5A");
    try stream.writeIntLittle(u32, 1);
    try stream.writeAll(self.comment);
    try stream.writeByteNTimes(0, 256 - self.comment.len);
    try stream.writeIntLittle(u16, self.globalCount);
    try stream.writeIntLittle(u16, self.temporaryCount);
    try stream.writeIntLittle(u16, @intCast(u16, self.functions.len));
    try stream.writeIntLittle(u32, @intCast(u32, self.code.len));
    try stream.writeIntLittle(u32, @intCast(u32, self.debugSymbols.len));
    for (self.functions) |fun| {
        try stream.writeAll(fun.name);
        try stream.writeByteNTimes(0, 128 - fun.name.len);
        try stream.writeIntNative(u32, fun.entryPoint);
        try stream.writeIntNative(u16, fun.localCount);
    }
    try stream.writeAll(self.code);
    for (self.debugSymbols) |sym| {
        try stream.writeIntNative(u32, sym.offset);
        try stream.writeIntNative(u32, sym.sourceLine);
        try stream.writeIntNative(u16, sym.sourceColumn);
    }
}

/// Searches for a debug symbol that preceeds the given address.
/// Function assumes that CompileUnit.debugSymbols is sorted
/// front-to-back by offset.
pub fn lookUp(self: CompileUnit, offset: u32) ?DebugSymbol {
    if (offset >= self.code.len)
        return null;
    var result: ?DebugSymbol = null;
    for (self.debugSymbols) |sym| {
        if (sym.offset > offset)
            break;
        result = sym;
    }
    return result;
}

pub fn deinit(self: CompileUnit) void {
    self.arena.deinit();
}

const serializedCompileUnit = "" // SoT
++ "Lux\xB9\x40\x80\x5A" // Header
++ "\x01\x00\x00\x00" // Version
++ "Made with NativeLux.zig!" ++ ("\x00" ** (256 - 25)) // Comment
++ "\x03\x00" // globalCount
++ "\x55\x11" // temporaryCount
++ "\x02\x00" // functionCount
++ "\x05\x00\x00\x00" // codeSize
++ "\x03\x00\x00\x00" // numSymbols
++ "Function1" ++ ("\x00" ** (128 - 9)) // Name
++ "\x00\x00\x00\x00" // entryPoint
++ "\x01\x00" // localCount
++ "Function2" ++ ("\x00" ** (128 - 9)) // Name
++ "\x10\x10\x00\x00" // entryPoint
++ "\x02\x00" // localCount
++ "Hello" // code
++ "\x01\x00\x00\x00" ++ "\x01\x00\x00\x00" ++ "\x01\x00" // dbgSym1
++ "\x02\x00\x00\x00" ++ "\x02\x00\x00\x00" ++ "\x04\x00" // dbgSym2
++ "\x04\x00\x00\x00" ++ "\x03\x00\x00\x00" ++ "\x08\x00" // dbgSym3
;

test "CompileUnit I/O" {
    var sliceInStream = std.io.fixedBufferStream(serializedCompileUnit);

    const cu = try CompileUnit.loadFromStream(std.testing.allocator, sliceInStream.reader());
    defer cu.deinit();

    std.debug.assert(std.mem.eql(u8, cu.comment, "Made with NativeLux.zig!"));
    std.debug.assert(cu.globalCount == 3);
    std.debug.assert(cu.temporaryCount == 0x1155);
    std.debug.assert(std.mem.eql(u8, cu.code, "Hello"));
    std.debug.assert(cu.functions.len == 2);
    std.debug.assert(cu.debugSymbols.len == 3);

    std.debug.assert(std.mem.eql(u8, cu.functions[0].name, "Function1"));
    std.debug.assert(cu.functions[0].entryPoint == 0x00000000);
    std.debug.assert(cu.functions[0].localCount == 1);

    std.debug.assert(std.mem.eql(u8, cu.functions[1].name, "Function2"));
    std.debug.assert(cu.functions[1].entryPoint == 0x00001010);
    std.debug.assert(cu.functions[1].localCount == 2);

    std.debug.assert(cu.debugSymbols[0].offset == 1);
    std.debug.assert(cu.debugSymbols[0].sourceLine == 1);
    std.debug.assert(cu.debugSymbols[0].sourceColumn == 1);

    std.debug.assert(cu.debugSymbols[1].offset == 2);
    std.debug.assert(cu.debugSymbols[1].sourceLine == 2);
    std.debug.assert(cu.debugSymbols[1].sourceColumn == 4);

    std.debug.assert(cu.debugSymbols[2].offset == 4);
    std.debug.assert(cu.debugSymbols[2].sourceLine == 3);
    std.debug.assert(cu.debugSymbols[2].sourceColumn == 8);

    var storage: [serializedCompileUnit.len]u8 = undefined;
    var sliceOutStream = std.io.fixedBufferStream(&storage);

    try cu.saveToStream(sliceOutStream.writer());

    std.debug.assert(sliceOutStream.getWritten().len == serializedCompileUnit.len);

    std.debug.assert(std.mem.eql(u8, sliceOutStream.getWritten(), serializedCompileUnit));
}

test "CompileUnit.lookUp" {
    var sliceInStream = std.io.fixedBufferStream(serializedCompileUnit);

    const cu = try CompileUnit.loadFromStream(std.testing.allocator, sliceInStream.reader());
    defer cu.deinit();

    std.debug.assert(cu.lookUp(0) == null); // no debug symbol before 1
    std.debug.assert(cu.lookUp(1).?.sourceLine == 1);
    std.debug.assert(cu.lookUp(2).?.sourceLine == 2);
    std.debug.assert(cu.lookUp(3).?.sourceLine == 2);
    std.debug.assert(cu.lookUp(4).?.sourceLine == 3);
    std.debug.assert(cu.lookUp(5) == null); // no debug symbol after end-of-code
}
