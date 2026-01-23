const std = @import("std");
const DiceError = @import("dice_error.zig").DiceError;
const ErrInfo = @import("dice_error.zig").ErrInfo;
const Lexer = @import("lexer.zig");
const Parser = @import("parser.zig");
const Executor = @import("executor.zig");

fn run(
    allocator: std.mem.Allocator,
    err_info: **ErrInfo,
) !void {
    var argsIterator = try std.process.ArgIterator.initWithAllocator(allocator);
    defer argsIterator.deinit();

    var verbose = false;
    _ = argsIterator.next(); // ditch the exe file
    if (argsIterator.next()) |arg| {
        verbose = std.mem.eql(u8, "--v", arg);
    }

    var stdin_buffer: [1024]u8 = undefined;
    var stdin = std.fs.File.stdin().reader(&stdin_buffer);
    var stdout = std.fs.File.stdout().writer(&.{});

    try stdout.interface.print("Please enter a dice algebra expression: ", .{});
    const roll = try stdin.interface.takeDelimiterExclusive('\n');

    const tokens = try Lexer.tokenize(allocator, roll, err_info);
    defer allocator.free(tokens);

    const tree = try Parser.parse(allocator, tokens, err_info);
    defer tree.deinit();

    const result = try Executor.execute(allocator, tree, err_info);
    defer result.deinit();

    if (verbose) {
        try stdout.interface.print("{s}\n", .{result.description});
    }
    try stdout.interface.print("Your result is: {d}\n", .{result.result});
}

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var stdout = std.fs.File.stdout().writer(&.{});

    var err_info: *ErrInfo = undefined;

    run(allocator, &err_info) catch |err| switch (err) {
        DiceError.InvalidInput => {
            try stdout.interface.print("ERROR! {s}\n", .{err_info.message});
            err_info.deinit();
            return;
        },
        DiceError.BadLogic => {
            try stdout.interface.print("ERROR! Unexpected error.\n{s}\n", .{err_info.message});
            err_info.deinit();
            return;
        },
        else => {
            try stdout.interface.print("ERROR! Unexpected error.\n{}\n", .{err});
            return;
        },
    };
}

test {
    std.testing.refAllDeclsRecursive(@This());
}

test "execute - input with all the fixings - computes correct result" {
    var err_info: *ErrInfo = undefined;
    const allocator = std.testing.allocator;

    // (10d1 + 1) * (5d1h2 - 4d1l1) / 2
    var input = [_]Lexer.Token{
        .{ .token_type = Lexer.TokenType.open_paren, .integer = 0 },
        .{ .token_type = Lexer.TokenType.number, .integer = 10 },
        .{ .token_type = Lexer.TokenType.d, .integer = 0 },
        .{ .token_type = Lexer.TokenType.number, .integer = 1 },
        .{ .token_type = Lexer.TokenType.add, .integer = 0 },
        .{ .token_type = Lexer.TokenType.number, .integer = 1 },
        .{ .token_type = Lexer.TokenType.close_paren, .integer = 0 },
        .{ .token_type = Lexer.TokenType.multiply, .integer = 0 },
        .{ .token_type = Lexer.TokenType.open_paren, .integer = 0 },
        .{ .token_type = Lexer.TokenType.number, .integer = 5 },
        .{ .token_type = Lexer.TokenType.d, .integer = 0 },
        .{ .token_type = Lexer.TokenType.number, .integer = 1 },
        .{ .token_type = Lexer.TokenType.h, .integer = 0 },
        .{ .token_type = Lexer.TokenType.number, .integer = 2 },
        .{ .token_type = Lexer.TokenType.subtract, .integer = 0 },
        .{ .token_type = Lexer.TokenType.number, .integer = 4 },
        .{ .token_type = Lexer.TokenType.d, .integer = 0 },
        .{ .token_type = Lexer.TokenType.number, .integer = 1 },
        .{ .token_type = Lexer.TokenType.l, .integer = 0 },
        .{ .token_type = Lexer.TokenType.number, .integer = 1 },
        .{ .token_type = Lexer.TokenType.close_paren, .integer = 0 },
        .{ .token_type = Lexer.TokenType.divide, .integer = 0 },
        .{ .token_type = Lexer.TokenType.number, .integer = 2 },
    };

    const parsed = try Parser.parse(allocator, input[0..], &err_info);
    defer parsed.deinit();
    const result = try Executor.execute(allocator, parsed, &err_info);
    defer result.deinit();

    try std.testing.expectEqual(5, result.result);
    try std.testing.expectEqualStrings(
        "\nRolling 10d1...\nYou rolled: 1\nYou rolled: 1\nYou rolled: 1\nYou rolled: 1\nYou rolled: 1" ++
            "\nYou rolled: 1\nYou rolled: 1\nYou rolled: 1\nYou rolled: 1\nYou rolled: 1\n\nRolling 5d1...\n" ++
            "You rolled: 1\nYou rolled: 1\nYou rolled: 1\nYou rolled: 1\nYou rolled: 1\n\nRolling 4d1...\n" ++
            "You rolled: 1\nYou rolled: 1\nYou rolled: 1\nYou rolled: 1\n",
        result.description,
    );
}
