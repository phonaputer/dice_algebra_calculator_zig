const std = @import("std");
const DiceError = @import("dice_error.zig").DiceError;
const ErrInfo = @import("dice_error.zig").ErrInfo;
const Lexer = @import("lexer.zig");

fn run(
    allocator: std.mem.Allocator,
    errInfo: **ErrInfo,
) !void {
    var stdin_buffer: [1024]u8 = undefined;
    var stdin = std.fs.File.stdin().reader(&stdin_buffer);
    var stdout = std.fs.File.stdout().writer(&.{});

    try stdout.interface.print("Please enter a dice algebra expression: ", .{});
    const roll = try stdin.interface.takeDelimiterExclusive('\n');

    const tokens = try Lexer.tokenize(allocator, roll, errInfo);
    defer allocator.free(tokens);

    for (tokens) |token| {
        try stdout.interface.print(
            "Got token: {s}, {d}\n",
            .{ @tagName(token.token_type), token.integer },
        );
    }
}

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var stdout = std.fs.File.stdout().writer(&.{});

    var errInfo: *ErrInfo = undefined;

    run(allocator, &errInfo) catch |err| switch (err) {
        DiceError.InvalidInput => {
            try stdout.interface.print("ERROR! Invalid input: {s}\n", .{errInfo.message});
            errInfo.deinit();
            return;
        },
        else => {
            try stdout.interface.print("ERROR! Unexpected error: {}\n", .{err});
            return;
        },
    };
}
