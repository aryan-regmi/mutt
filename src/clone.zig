const std = @import("std");
const testing = std.testing;

/// An interface for a cloneable type.
pub fn Clone(comptime Self: type) type {
    comptime if (!@hasDecl(Self, "clone")) {
        const tname = @typeName(Self);
        @compileError("`clone(" ++ tname ++ ") " ++ tname ++ "` must be implemented by " ++ tname);
    } else {
        const info = @typeInfo(@TypeOf(@field(Self, "clone")));
        const num_args = info.Fn.params.len;
        const arg_type = info.Fn.params[0].type.?;
        const ret_type = info.Fn.return_type.?;

        if (num_args != 1) {
            @compileError("The `clone` function must have only 1 parameter");
        } else if (arg_type != Self) {
            @compileError("The `clone` function must have one parameter of type `*" ++ @typeName(Self) ++ "` or `*const " ++ @typeName(Self) ++ "`");
        } else if (ret_type != Self) {
            @compileError("The `clone` function must return `" ++ @typeName(Self) ++ "`");
        }
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
