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

pub fn tokenize(allocator: std.mem.Allocator, str: []u8, err: **ErrInfo) ![]Token {
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
                err.* = try ErrInfo.init(
                    allocator,
                    try std.fmt.allocPrint(
                        allocator,
                        "Unexpected character in input: {c}",
                        .{asciiChar},
                    ),
                );
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

    return try tokens.toOwnedSlice(allocator);
}
