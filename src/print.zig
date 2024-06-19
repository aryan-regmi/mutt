const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const InterfaceImplError = @import("common.zig").InterfaceImplError;

pub fn isPrintable(comptime T: type) InterfaceImplError {
    comptime {
        const tinfo = @typeInfo(T);
        if ((tinfo == .Struct) or (tinfo == .Union)) {
            if (!@hasDecl(T, "writeToBuf")) {
                return .{ .valid = false, .reason = .MissingRequiredMethod };
            } else {
                const info = @typeInfo(@TypeOf(@field(T, "writeToBuf")));
                const num_args = info.Fn.params.len;
                const arg_type1 = info.Fn.params[0].type.?;
                const arg_type2 = info.Fn.params[1].type.?;
                const ret_type = info.Fn.return_type.?;
                if (num_args != 2) {
                    return .{ .valid = false, .reason = .InvalidNumArgs };
                } else if ((arg_type1 != *T) and (arg_type1 != *const T)) {
                    return .{ .valid = false, .reason = .InvalidArgType };
                } else if (arg_type2 != []u8) {
                    return .{ .valid = false, .reason = .InvalidArgType };
                } else if (ret_type != anyerror![]u8) {
                    return .{ .valid = false, .reason = .InvalidReturnType };
                }
            }
        } else {
            return .{ .valid = false, .reason = .MissingRequiredMethod };
        }
        return .{ .valid = true };
    }
}

pub fn Printable(comptime Self: type) type {
    comptime {
        const impl = isPrintable(Self);
        if (!impl.valid) {
            const tname = @typeName(Self);
            switch (impl.reason.?) {
                .MissingRequiredMethod => @compileError("`writeToBuf(*" ++ tname ++ ", []u8) anyerror![]u8` must be implemented by `" ++ tname ++ "`"),
                .InvalidNumArgs => @compileError("`writeToBuf` must have 2 parameters"),
                .InvalidArgType => @compileError("`writeToBuf` must have parameters of the following types: \n\t-- *" ++ tname ++ "\n\t-- []u8"),
                .InvalidReturnType => @compileError("`writeToBuf` must return `anyerror![u8]`"),
                else => unreachable,
            }
        }
    }

    return struct {
        pub fn debug(self: *Self, allocator: ?Allocator) void {
            const alloc = blk: {
                if (allocator) |a| {
                    break :blk a;
                } else {
                    break :blk std.heap.page_allocator;
                }
            };
            const cap = @typeName(Self).len + @sizeOf(Self);
            const buf = alloc.alloc(u8, cap) catch @panic("Unable to allocate buffer");
            defer alloc.free(buf);
            std.debug.print("{s}", .{self.writeToBuf(buf) catch @panic("`writeToBuf` failed")});
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
    val.debug(testing.allocator);
}
