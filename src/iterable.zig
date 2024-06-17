const std = @import("std");
const testing = std.testing;

// TODO: Use builtin reflection functions to check function signatures!

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
    comptime if (!@hasDecl(Self, "next")) {
        const self_type = @typeName(Self);
        const item_type = @typeName(Item);
        @compileError("`next(*" ++ self_type ++ ") ?" ++ item_type ++ "` must be implemented by " ++ self_type);
    } else {
        const info = @typeInfo(@TypeOf(@field(Self, "next")));
        const num_args = info.Fn.params.len;
        const arg_type = info.Fn.params[0].type.?;
        const ret_type = info.Fn.return_type.?;

        if (num_args != 1) {
            @compileError("The `next` function must have only 1 parameter");
        } else if ((arg_type != *Self) and (arg_type != *const Self)) {
            @compileError("The `next` function must have one parameter of type `*" ++ @typeName(Self) ++ "` or `*const " ++ @typeName(Self) ++ "`");
        } else if ((ret_type != ?Item) and (ret_type != ?Enumerator(Self, Item).Tuple)) {
            @compileError("The `next` function must return a `?" ++ @typeName(Item) ++ "`" ++ " (returns `" ++ @typeName(ret_type) ++ "`)");
        }
    };

    return struct {
        /// Creates an iterator that tracks the current iteration count as well as the next value.
        ///
        /// The iterator returns an `Enumerator(Self, Item).Tuple` with an `idx`
        /// that is the current index of iteration and a `val` that is the value
        /// returned by the iterator.
        pub fn enumerate(self: *const Self) Enumerator(Self, Item) {
            return Enumerator(Self, Item){ .it = @constCast(self) };
        }
    };
}

pub fn IndexItem(comptime Item: type) type {
    return struct {
        idx: usize,
        val: Item,
    };
}

// pub const IndexItem = struct {
//     idx: usize,
//     item: Item
// };

/// An iterator that returns the current count and the element.
pub fn Enumerator(comptime Self: type, comptime Item: type) type {
    return struct {
        it: *anyopaque,
        count: usize = 0,

        pub usingnamespace Iterator(Self, Tuple);
        pub const Tuple = struct {
            idx: usize,
            val: Item,
        };

        pub fn next(self: *@This()) ?Tuple {
            var actual_iter: *Self = @ptrCast(@alignCast(self.it));
            const val = actual_iter.next();
            if (val != null) {
                self.count += 1;
                const out = .{ .idx = self.count - 1, .val = val.? };
                return out;
            }
            return null;
        }
    };
}

test "Create Iterable" {
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

    const original_data = [_]u8{ 1, 2, 3, 4, 5 };
    var data = [_]u8{ 1, 2, 3, 4, 5 };
    var container = Container{ .data = &data };

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
