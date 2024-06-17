// pub const Iterable = @import("iterable.zig").Iterable;
pub const Cloneable = @import("cloneable.zig").Clone;

test {
    @import("std").testing.refAllDecls(@This());
}
