const std = @import("std");
const testing = std.testing;
const InterfaceChecker = @import("common.zig").InterfaceChecker;

/// Checks if a the type implments the `Clone` interface.
// pub fn isClone(comptime T: type) InterfaceImplError {
//     comptime {
//         const tinfo = @typeInfo(T);
//         if ((tinfo == .Struct) or (tinfo == .Union)) {
//             if (!@hasDecl(T, "clone")) {
//                 return .{ .valid = false, .reason = .MissingRequiredMethod };
//             } else {
//                 const info = @typeInfo(@TypeOf(@field(T, "clone")));
//                 const num_args = info.Fn.params.len;
//                 const arg_type = info.Fn.params[0].type.?;
//                 const ret_type = info.Fn.return_type.?;
//                 if (num_args != 1) {
//                     return .{ .valid = false, .reason = .InvalidNumArgs };
//                 } else if (arg_type != T) {
//                     return .{ .valid = false, .reason = .InvalidArgType };
//                 } else if (ret_type != T) {
//                     return .{ .valid = false, .reason = .InvalidReturnType };
//                 }
//             }
//         } else {
//             return .{ .valid = false, .reason = .MissingRequiredMethod };
//         }
//         return .{ .valid = true };
//     }
// }

fn checkCloneImpl(comptime T: type, show_err: bool) InterfaceChecker(T) {
    comptime {
        var checker = InterfaceChecker(T){};

        _ = checker.isEnumStructUnion();
        if (checker.reason) |_| {
            if (show_err) {
                @compileError("Invalid implementation type: must be `Struct`, `Enum`, or `Union`");
            }
        }

        _ = checker.hasFunc(.{
            .name = "clone",
            .num_args = 1,
            .arg_types = &[_]type{T},
            .ret_type = &[_]type{T},
        });
        if (checker.reason) |r| {
            if (show_err) {
                switch (r) {
                    .MissingRequiredMethod => @compileError("`clone(" ++ @typeName(T) ++ ") " ++ @typeName(T) ++ "` must be implemented by " ++ @typeName(T)),
                    .InvalidNumArgs => @compileError("The `clone` function must have only 1 parameter"),
                    .InvalidArgType => @compileError("The `clone` function must have one parameter of type `" ++ @typeName(T) ++ "`"),
                    .InvalidReturnType => @compileError("The `clone` function must return `" ++ @typeName(T) ++ "`"),
                    else => unreachable,
                }
            }
        }

        return checker;
    }
}

pub fn isClone(comptime T: type) bool {
    comptime {
        const checker = checkCloneImpl(T, false);
        if (checker.reason) |_| {
            return false;
        }
        return true;
    }
}

/// An interface for a cloneable type.
pub fn Clone(comptime Self: type) type {
    comptime checkCloneImpl(Self, true);
    // comptime {
    //     const impl = isClone(Self);
    //     if (!impl.valid) {
    //         const tname = @typeName(Self);
    //         switch (impl.reason.?) {
    //             .MissingRequiredMethod => {
    //                 @compileError("`clone(" ++ tname ++ ") " ++ tname ++ "` must be implemented by " ++ tname);
    //             },
    //             .InvalidNumArgs => {
    //                 @compileError("The `clone` function must have only 1 parameter");
    //             },
    //             .InvalidArgType => {
    //                 @compileError("The `clone` function must have one parameter of type `*" ++ tname ++ "` or `*const " ++ tname ++ "`");
    //             },
    //             .InvalidReturnType => {
    //                 @compileError("The `clone` function must return `" ++ tname ++ "`");
    //             },
    //             else => unreachable,
    //         }
    //     }
    // }

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
