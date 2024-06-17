const std = @import("std");
const testing = std.testing;

// /// An iterable interface.
// pub fn Iterable(comptime Context: type, comptime Item: type, comptime methods: struct {
//     next: ?fn (*Context) ?Item = null,
// }) type {
//     return struct {
//         /// The interface type for an `Iterable`.
//         pub const @"mutt.Iterable" = struct {
//             context: *Context,
//             pub const ItemType = Item;
//
//             /// Returns the next item in the iterator.
//             pub fn next(self: @This()) ?Item {
//                 if (methods.next) |f| {
//                     return f(self.context);
//                 }
//
//                 @compileError("`next` is unimplemented");
//             }
//
//             // TODO: Add `enumerate` method (Create `mutt.Enumerable` type that has a counter in the struct)
//             //  - the method will return .{.idx: usize, .val: Context};
//         };
//
//         /// Returns an `Iterable` interface value.
//         pub fn iter(self: Context) @"mutt.Iterable" {
//             return .{ .context = self };
//         }
//     };
// }

/// An interface for types that can be turned into an `Iterator`.
pub fn IntoIter(comptime Self: type, comptime Item: type) type {
    comptime if (!@hasDecl(Self, "iter")) {
        const self_type = @typeName(Self);
        const item_type = @typeName(Item);
        @compileError("`iter(*" ++ self_type ++ ") Iterator(" ++ self_type ++ ", " ++ item_type ++ ")" ++ "` must be implemented by " ++ self_type);
    };

    return struct {};
}

/// An interface for iterable types.
pub fn Iterator(comptime Self: type, comptime Item: type) type {
    comptime if (!@hasDecl(Self, "next")) {
        const self_type = @typeName(Self);
        const item_type = @typeName(Item);
        @compileError("`next(*" ++ self_type ++ ") ?*" ++ item_type ++ "` must be implemented by " ++ self_type);
    };

    return struct {};
}

test "Create Iterable" {
    const Container = struct {
        const Self = @This();
        const Item = u8;

        pub usingnamespace IntoIter(Self, Item);
        pub const Iter = struct {
            pub usingnamespace Iterator(Iter, Item);

            container: *Self,
            idx: usize = 0,

            /// Returns the next item in the iterator.
            pub fn next(self: *Iter) ?*Item {
                if (self.idx < self.container.data.len) {
                    self.idx += 1;
                    return &self.container.data[self.idx - 1];
                }
                return null;
            }
        };

        data: []u8,

        /// Returns an `Iterator` over `self`.
        pub fn iter(self: *Self) Iter {
            return .{ .container = self };
        }
    };

    const original_data = [_]u8{ 1, 2, 3, 4, 5 };
    var data = [_]u8{ 1, 2, 3, 4, 5 };
    var container = Container{ .data = &data };

    var iter = container.iter();
    while (iter.next()) |v| {
        v.* += 1;
    }

    var i: usize = 0;
    var iter2 = container.iter();
    while (iter2.next()) |v| {
        try testing.expectEqual(original_data[i] + 1, v.*);
        i += 1;
    }
}
