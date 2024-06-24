const std = @import("std");
const testing = std.testing;
const InterfaceImplError = @import("common.zig").InterfaceImplError;

/// Checks if a the type implments the `Clone` interface.
pub fn isClone(comptime T: type) InterfaceImplError {
    comptime {
        const tinfo = @typeInfo(T);
        if ((tinfo == .Struct) or (tinfo == .Union)) {
            if (!@hasDecl(T, "clone")) {
                return .{ .valid = false, .reason = .MissingRequiredMethod };
            } else {
                const info = @typeInfo(@TypeOf(@field(T, "clone")));
                const num_args = info.Fn.params.len;
                const arg_type = info.Fn.params[0].type.?;
                const ret_type = info.Fn.return_type.?;
                if (num_args != 1) {
                    return .{ .valid = false, .reason = .InvalidNumArgs };
                } else if (arg_type != T) {
                    return .{ .valid = false, .reason = .InvalidArgType };
                } else if (ret_type != T) {
                    return .{ .valid = false, .reason = .InvalidReturnType };
                }
            }
        } else {
            return .{ .valid = false, .reason = .MissingRequiredMethod };
        }
        return .{ .valid = true };
    }
}

/// An interface for a cloneable type.
pub fn Clone(comptime Self: type) type {
    comptime {
        const impl = isClone(Self);
        if (!impl.valid) {
            const tname = @typeName(Self);
            switch (impl.reason.?) {
                .MissingRequiredMethod => {
                    @compileError("`clone(" ++ tname ++ ") " ++ tname ++ "` must be implemented by " ++ tname);
                },
                .InvalidNumArgs => {
                    @compileError("The `clone` function must have only 1 parameter");
                },
                .InvalidArgType => {
                    @compileError("The `clone` function must have one parameter of type `*" ++ tname ++ "` or `*const " ++ tname ++ "`");
                },
                .InvalidReturnType => {
                    @compileError("The `clone` function must return `" ++ tname ++ "`");
                },
                else => unreachable,
            }
        }
    }

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
