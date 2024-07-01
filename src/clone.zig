const std = @import("std");
const testing = std.testing;
const InterfaceChecker = @import("common.zig").InterfaceChecker;

/// Checks if a the type implments the `Clone` interface.
fn checkCloneImpl(comptime T: type, print_errors: bool) *InterfaceChecker(T) {
    comptime {
        var checker = InterfaceChecker(T){ .print_error = print_errors };
        return checker
            .isEnumStructUnion()
            .hasFunc(.{
            .name = "clone",
            .num_args = 1,
            .arg_types = &[_]type{T},
            .ret_type = &[_]type{T},
        });
    }
}

/// Returns `true` if `T` implments the `Clone` interface.
pub fn isClone(comptime T: type) bool {
    comptime {
        const checker = checkCloneImpl(T, false);
        return checker.valid;
    }
}

fn hasCloneFromFn(comptime T: type) bool {
    var checker = InterfaceChecker(T){ .print_error = false };
    return checker.isEnumStructUnion().hasFunc(.{
        .name = "cloneFrom",
        .num_args = 2,
        .arg_types = &[_]type{ *T, T },
        .ret_type = &[_]type{void},
    }).valid;
}

/// An interface for a cloneable type.
///
/// # Note
/// Implementations must provide a `clone` function.
pub fn Clone(comptime Self: type) type {
    comptime _ = checkCloneImpl(Self, true);
    comptime if (hasCloneFromFn(Self)) {
        return struct {};
    } else {
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
