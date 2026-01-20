const std = @import("std");

pub fn main() !void {
    var stdin_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&.{});
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);

    try stdout_writer.interface.print("Please enter a dice algebra expression: ", .{});

    const roll = try stdin_reader.interface.takeDelimiterExclusive('\n');

    try stdout_writer.interface.print("You wrote: {s}\n", .{roll});
}
