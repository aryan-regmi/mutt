const std = @import("std");
const testing = std.testing;

/// Returns `true` if the type implements the `Iterable` interface.
pub fn isIterable(comptime T: type) bool {
    return @hasDecl(T, "mutt.Iterable") and @hasDecl(T, "iter");
}

/// An iterable interface.
pub fn Iterable(comptime Context: type, comptime Item: type, comptime methods: struct {
    next: ?fn (Context) ?Item = null,
}) type {
    return struct {
        /// The interface type for an `Iterable`.
        pub const @"mutt.Iterable" = struct {
            context: Context,
            pub const ItemType = Item;

            /// Returns the next item in the iterator.
            pub fn next(self: @This()) ?Item {
                if (methods.next) |f| {
                    return f(self.context);
                }

                @compileError("`next` is unimplemented");
            }

            // TODO: Add `enumerate` method (Create `mutt.Enumerable` type that has a counter in the struct)
            //  - the method will return .{.idx: usize, .val: Context};
        };

        /// Returns an `Iterable` interface value.
        pub fn iter(self: Context) @"mutt.Iterable" {
            return .{ .context = self };
        }
    };
}

test "Create Iterable" {
    const Tst = struct {
        const Self = @This();
        const Item = u8;
        pub usingnamespace Iterable(*Self, Item, .{
            .next = next,
        });

        data: []u8,
        idx: usize = 0,

        fn next(self: *Self) ?Item {
            if (self.idx < self.data.len) {
                self.idx += 1;
                return self.data[self.idx - 1];
            }
            return null;
        }
    };

    var data = [_]u8{ 1, 2, 3, 4, 5 };
    var tst = Tst{ .data = &data };

    var i: usize = 0;
    const iter = tst.iter();
    while (iter.next()) |v| {
        try testing.expectEqual(v, data[i]);
        i += 1;
    }
}
