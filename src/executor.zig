const std = @import("std");
const DiceError = @import("dice_error.zig").DiceError;
const ErrInfo = @import("dice_error.zig").ErrInfo;
const Parser = @import("parser.zig");
const Tree = Parser.Tree;
const MathOperation = Parser.MathOperation;

pub const ExecuteResult = struct {
    result: i128,
    description: []u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, result: i128, description: []u8) !*@This() {
        var newExecuteResult = try allocator.create(@This());
        errdefer allocator.destroy(newExecuteResult);

        const newDescription = try allocator.dupe(u8, description);

        newExecuteResult.result = result;
        newExecuteResult.description = newDescription;
        newExecuteResult.allocator = allocator;

        return newExecuteResult;
    }

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.description);
        self.allocator.destroy(self);
    }
};

pub fn execute(allocator: std.mem.Allocator, tree: *Tree, err_info: **ErrInfo) DiceError!*ExecuteResult {
    switch (tree.node) {
        .integer => |node| {
            return execute_integer(allocator, &node);
        },
        .shortroll => |node| {
            return execute_shortroll(allocator, &node);
        },
        .longroll => |node| {
            return execute_longroll(allocator, &node);
        },
        .math => |node| {
            return execute_math(allocator, &node, err_info);
        },
    }
}

fn execute_integer(allocator: std.mem.Allocator, node: *const Parser.IntegerNode) DiceError!*ExecuteResult {
    return try ExecuteResult.init(allocator, node.integer, "");
}

fn execute_shortroll(allocator: std.mem.Allocator, node: *const Parser.ShortRollNode) DiceError!*ExecuteResult {
    const roll = std.crypto.random.intRangeAtMost(i128, 1, node.faces);
    const description = try std.fmt.allocPrint(
        allocator,
        "\nRolling d{d}...\nYou rolled: {d}\n",
        .{ node.faces, roll },
    );
    defer allocator.free(description);

    return try ExecuteResult.init(allocator, roll, description);
}

fn execute_longroll(allocator: std.mem.Allocator, node: *const Parser.LongRollNode) DiceError!*ExecuteResult {
    var description = std.Io.Writer.Allocating.init(allocator);
    defer description.deinit();

    var rolls: std.ArrayList(i128) = .empty;
    defer rolls.deinit(allocator);

    try description.writer.print("\nRolling {d}d{d}...\n", .{ node.die, node.faces });

    var sum: i128 = 0;

    for (0..node.die) |_| {
        const roll = std.crypto.random.intRangeAtMost(i128, 1, node.faces);

        sum += roll;
        try rolls.append(allocator, roll);
        try description.writer.print("You rolled: {d}\n", .{roll});
    }

    if (node.keep_high) |keep_high| {
        if (keep_high < node.die) {
            sum = 0;
            std.mem.sort(i128, rolls.items, {}, comptime std.sort.desc(i128));

            for (0..keep_high) |i| {
                sum += rolls.items[i];
            }
        }
    } else if (node.keep_low) |keep_low| {
        if (keep_low < node.die) {
            sum = 0;
            std.mem.sort(i128, rolls.items, {}, comptime std.sort.asc(i128));

            for (0..keep_low) |i| {
                sum += rolls.items[i];
            }
        }
    }

    return try ExecuteResult.init(allocator, sum, description.written());
}

fn execute_math(allocator: std.mem.Allocator, node: *const Parser.MathNode, err_info: **ErrInfo) DiceError!*ExecuteResult {
    const left = try execute(allocator, node.left_operand, err_info);
    defer left.deinit();

    const right = try execute(allocator, node.right_operand, err_info);
    defer right.deinit();

    var result: i128 = undefined;
    switch (node.operation) {
        MathOperation.add => {
            result = left.result + right.result;
        },
        MathOperation.subtract => {
            result = left.result - right.result;
        },
        MathOperation.multiply => {
            result = left.result * right.result;
        },
        MathOperation.divide => {
            if (right.result == 0) {
                err_info.* = try ErrInfo.init(allocator, "Division by zero.");
                return DiceError.InvalidInput;
            }

            result = @divFloor(left.result, right.result);
        },
    }

    const combinedDescription = try std.fmt.allocPrint(
        allocator,
        "{s}{s}",
        .{ left.description, right.description },
    );
    defer allocator.free(combinedDescription);

    return try ExecuteResult.init(allocator, result, combinedDescription);
}
