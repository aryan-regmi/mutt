const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const InterfaceChecker = @import("common.zig").InterfaceChecker;

/// Checks if a the type implments the `Printable` interface.
fn checkPrintableImpl(comptime T: type, print_errors: bool) *InterfaceChecker(T) {
    comptime {
        var checker = InterfaceChecker(T){ .print_error = print_errors };
        return checker.isEnumStructUnion().hasFunc(.{
            .name = "writeToBuf",
            .num_args = 2,
            .arg_types = &[_]type{ *T, []u8 },
            .ret_type = &[_]type{anyerror![]u8},
        });
    }
}

/// Returns `true` if `T` implments the `Printable` interface.
pub fn isPrintable(comptime T: type) bool {
    comptime {
        const checker = checkPrintableImpl(T, false);
        return checker.valid;
    }
}

/// An interface for printable types.
///
/// # Note
/// Implementations must provide a `writeToBuf` function.
pub fn Printable(comptime Self: type) type {
    comptime _ = checkPrintableImpl(Self, true);
    return struct {
        pub fn debug(self: *Self) void {
            const cap = @typeName(Self).len + @sizeOf(Self);
            var buf: [cap]u8 = undefined;
            std.debug.print("{s}", .{self.writeToBuf(&buf) catch @panic("`writeToBuf` failed")});
        }
    };
}

test "Create printable type" {
    const TstPrint = struct {
        const Self = @This();
        data: usize,

        pub usingnamespace Printable(Self);
        pub fn writeToBuf(self: *Self, buf: []u8) anyerror![]u8 {
            var stream = std.io.fixedBufferStream(buf);
            var writer = stream.writer();
            try writer.print("TstPrint {{ {} }}\n", .{self.data});
            return stream.getWritten();
        }
    };

    var val = TstPrint{ .data = 42 };
    val.debug();
}
