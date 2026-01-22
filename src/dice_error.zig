const std = @import("std");

pub const DiceError = error{
    InvalidInput,
};

pub const ErrInfo = struct {
    message: []u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, message: []u8) !*@This() {
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
