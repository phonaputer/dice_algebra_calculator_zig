const std = @import("std");
const DiceError = @import("dice_error.zig").DiceError;
const ErrInfo = @import("dice_error.zig").ErrInfo;

pub const TokenType = enum {
    number,
    d,
    h,
    l,
    add,
    subtract,
    multiply,
    divide,
    open_paren,
    close_paren,
};

pub const Token = struct {
    token_type: TokenType,
    integer: u64,
};

pub fn tokenize(allocator: std.mem.Allocator, str: []const u8, err_info: **ErrInfo) ![]Token {
    var tokens: std.ArrayList(Token) = .empty;
    defer tokens.deinit(allocator);

    var ongoing_int_str: std.ArrayList(u8) = .empty;
    defer ongoing_int_str.deinit(allocator);

    for (str) |asciiChar| {
        var got_token = false;
        var token_type: TokenType = undefined;

        switch (asciiChar) {
            '0'...'9' => {
                try ongoing_int_str.append(allocator, asciiChar);
            },
            ' ', '\n', '\t' => {
                // skip
            },
            'd', 'D' => {
                got_token = true;
                token_type = TokenType.d;
            },
            'h', 'H' => {
                got_token = true;
                token_type = TokenType.h;
            },
            'l', 'L' => {
                got_token = true;
                token_type = TokenType.l;
            },
            '+' => {
                got_token = true;
                token_type = TokenType.add;
            },
            '-' => {
                got_token = true;
                token_type = TokenType.subtract;
            },
            '*' => {
                got_token = true;
                token_type = TokenType.multiply;
            },
            '/' => {
                got_token = true;
                token_type = TokenType.divide;
            },
            '(' => {
                got_token = true;
                token_type = TokenType.open_paren;
            },
            ')' => {
                got_token = true;
                token_type = TokenType.close_paren;
            },
            else => {
                const msg = try std.fmt.allocPrint(
                    allocator,
                    "Unexpected character in input: {c}",
                    .{asciiChar},
                );
                defer allocator.free(msg);
                err_info.* = try ErrInfo.init(allocator, msg);

                return DiceError.InvalidInput;
            },
        }

        if (!got_token) {
            continue;
        }

        if (ongoing_int_str.items.len > 0) {
            try tokens.append(
                allocator,
                .{
                    .token_type = TokenType.number,
                    .integer = try std.fmt.parseInt(u64, ongoing_int_str.items, 10),
                },
            );
            ongoing_int_str.clearRetainingCapacity();
        }

        try tokens.append(allocator, .{
            .token_type = token_type,
            .integer = 0,
        });
    }

    if (ongoing_int_str.items.len > 0) {
        try tokens.append(
            allocator,
            .{
                .token_type = TokenType.number,
                .integer = try std.fmt.parseInt(u64, ongoing_int_str.items, 10),
            },
        );
        ongoing_int_str.clearRetainingCapacity();
    }

    return try tokens.toOwnedSlice(allocator);
}

test "tokenize - empty string input - returns empty token slice" {
    var err_info: *ErrInfo = undefined;
    const allocator = std.testing.allocator;
    const input: []const u8 = "";

    const result = try tokenize(allocator, input, &err_info);

    try std.testing.expectEqual(0, result.len);
}

test "tokenize - only whitespace input - returns empty token slice" {
    var err_info: *ErrInfo = undefined;
    const allocator = std.testing.allocator;
    const input: []const u8 = " \n\t";

    const result = try tokenize(allocator, input, &err_info);

    try std.testing.expectEqual(0, result.len);
}

test "tokenize - input valid tokens - returns the tokens" {
    var err_info: *ErrInfo = undefined;
    const allocator = std.testing.allocator;
    const input: []const u8 = "100d5DhHlL+-/*()";

    const result = try tokenize(allocator, input, &err_info);
    defer allocator.free(result);

    var expectedTokens = [_]Token{
        .{ .token_type = TokenType.number, .integer = 100 },
        .{ .token_type = TokenType.d, .integer = 0 },
        .{ .token_type = TokenType.number, .integer = 5 },
        .{ .token_type = TokenType.d, .integer = 0 },
        .{ .token_type = TokenType.h, .integer = 0 },
        .{ .token_type = TokenType.h, .integer = 0 },
        .{ .token_type = TokenType.l, .integer = 0 },
        .{ .token_type = TokenType.l, .integer = 0 },
        .{ .token_type = TokenType.add, .integer = 0 },
        .{ .token_type = TokenType.subtract, .integer = 0 },
        .{ .token_type = TokenType.divide, .integer = 0 },
        .{ .token_type = TokenType.multiply, .integer = 0 },
        .{ .token_type = TokenType.open_paren, .integer = 0 },
        .{ .token_type = TokenType.close_paren, .integer = 0 },
    };
    try std.testing.expectEqualSlices(Token, expectedTokens[0..], result);
}

test "tokenize - input valid tokens with whitespace - ignores the whitespace and returns the tokens" {
    var err_info: *ErrInfo = undefined;
    const allocator = std.testing.allocator;
    const input: []const u8 = "\n\t100 \n\td \n\t5 \n\tD \n\th \n\tH \n\tl \n\tL \n\t+ \n\t- \n\t/ \n\t* \n\t( \n\t)";

    const result = try tokenize(allocator, input, &err_info);
    defer allocator.free(result);

    var expectedTokens = [_]Token{
        .{ .token_type = TokenType.number, .integer = 100 },
        .{ .token_type = TokenType.d, .integer = 0 },
        .{ .token_type = TokenType.number, .integer = 5 },
        .{ .token_type = TokenType.d, .integer = 0 },
        .{ .token_type = TokenType.h, .integer = 0 },
        .{ .token_type = TokenType.h, .integer = 0 },
        .{ .token_type = TokenType.l, .integer = 0 },
        .{ .token_type = TokenType.l, .integer = 0 },
        .{ .token_type = TokenType.add, .integer = 0 },
        .{ .token_type = TokenType.subtract, .integer = 0 },
        .{ .token_type = TokenType.divide, .integer = 0 },
        .{ .token_type = TokenType.multiply, .integer = 0 },
        .{ .token_type = TokenType.open_paren, .integer = 0 },
        .{ .token_type = TokenType.close_paren, .integer = 0 },
    };
    try std.testing.expectEqualSlices(Token, expectedTokens[0..], result);
}

test "tokenize - input invalid character - returns error" {
    var err_info: *ErrInfo = undefined;
    const allocator = std.testing.allocator;
    const input: []const u8 = "k";

    const result = tokenize(allocator, input, &err_info);

    try std.testing.expectError(DiceError.InvalidInput, result);
    defer err_info.deinit();
    try std.testing.expectEqualStrings("Unexpected character in input: k", err_info.message);
}
