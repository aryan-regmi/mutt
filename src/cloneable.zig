const std = @import("std");
const testing = std.testing;

/// An interface for a cloneable type.
pub fn Clone(comptime Self: type) type {
    // FIXME: Check function signature
    comptime if (!@hasDecl(Self, "clone")) {
        const tname = @typeName(Self);
        @compileError("`clone(" ++ tname ++ ") " ++ tname ++ "` must be implemented by " ++ tname);
    };

    return struct {
        /// Performs copy-assignment from `src`.
        ///
        /// # Note
        /// `a.cloneFrom(b)` is equivalent to `a = b.clone()`.
        /// This can be overridden (by providing a `cloneFrom` implementation)
        /// to reuse the resources of `a` to avoid unnecessary allocations.
        pub fn cloneFrom(self: *Self, src: Self) void {
            self.* = src.clone();
        }
    };
}

test "Create Cloneable" {
    const Tst = struct {
        const Self = @This();
        pub usingnamespace Clone(Self);

        data: u8,

        /// Returns a copy of `self`.
        pub fn clone(self: Self) Self {
            return .{ .data = self.data + 1 };
        }
    };
    const tst = Tst{ .data = 1 };

    const cloned = tst.clone();
    try testing.expectEqual(2, cloned.data);

    var cloned2: Tst = undefined;
    cloned2.cloneFrom(cloned);
    try testing.expectEqual(3, cloned2.data);
}
