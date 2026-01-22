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

    try stdout.interface.print("{s}\nYour result is: {d}\n", .{ result.description, result.result });
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
