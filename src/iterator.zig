const std = @import("std");
const testing = std.testing;

/// An interface for types that can be turned into an `Iterator`.
pub fn IntoIter(comptime Self: type, comptime Item: type) type {
    comptime if (!@hasDecl(Self, "iter")) {
        const self_type = @typeName(Self);
        const item_type = @typeName(Item);
        @compileError("`iter(*" ++ self_type ++ ") Iterator(" ++ self_type ++ ", " ++ item_type ++ ")" ++ "` must be implemented by " ++ self_type);
    } else {
        const info = @typeInfo(@TypeOf(@field(Self, "iter")));
        const num_args = info.Fn.params.len;
        const arg_type = info.Fn.params[0].type.?;

        if (num_args != 1) {
            @compileError("The `iter` function must have only 1 parameter");
        } else if (arg_type != *Self) {
            @compileError("The `iter` function must have one parameter of type `*" ++ @typeName(Self) ++ "`");
        }
    };

    return struct {};
}

/// An interface for iterable types.
pub fn Iterator(comptime Self: type, comptime Item: type) type {
    // NOTE: Abstract away interface checks to a separate function?
    comptime {
        if (!@hasDecl(Self, "next")) {
            @compileError("`next(*" ++ @typeName(Self) ++ ") ?" ++ @typeName(Item) ++ "` must be implemented by " ++ @typeName(Self));
        } else {
            const info = @typeInfo(@TypeOf(@field(Self, "next")));
            const num_args = info.Fn.params.len;
            const arg_type = info.Fn.params[0].type.?;
            const ret_type = info.Fn.return_type.?;

            if (num_args != 1) {
                @compileError("The `next` function must have only 1 parameter");
            } else if ((arg_type != *Self) and (arg_type != *const Self)) {
                @compileError("The `next` function must have one parameter of type `*" ++ @typeName(Self) ++ "` or `*const " ++ @typeName(Self) ++ "`");
            } else if (ret_type != ?Item) {
                const err = blk: {
                    switch (@typeInfo(Item)) {
                        .Struct => {
                            // Enumerator `Item` types are valid
                            if ((@hasDecl(Item, "ItemType")) and (Item == IndexedItem(Item.ItemType))) {
                                break :blk false;
                            }
                        },
                        else => {
                            break :blk true;
                        },
                    }
                };
                if (err) {
                    @compileError("The `next` function must return a `?" ++ @typeName(Item) ++ "`" ++ " (returns `" ++ @typeName(ret_type) ++ "`)");
                }
            }
        }
    }

    return struct {
        /// Creates an iterator that tracks the current iteration count as well as the next value.
        ///
        /// The iterator returns an `Enumerator(Self, Item).Tuple` with an `idx`
        /// that is the current index of iteration and a `val` that is the value
        /// returned by the iterator.
        pub fn enumerate(self: *const Self) Enumerator(Self, Item) {
            return Enumerator(Self, Item){ .it = @constCast(self) };
        }

        /// Returns `true` if *every* element of the iterator matches the predicate.
        ///
        /// This is short-circuiting; it will return early if the predicate
        /// returns `false` for any item.
        pub fn all(self: *Self, predicate: fn (Item) bool) bool {
            while (self.next()) |v| {
                if (predicate(v) == false) {
                    return false;
                }
            }
            return true;
        }

        /// Returns `true` if *any* element of the iterator matches the predicate.
        ///
        /// This is short-circuiting; it will return early if the predicate
        /// returns `true` for any item.
        pub fn any(self: *Self, predicate: fn (Item) bool) bool {
            while (self.next()) |v| {
                if (predicate(v) == true) {
                    return true;
                }
            }
            return false;
        }

        /// Returns the first element of the iterator that matches the predicate.
        ///
        /// If nothing matches, `null` is returned.
        pub fn find(self: *Self, predicate: fn (Item) bool) ?Item {
            while (self.next()) |v| {
                if (predicate(v) == true) {
                    return v;
                }
            }
            return null;
        }
    };
}

/// The type returned by an `Enumerator`.
///
/// It keeps track of the iteration count of the value.
pub fn IndexedItem(comptime Item: type) type {
    return struct {
        pub const ItemType = Item;
        idx: usize,
        val: Item,
    };
}

/// An iterator that returns the current count and the element.
pub fn Enumerator(comptime Self: type, comptime Item: type) type {
    return struct {
        it: *Self,
        count: usize = 0,

        pub usingnamespace Iterator(Self, IndexedItem(Item));
        pub const Tuple = struct {
            pub const ItemType = Item;
            idx: usize,
            val: Item,
        };

        pub fn next(self: *@This()) ?IndexedItem(Item) {
            const val = self.it.next();
            if (val != null) {
                self.count += 1;
                const out = .{ .idx = self.count - 1, .val = val.? };
                return out;
            }
            return null;
        }
    };
}

const TestIter = struct {
    const Container = struct {
        const Self = @This();
        const Item = *u8;
        data: []u8,

        pub usingnamespace IntoIter(Self, Item);

        pub const Iter = struct {
            container: *Self,
            idx: usize = 0,

            pub usingnamespace Iterator(Iter, Item);

            /// Returns the next item in the iterator.
            pub fn next(self: *Iter) ?Item {
                if (self.idx < self.container.data.len) {
                    self.idx += 1;
                    return &self.container.data[self.idx - 1];
                }
                return null;
            }
        };

        /// Returns an `Iterator` over `self`.
        pub fn iter(self: *Self) Iter {
            return .{ .container = self };
        }
    };
};

test "Create Iterable" {
    const original_data = [_]u8{ 1, 2, 3, 4, 5 };
    var data = [_]u8{ 1, 2, 3, 4, 5 };
    var container = TestIter.Container{ .data = &data };

    var iter = container.iter();
    while (iter.next()) |v| {
        v.* += 1;
    }

    var en = container.iter().enumerate();
    while (en.next()) |v| {
        v.val.* += 1;
        try testing.expectEqual(original_data[v.idx] + 2, v.val.*);
    }
}
