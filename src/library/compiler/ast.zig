const std = @import("std");

const Location = @import("location.zig").Location;

pub const UnaryOperator = enum {
    negate,
    boolean_not,
};

pub const BinaryOperator = enum {
    add,
    subtract,
    multiply,
    divide,
    modulus,
    boolean_or,
    boolean_and,
    less_than,
    greater_than,
    greater_or_equal_than,
    less_or_equal_than,
    equal,
    different,
};

pub const Expression = struct {
    const Self = @This();

    pub const Type = std.meta.Tag(ExprValue);

    /// Starting location of the statement
    location: Location,

    /// kind of the expression as well as associated child nodes.
    /// child expressions memory is stored in the `Program` structure.
    type: ExprValue,

    /// Returns true when the expression allows an assignment similar to
    /// Cs `lvalue`.
    pub fn isAssignable(self: Self) bool {
        return switch (self.type) {
            .array_indexer, .variable_expr => true,
            else => false,
        };
    }

    const ExprValue = union(enum) {
        array_indexer: struct {
            value: *Expression,
            index: *Expression,
        },
        variable_expr: []const u8,
        array_literal: []Expression,
        function_call: struct {
            // this must be a expression of type `variable_expr`
            function: *Expression,
            arguments: []Expression,
        },
        method_call: struct {
            object: *Expression,
            name: []const u8,
            arguments: []Expression,
        },
        number_literal: f64,
        string_literal: []const u8,
        unary_operator: struct {
            operator: UnaryOperator,
            value: *Expression,
        },
        binary_operator: struct {
            operator: BinaryOperator,
            lhs: *Expression,
            rhs: *Expression,
        },
    };
};

pub const Statement = struct {
    const Self = @This();

    pub const Type = std.meta.Tag(StmtValue);

    /// Starting location of the statement
    location: Location,

    /// kind of the statement as well as associated child nodes.
    /// child statements and expressions memory is stored in the
    /// `Program` structure.
    type: StmtValue,

    const StmtValue = union(enum) {
        empty: void, // Just a single, flat ';'

        /// Top level assignment as in `lvalue = value`.
        assignment: struct {
            target: Expression,
            value: Expression,
        },

        /// Top-level function call like `Foo()`
        discard_value: Expression,

        return_void: void,
        return_expr: Expression,
        while_loop: struct {
            condition: Expression,
            body: *Statement,
        },
        for_loop: struct {
            variable: []const u8,
            source: Expression,
            body: *Statement,
        },
        if_statement: struct {
            condition: Expression,
            true_body: *Statement,
            false_body: ?*Statement,
        },
        declaration: struct {
            variable: []const u8,
            initial_value: ?Expression,
            is_const: bool,
        },
        block: []Statement,
        @"break": void,
        @"continue": void,
    };
};

pub const Function = struct {
    /// Starting location of the function
    location: Location,

    name: []const u8,
    parameters: [][]const u8,
    body: Statement,
};

/// Root node of the abstract syntax tree,
/// contains a whole Lux file.
pub const Program = struct {
    const Self = @This();

    /// Arena storing all associated memory with the AST.
    /// Each node, string or array is stored here.
    arena: std.heap.ArenaAllocator,

    /// The sequence of statements that are not contained in functions.
    root_script: []Statement,

    /// All declared functions in the script.
    functions: []Function,

    /// Releases all resources associated with this syntax tree.
    pub fn deinit(self: *Self) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub fn dumpExpression(writer: anytype, expr: Expression) @TypeOf(writer).Error!void {
    switch (expr.type) {
        .array_indexer => |val| {
            try dumpExpression(writer, val.value.*);
            try writer.writeAll("[");
            try dumpExpression(writer, val.index.*);
            try writer.writeAll("]");
        },
        .variable_expr => |val| try writer.writeAll(val),
        .array_literal => |val| {
            try writer.writeAll("[ ");
            for (val) |item, index| {
                if (index > 0) {
                    try writer.writeAll(", ");
                }
                try dumpExpression(writer, item);
            }
            try writer.writeAll("]");
        },
        .function_call => unreachable,
        .method_call => unreachable,
        .number_literal => |val| try writer.print("{d}", .{val}),
        .string_literal => |val| try writer.print("\"{}\"", .{val}),
        .unary_operator => |val| {
            try writer.writeAll(switch (val.operator) {
                .negate => "-",
                .boolean_not => "not",
            });
            try dumpExpression(writer, val.value.*);
        },
        .binary_operator => |val| {
            try writer.writeAll("(");
            try dumpExpression(writer, val.lhs.*);
            try writer.writeAll(" ");
            try writer.writeAll(switch (val.operator) {
                .add => "+",
                .subtract => "-",
                .multiply => "*",
                .divide => "/",
                .modulus => "%",
                .boolean_or => "or",
                .boolean_and => "and",
                .less_than => "<",
                .greater_than => ">",
                .greater_or_equal_than => ">=",
                .less_or_equal_than => "<=",
                .equal => "==",
                .different => "!=",
            });
            try writer.writeAll(" ");
            try dumpExpression(writer, val.rhs.*);
            try writer.writeAll(")");
        },
    }
}
