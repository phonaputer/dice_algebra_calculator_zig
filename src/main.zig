const std = @import("std");

pub fn main() !void {
    var stdin_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&.{});
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);

    try stdout_writer.interface.print("Please enter a dice algebra expression: ", .{});

    const roll = try stdin_reader.interface.takeDelimiterExclusive('\n');

    try stdout_writer.interface.print("You wrote: {s}\n", .{roll});
}

const ErrInfo = struct {
    message: []u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, message: *[]u8) !*@This() {
        var err = try allocator.create(@This());
        errdefer allocator.destroy(err);

        err.message = message;
        err.allocator = allocator;

        return err;
    }

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.message);
        self.allocator.destroy(self);
    }
};

const TokenType = enum { number, d, h, l, add, subtract, multiply, divide, open_paren, close_paren };

const Token = struct { token_type: TokenType, integer: u64 };

fn tokenize(allocator: std.mem.Allocator, str: []u8, err: **ErrInfo) !std.ArrayList(Token) {
    const tokens: std.ArrayList(Token) = .empty;

    for (str) |asciiChar| {
        var got_token = false;
        var token_type: TokenType = undefined;
        var ongoing_int_str: std.ArrayList(u8) = .empty;

        switch (asciiChar) {
            '0'...'9' => {
                ongoing_int_str.append(allocator, asciiChar);
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
                err.* = ErrInfo.init(
                    allocator,
                    std.fmt.allocPrint(
                        allocator,
                        "Unexpected character in input: {c}",
                        asciiChar,
                    ),
                );
            },
        }

        if (!got_token) {
            continue;
        }

        if (ongoing_int_str.items.len > 0) {}

        tokens.append(allocator, .{ .token_type = token_type });
    }
}
