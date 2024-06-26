const std = @import("std");
const testing = std.testing;
const cloneable = @import("clone.zig");
const common = @import("common.zig");
const InterfaceChecker = common.InterfaceChecker;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

// TODO: Add overflow checks!

/// Checks if a the type implments the `IntoIter` interface.
fn checkIntoIterImpl(comptime T: type, print_errors: bool) *InterfaceChecker(T) {
    comptime {
        var checker = InterfaceChecker(T){ .print_error = print_errors };
        return checker.isEnumStructUnion().hasFunc(.{
            .name = "iter",
            .num_args = 1,
            .arg_types = &[_]type{*T},
        });
    }
}

/// Returns `true` if `T` implments the `IntoIter` interface.
pub fn isIntoIter(comptime T: type) bool {
    comptime {
        const checker = checkIntoIterImpl(T, false);
        return checker.valid;
    }
}

/// An interface for types that can be turned into an `Iterator`.
pub fn IntoIter(comptime Self: type) type {
    comptime _ = checkIntoIterImpl(Self, true);

    return struct {
        /// Resets the given iterator.
        pub fn resetIter(self: *Self, it: anytype) void {
            comptime {
                const info = @typeInfo(@TypeOf(it));
                switch (info) {
                    .Pointer => {
                        const impl = isIterator(info.Pointer.child);
                        if (!impl) {
                            @compileError("`it` must be a valid `Iterator`");
                        }
                    },
                    else => {
                        @compileError("`it` must be a pointer to a valid `Iterator`");
                    },
                }
            }

            it.* = self.iter();
        }
    };
}

/// Checks if a the type implments the `IntoIter` interface.
fn checkIteratorImpl(comptime T: type, comptime I: type, print_errors: bool) *InterfaceChecker(T) {
    comptime {
        var checker = InterfaceChecker(T){ .print_error = print_errors };
        return checker
            .isEnumStructUnion()
            .hasAssociatedType("ItemType")
            .hasFunc(.{
            .name = "next",
            .num_args = 1,
            .arg_types = &[_]type{*T},
            .ret_type = &[_]type{?I},
        });
    }
}

/// Returns `true` if `T` implments the `IntoIter` interface.
pub fn isIterator(comptime T: type) bool {
    comptime {
        var valid = true;
        {
            var checker = InterfaceChecker(T){ .print_error = false };
            valid = checker.isEnumStructUnion().valid;
        }

        if (valid) {
            const checker = checkIteratorImpl(T, T.ItemType, false);
            return checker.valid;
        } else {
            return false;
        }
    }
}

/// An interface for iterable types.
pub fn Iterator(comptime Self: type, comptime Item: type) type {
    comptime _ = checkIteratorImpl(Self, Item, true);

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
        pub fn all(self: *Self, predicate: *const fn (Item) bool) bool {
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
        pub fn any(self: *Self, predicate: *const fn (Item) bool) bool {
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
        pub fn find(self: *Self, predicate: *const fn (Item) bool) ?Item {
            while (self.next()) |v| {
                if (predicate(v) == true) {
                    return v;
                }
            }
            return null;
        }

        /// Returns the index of the first element that matches the predicate.
        ///
        /// If nothing matches, `null` is returned.
        pub fn findPos(self: *Self, predicate: *const fn (Item) bool) ?usize {
            var pos: usize = 0;
            while (self.next()) |v| {
                if (predicate(v) == true) {
                    return pos;
                }
                pos += 1;
            }
            return null;
        }

        /// Transforms the iterator into an `ArrayList(Item)`.
        pub fn collect(self: *Self, allocator: Allocator) !ArrayList(Item) {
            var collection = ArrayList(Item).init(allocator);
            while (self.next()) |v| {
                try collection.append(v);
            }
            return collection;
        }

        /// Creates an iterator that clones all of its elements.
        pub fn cloned(self: *const Self) Cloned(Self, Item) {
            return Cloned(Self, Item){ .it = @constCast(self) };
        }

        /// Counts and returns the number of iterations in the iterator.
        ///
        /// This will call `next` until `null` is returned, consuming the iterator.
        pub fn count(self: *const Self) usize {
            var cnt: usize = 0;
            while (@constCast(self).next()) |_| {
                cnt += 1;
            }
            return cnt;
        }

        /// Creates an iterator that only contains elements that return `true` for the predicate.
        pub fn filter(self: *const Self, predicate: *const fn (Item) bool) Filter(Self, Item) {
            return Filter(Self, Item){ .it = @constCast(self), .predicate = predicate };
        }

        /// Creates an iterator that steps by the given amount each iteration.
        ///
        /// # Note
        /// The first element will always be returned, regardless of the step.
        pub fn stepBy(self: *const Self, step: usize) StepBy(Self, Item) {
            return StepBy(Self, Item){ .it = @constCast(self), .step = step };
        }
    };
}

/// The type returned by an `Enumerator`.
///
/// It keeps track of the iteration count of the value.
pub fn IndexedItem(comptime Item: type) type {
    return struct {
        const II = @This();
        pub const ItemType = Item;
        idx: usize,
        val: Item,

        pub usingnamespace if (cloneable.isClone(ItemType)) struct {
            pub fn clone(self: II) II {
                return .{ .idx = self.idx, .val = self.val.clone() };
            }
        } else struct {};
    };
}

/// An iterator that returns the current count and the element.
pub fn Enumerator(comptime Self: type, comptime Item: type) type {
    return struct {
        pub const ItemType = IndexedItem(Item);
        it: *Self,
        count: usize = 0,

        pub usingnamespace Iterator(@This(), ItemType);
        pub const Tuple = struct {
            pub const ItemType = Item;
            idx: usize,
            val: Item,
        };

        pub fn next(self: *@This()) ?ItemType {
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

/// An iterator that clones the elements of the underlying iterator.
pub fn Cloned(comptime Self: type, comptime Item: type) type {
    comptime {
        const impl = cloneable.isClone(Item);
        if (!impl) {
            @compileError("`" ++ @typeName(Item) ++ "` must implement the `Clone` interface");
        }
    }

    return struct {
        pub const ItemType = Item;
        it: *Self,

        pub usingnamespace Iterator(@This(), Item);

        pub fn next(self: *@This()) ?Item {
            const val = self.it.next();
            if (val != null) {
                return val.?.clone();
            }
            return null;
        }
    };
}

/// An iterator that filters the elements of the underlying iterator with a predicate.
pub fn Filter(comptime Self: type, comptime Item: type) type {
    return struct {
        pub const ItemType = Item;
        it: *Self,
        predicate: *const fn (Item) bool,

        pub usingnamespace Iterator(@This(), Item);

        pub fn next(self: *@This()) ?ItemType {
            return self.it.find(self.predicate);
        }
    };
}

/// An iterator that steps through the underlying iterator by a custom amount.
pub fn StepBy(comptime Self: type, comptime Item: type) type {
    return struct {
        pub const ItemType = Item;
        it: *Self,
        step: usize,
        first: bool = true,

        pub usingnamespace Iterator(@This(), ItemType);

        pub fn next(self: *@This()) ?ItemType {
            if (self.first) {
                self.first = false;
                return self.it.next();
            }

            for (0..self.step - 1) |_| {
                _ = self.it.next();
            }

            if (self.it.next()) |v| {
                return v;
            } else {
                return null;
            }
        }
    };
}

const TestIter = struct {
    const Container = struct {
        const Self = @This();
        data: []u8,

        pub usingnamespace IntoIter(Self);

        pub const Iter = struct {
            container: *Self,
            idx: usize = 0,

            pub const ItemType = *u8;
            pub usingnamespace Iterator(Iter, ItemType);

            /// Returns the next item in the iterator.
            pub fn next(self: *Iter) ?ItemType {
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

    const CloneableContainer = struct {
        const Self = @This();
        data: []CloneItem,

        pub const CloneItem = struct {
            data: usize,

            pub usingnamespace cloneable.Clone(CloneItem);

            pub fn clone(self: CloneItem) CloneItem {
                return .{ .data = self.data * 2 };
            }
        };

        pub usingnamespace IntoIter(Self);

        pub const Iter = struct {
            container: *Self,
            idx: usize = 0,

            pub const ItemType = CloneItem;
            pub usingnamespace Iterator(Iter, ItemType);

            pub fn next(self: *Iter) ?ItemType {
                if (self.idx < self.container.data.len) {
                    self.idx += 1;
                    return self.container.data[self.idx - 1];
                }
                return null;
            }
        };

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

    try testing.expectEqual(container.iter().count(), 5);
}

test "Cloneable iterator" {
    const CloneItem = TestIter.CloneableContainer.CloneItem;
    const original_data = [_]CloneItem{ .{ .data = 1 }, .{ .data = 2 }, .{ .data = 3 } };
    var data = [_]CloneItem{ .{ .data = 1 }, .{ .data = 2 }, .{ .data = 3 } };
    var container = TestIter.CloneableContainer{ .data = &data };

    var it = container.iter().cloned().enumerate();
    while (it.next()) |v| {
        try testing.expectEqual(original_data[v.idx].data * 2, v.val.data);
    }
}

test "Filter iterator" {
    const gt3 = struct {
        fn gt3(v: *u8) bool {
            if (v.* > 3) {
                return true;
            }
            return false;
        }
    }.gt3;
    const gt0 = struct {
        pub fn gt0(v: *u8) bool {
            if (v.* > 0) {
                return true;
            }
            return false;
        }
    }.gt0;

    var data = [_]u8{ 1, 2, 3, 4, 5 };
    var container = TestIter.Container{ .data = &data };
    var it = container.iter();

    // Any
    {
        defer container.resetIter(&it);
        const any = it.any(gt3);
        try testing.expect(any);
    }

    // All
    {
        defer container.resetIter(&it);
        const all = it.all(gt0);
        try testing.expect(all);
    }

    // Find
    {
        defer container.resetIter(&it);
        const found = it.find(gt3);
        try testing.expectEqual(4, found.?.*);
    }

    // Find pos
    {
        defer container.resetIter(&it);
        const found_pos = it.findPos(gt3);
        try testing.expectEqual(3, found_pos);
    }

    // Filter
    {
        var filtered = it.filter(gt3);
        try testing.expectEqual(4, filtered.next().?.*);
        try testing.expectEqual(5, filtered.next().?.*);
        try testing.expectEqual(null, filtered.next());
    }
}

test "Collect iterator" {
    const original_data = [_]u8{ 1, 2, 3, 4, 5 };
    var data = [_]u8{ 1, 2, 3, 4, 5 };
    var container = TestIter.Container{ .data = &data };

    var it = container.iter();
    var collection = try it.collect(testing.allocator);
    defer collection.deinit();

    for (collection.items, 0..) |v, i| {
        try testing.expectEqual(original_data[i], v.*);
    }
}

test "Step iterator" {
    var data = [_]u8{ 0, 1, 2, 3, 4, 5 };
    var container = TestIter.Container{ .data = &data };

    var it = container.iter().stepBy(2);
    try testing.expectEqual(0, it.next().?.*);
    try testing.expectEqual(2, it.next().?.*);
    try testing.expectEqual(4, it.next().?.*);
    try testing.expectEqual(null, it.next());
}
