const std = @import("std");
const DiceError = @import("dice_error.zig").DiceError;
const ErrInfo = @import("dice_error.zig").ErrInfo;
const Token = @import("lexer.zig").Token;
const TokenType = @import("lexer.zig").TokenType;

pub const IntegerNode = struct {
    integer: u64,
};

pub const ShortRollNode = struct {
    faces: u64,
};

pub const LongRollNode = struct {
    die: u64,
    faces: u64,
    keep_high: ?u64,
    keep_low: ?u64,
};

pub const MathOperation = enum {
    add,
    subtract,
    multiply,
    divide,
};

pub const MathNode = struct {
    left_operand: *Tree,
    right_operand: *Tree,
    operation: MathOperation,
};

pub const TreeNode = union(enum) {
    integer: IntegerNode,
    shortroll: ShortRollNode,
    longroll: LongRollNode,
    math: MathNode,
};

pub const Tree = struct {
    node: TreeNode,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*@This() {
        var newTree = try allocator.create(@This());
        errdefer allocator.destroy(newTree);

        newTree.allocator = allocator;

        return newTree;
    }

    pub fn deinit(self: *@This()) void {
        switch (self.node) {
            .math => |node| {
                node.left_operand.deinit();
                node.right_operand.deinit();
            },
            else => {
                // nothing extra to free
            },
        }
        self.allocator.destroy(self);
    }
};

pub fn parse(allocator: std.mem.Allocator, tokens: []Token, err_info: **ErrInfo) DiceError!*Tree {
    try validateNotEmpty(allocator, tokens, err_info);
    try validateParenBalance(allocator, tokens, err_info);

    var itr = TokenIter.init(tokens);

    return parse_add(allocator, &itr, err_info);
}

const TokenIter = struct {
    tokens: []Token,
    cur_token: u64,

    pub fn init(tokens: []Token) @This() {
        return .{
            .tokens = tokens,
            .cur_token = 0,
        };
    }

    pub fn next(self: *@This()) ?Token {
        if (self.tokens.len <= self.cur_token) {
            return null;
        }

        const token = self.tokens[self.cur_token];

        self.cur_token += 1;

        return token;
    }

    pub fn peek(self: *@This()) ?Token {
        if (self.tokens.len <= self.cur_token) {
            return null;
        }

        return self.tokens[self.cur_token];
    }

    pub fn peekNext(self: *@This()) ?Token {
        const peekIdx = self.cur_token + 1;

        if (self.tokens.len <= peekIdx) {
            return null;
        }

        return self.tokens[peekIdx];
    }
};

fn parse_add(allocator: std.mem.Allocator, itr: *TokenIter, err_info: **ErrInfo) DiceError!*Tree {
    var left_operand = try parse_mult(allocator, itr, err_info);
    errdefer left_operand.deinit();

    while (itr.peek()) |peek_token| {
        var op: MathOperation = undefined;
        switch (peek_token.token_type) {
            TokenType.add => {
                op = MathOperation.add;
            },
            TokenType.subtract => {
                op = MathOperation.subtract;
            },
            else => {
                return left_operand;
            },
        }

        _ = itr.next(); // discard * or / token

        const right_operand = try parse_mult(allocator, itr, err_info);
        errdefer right_operand.deinit();

        const new_left_operand = try Tree.init(allocator);
        errdefer new_left_operand.deinit();

        new_left_operand.node = .{
            .math = .{
                .left_operand = left_operand,
                .right_operand = right_operand,
                .operation = op,
            },
        };

        left_operand = new_left_operand;
    }

    return left_operand;
}

fn parse_mult(allocator: std.mem.Allocator, itr: *TokenIter, err_info: **ErrInfo) DiceError!*Tree {
    var left_operand = try parse_atom(allocator, itr, err_info);
    errdefer left_operand.deinit();

    while (itr.peek()) |peek_token| {
        var op: MathOperation = undefined;
        switch (peek_token.token_type) {
            TokenType.multiply => {
                op = MathOperation.multiply;
            },
            TokenType.divide => {
                op = MathOperation.divide;
            },
            else => {
                return left_operand;
            },
        }

        _ = itr.next(); // discard * or / token

        const right_operand = try parse_atom(allocator, itr, err_info);
        errdefer right_operand.deinit();

        const new_left_operand = try Tree.init(allocator);
        errdefer new_left_operand.deinit();

        new_left_operand.node = .{
            .math = .{
                .left_operand = left_operand,
                .right_operand = right_operand,
                .operation = op,
            },
        };

        left_operand = new_left_operand;
    }

    return left_operand;
}

fn parse_atom(allocator: std.mem.Allocator, itr: *TokenIter, err_info: **ErrInfo) DiceError!*Tree {
    const maybe_next_token = itr.peek();
    const next_token = maybe_next_token orelse {
        err_info.* = try ErrInfo.init(allocator, "Invalid expression.");
        return DiceError.InvalidInput;
    };

    if (next_token.token_type != TokenType.open_paren) {
        return try parse_roll(allocator, itr, err_info);
    }

    _ = itr.next(); // discard ( token
    const result = try parse_add(allocator, itr, err_info);
    _ = itr.next(); // discard ) token

    return result;
}

fn parse_roll(allocator: std.mem.Allocator, itr: *TokenIter, err_info: **ErrInfo) DiceError!*Tree {
    const maybe_next_token = itr.peek();
    const next_token = maybe_next_token orelse {
        err_info.* = try ErrInfo.init(allocator, "Invalid expression.");
        return DiceError.BadLogic;
    };

    if (next_token.token_type == TokenType.d) {
        return try parse_shortroll(allocator, itr, err_info);
    }

    const maybe_next_next_token = itr.peekNext();
    if (maybe_next_next_token) |next_next_token| {
        if (next_next_token.token_type == TokenType.d) {
            return try parse_longroll(allocator, itr, err_info);
        }
    }

    return try parse_integer(allocator, itr, err_info);
}

fn parse_longroll(allocator: std.mem.Allocator, itr: *TokenIter, err_info: **ErrInfo) DiceError!*Tree {
    const die = try parse_integer_raw(allocator, itr, err_info);

    const d_token = itr.next();
    if (d_token == null or d_token.?.token_type != TokenType.d) {
        err_info.* = try ErrInfo.init(allocator, "Parse longroll should not be called when the 2nd token is not D.");
        return DiceError.BadLogic;
    }

    const faces = try parse_integer_raw(allocator, itr, err_info);

    const tree = try Tree.init(allocator);
    errdefer tree.deinit();

    tree.node = .{
        .longroll = .{
            .die = die,
            .faces = faces,
            .keep_high = null,
            .keep_low = null,
        },
    };

    const maybe_token = itr.peek();
    if (maybe_token) |token| {
        switch (token.token_type) {
            TokenType.h => {
                _ = itr.next(); // discard h token
                tree.node.longroll.keep_high = try parse_integer_raw(allocator, itr, err_info);
            },
            TokenType.l => {
                _ = itr.next(); // discard l token
                tree.node.longroll.keep_low = try parse_integer_raw(allocator, itr, err_info);
            },
            else => {
                return tree;
            },
        }
    }

    return tree;
}

fn parse_shortroll(allocator: std.mem.Allocator, itr: *TokenIter, err_info: **ErrInfo) DiceError!*Tree {
    const token = itr.next();
    if (token == null or token.?.token_type != TokenType.d) {
        err_info.* = try ErrInfo.init(allocator, "Parse shortroll should not be called when the 1st token is not D.");
        return DiceError.BadLogic;
    }

    const tree = try Tree.init(allocator);
    errdefer tree.deinit();

    tree.node = .{
        .shortroll = .{
            .faces = try parse_integer_raw(allocator, itr, err_info),
        },
    };

    return tree;
}

fn parse_integer(allocator: std.mem.Allocator, itr: *TokenIter, err_info: **ErrInfo) DiceError!*Tree {
    const tree = try Tree.init(allocator);
    errdefer tree.deinit();

    tree.node = .{
        .integer = .{
            .integer = try parse_integer_raw(allocator, itr, err_info),
        },
    };

    return tree;
}

fn parse_integer_raw(allocator: std.mem.Allocator, itr: *TokenIter, err_info: **ErrInfo) DiceError!u64 {
    const maybe_token = itr.next();
    if (maybe_token) |token| {
        if (token.token_type == TokenType.number) {
            return token.integer;
        }
    }

    err_info.* = try ErrInfo.init(allocator, "Invalid expression.");
    return DiceError.InvalidInput;
}

fn validateNotEmpty(allocator: std.mem.Allocator, tokens: []Token, err_info: **ErrInfo) DiceError!void {
    if (tokens.len < 1) {
        err_info.* = try ErrInfo.init(allocator, "Invalid expression.");
        return DiceError.InvalidInput;
    }
}

fn validateParenBalance(allocator: std.mem.Allocator, tokens: []Token, err_info: **ErrInfo) DiceError!void {
    var open_count: u64 = 0;
    var close_count: u64 = 0;

    for (tokens) |token| {
        if (token.token_type == TokenType.open_paren) {
            open_count += 1;
        } else if (token.token_type == TokenType.close_paren) {
            close_count += 1;
        }
    }

    if (open_count != close_count) {
        err_info.* = try ErrInfo.init(allocator, "Expression contains an unclosed parenthetical.");
        return DiceError.InvalidInput;
    }
}

test "parse - unclosed open paren - returns error with message" {
    var err_info: *ErrInfo = undefined;
    const allocator = std.testing.allocator;
    var input = [_]Token{
        .{ .token_type = TokenType.open_paren, .integer = 0 },
        .{ .token_type = TokenType.d, .integer = 0 },
        .{ .token_type = TokenType.number, .integer = 5 },
    };

    const result = parse(allocator, input[0..], &err_info);

    try std.testing.expectError(DiceError.InvalidInput, result);
    defer err_info.deinit();
    try std.testing.expectEqualStrings("Expression contains an unclosed parenthetical.", err_info.message);
}

test "parse - unopened close paren - returns error with message" {
    var err_info: *ErrInfo = undefined;
    const allocator = std.testing.allocator;
    var input = [_]Token{
        .{ .token_type = TokenType.d, .integer = 0 },
        .{ .token_type = TokenType.number, .integer = 5 },
        .{ .token_type = TokenType.close_paren, .integer = 0 },
    };

    const result = parse(allocator, input[0..], &err_info);

    try std.testing.expectError(DiceError.InvalidInput, result);
    defer err_info.deinit();
    try std.testing.expectEqualStrings("Expression contains an unclosed parenthetical.", err_info.message);
}

test "parse - open & close paren in wrong order - returns error with message" {
    var err_info: *ErrInfo = undefined;
    const allocator = std.testing.allocator;
    var input = [_]Token{
        .{ .token_type = TokenType.close_paren, .integer = 0 },
        .{ .token_type = TokenType.d, .integer = 0 },
        .{ .token_type = TokenType.number, .integer = 5 },
        .{ .token_type = TokenType.open_paren, .integer = 0 },
    };

    const result = parse(allocator, input[0..], &err_info);

    try std.testing.expectError(DiceError.InvalidInput, result);
    defer err_info.deinit();
    try std.testing.expectEqualStrings("Invalid expression.", err_info.message);
}

test "parse - roll without faces - returns error with message" {
    var err_info: *ErrInfo = undefined;
    const allocator = std.testing.allocator;
    var input = [_]Token{
        .{ .token_type = TokenType.d, .integer = 0 },
    };

    const result = parse(allocator, input[0..], &err_info);

    try std.testing.expectError(DiceError.InvalidInput, result);
    defer err_info.deinit();
    try std.testing.expectEqualStrings("Invalid expression.", err_info.message);
}

test "parse - longroll without faces - returns error with message" {
    var err_info: *ErrInfo = undefined;
    const allocator = std.testing.allocator;
    var input = [_]Token{
        .{ .token_type = TokenType.number, .integer = 5 },
        .{ .token_type = TokenType.d, .integer = 0 },
    };

    const result = parse(allocator, input[0..], &err_info);

    try std.testing.expectError(DiceError.InvalidInput, result);
    defer err_info.deinit();
    try std.testing.expectEqualStrings("Invalid expression.", err_info.message);
}

test "parse - longroll keep high without number - returns error with message" {
    var err_info: *ErrInfo = undefined;
    const allocator = std.testing.allocator;
    var input = [_]Token{
        .{ .token_type = TokenType.number, .integer = 5 },
        .{ .token_type = TokenType.d, .integer = 0 },
        .{ .token_type = TokenType.number, .integer = 5 },
        .{ .token_type = TokenType.h, .integer = 0 },
    };

    const result = parse(allocator, input[0..], &err_info);

    try std.testing.expectError(DiceError.InvalidInput, result);
    defer err_info.deinit();
    try std.testing.expectEqualStrings("Invalid expression.", err_info.message);
}

test "parse - longroll keep low without number - returns error with message" {
    var err_info: *ErrInfo = undefined;
    const allocator = std.testing.allocator;
    var input = [_]Token{
        .{ .token_type = TokenType.number, .integer = 5 },
        .{ .token_type = TokenType.d, .integer = 0 },
        .{ .token_type = TokenType.number, .integer = 5 },
        .{ .token_type = TokenType.l, .integer = 0 },
    };

    const result = parse(allocator, input[0..], &err_info);

    try std.testing.expectError(DiceError.InvalidInput, result);
    defer err_info.deinit();
    try std.testing.expectEqualStrings("Invalid expression.", err_info.message);
}

test "parse - add without left operand - returns error with message" {
    var err_info: *ErrInfo = undefined;
    const allocator = std.testing.allocator;
    var input = [_]Token{
        .{ .token_type = TokenType.add, .integer = 0 },
        .{ .token_type = TokenType.number, .integer = 5 },
    };

    const result = parse(allocator, input[0..], &err_info);

    try std.testing.expectError(DiceError.InvalidInput, result);
    defer err_info.deinit();
    try std.testing.expectEqualStrings("Invalid expression.", err_info.message);
}

test "parse - add without right operand - returns error with message" {
    var err_info: *ErrInfo = undefined;
    const allocator = std.testing.allocator;
    var input = [_]Token{
        .{ .token_type = TokenType.number, .integer = 5 },
        .{ .token_type = TokenType.add, .integer = 0 },
    };

    const result = parse(allocator, input[0..], &err_info);

    try std.testing.expectError(DiceError.InvalidInput, result);
    defer err_info.deinit();
    try std.testing.expectEqualStrings("Invalid expression.", err_info.message);
}

test "parse - multiply without left operand - returns error with message" {
    var err_info: *ErrInfo = undefined;
    const allocator = std.testing.allocator;
    var input = [_]Token{
        .{ .token_type = TokenType.multiply, .integer = 0 },
        .{ .token_type = TokenType.number, .integer = 5 },
    };

    const result = parse(allocator, input[0..], &err_info);

    try std.testing.expectError(DiceError.InvalidInput, result);
    defer err_info.deinit();
    try std.testing.expectEqualStrings("Invalid expression.", err_info.message);
}

test "parse - multiply without right operand - returns error with message" {
    var err_info: *ErrInfo = undefined;
    const allocator = std.testing.allocator;
    var input = [_]Token{
        .{ .token_type = TokenType.number, .integer = 5 },
        .{ .token_type = TokenType.multiply, .integer = 0 },
    };

    const result = parse(allocator, input[0..], &err_info);

    try std.testing.expectError(DiceError.InvalidInput, result);
    defer err_info.deinit();
    try std.testing.expectEqualStrings("Invalid expression.", err_info.message);
}
