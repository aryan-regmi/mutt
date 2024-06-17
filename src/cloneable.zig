const std = @import("std");
const testing = std.testing;

/// An interface for a cloneable type.
pub fn Cloneable(comptime Context: type, comptime methods: struct {
    clone: ?fn (Context) Context = null,
    cloneFrom: ?fn (*Context, Context) void = null,
}) type {
    return struct {
        /// Returns a copy of `self`.
        pub fn clone(self: Context) Context {
            if (methods.clone) |f| {
                return f(self);
            }

            @compileError("`clone` is unimplemented");
        }

        /// Performs copy-assignment from `src`.
        ///
        /// # Note
        /// `a.cloneFrom(b)` is equivalent to `a = b.clone()`.
        /// This can be overridden (by providing a `cloneFrom` implementation)
        /// to reuse the resources of `a` to avoid unnecessary allocations.
        pub fn cloneFrom(self: *Context, src: Context) void {
            if (methods.cloneFrom) |f| {
                return f(self, src);
            }

            self.* = src.clone();
        }
    };
}

test "Create Cloneable" {
    const Tst = struct {
        const Self = @This();
        pub usingnamespace Cloneable(Self, .{
            .clone = cloneImpl,
        });

        data: u8,

        fn cloneImpl(self: Self) Self {
            return Self{ .data = self.data + 1 };
        }
    };

    const tst = Tst{ .data = 2 };
    const cloned = tst.clone();
    var cloned2: Tst = undefined;
    cloned2.cloneFrom(cloned);

    try testing.expectEqual(tst.data, 2);
    try testing.expectEqual(cloned.data, 3);
    try testing.expectEqual(cloned2.data, 4);
}
