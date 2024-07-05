const std = @import("std");
const testing = std.testing;

pub const FuncInfo = struct {
    name: []const u8,
    num_args: usize,
    arg_types: []const type,
    ret_type: ?[]const type = null,
};

/// Used to validate interfaces.
pub fn InterfaceChecker(comptime T: type) type {
    return struct {
        const Self = @This();

        print_error: bool = true,
        valid: bool = true,

        /// Checks that `T` is an enum, struct, or union.
        pub fn isEnumStructUnion(comptime self: *Self) *Self {
            comptime {
                const INFO = @typeInfo(T);
                if ((INFO != .Struct) and (INFO != .Union) and (INFO != .Enum)) {
                    self.valid = false;
                    if (self.print_error) {
                        @compileError("Invalid implementation type: must be Enum, Struct, or Union");
                    }
                } else {
                    self.valid = true;
                }
                return self;
            }
        }

        /// Checks that `T` has the function defined by `info`.
        pub fn hasFunc(comptime self: *Self, comptime info: FuncInfo) *Self {
            comptime {
                const INFO = @typeInfo(T);
                switch (INFO) {
                    .Struct, .Enum, .Union => {
                        if (!@hasDecl(T, info.name)) {
                            self.valid = false;
                            if (self.print_error) {
                                const err = std.fmt.comptimePrint("Required method missing: {s} must implement the `{s}({any}) {any}`", .{ @typeName(T), info.name, info.arg_types, info.ret_type });
                                @compileError(err);
                            }
                            return self;
                        }
                    },
                    else => {
                        self.valid = false;
                        if (self.print_error) {
                            @compileError("Invalid type: " ++ @typeName(T) ++ " does not implement the `" ++ info.name ++ "` method");
                        }
                        return self;
                    },
                }

                const fn_info = @typeInfo(@TypeOf(@field(T, info.name)));

                // Check number of args
                if (fn_info.Fn.params.len != info.num_args) {
                    self.valid = false;
                    if (self.print_error) {
                        const err = std.fmt.comptimePrint("Incorrect number of arguments: the `{s}` function must have {} arguments", .{ info.name, info.num_args });
                        @compileError(err);
                    }
                    return self;
                }

                // Check arg types
                for (0..info.num_args) |i| {
                    if (fn_info.Fn.params[i].type) |t| {
                        if (t != info.arg_types[i]) {
                            self.valid = false;
                            if (self.print_error) {
                                @compileError("Invalid argument type: expected `" ++ @typeName(t) ++ "`, was `" ++ @typeName(info.arg_types[i]) ++ "`");
                            }
                            return self;
                        }
                    }
                }

                // Check return type
                var ret_type_ok = false;
                if (info.ret_type) |ret_types| {
                    if (fn_info.Fn.return_type) |t| {
                        for (0..ret_types.len) |i| {
                            if (t == ret_types[i]) {
                                ret_type_ok = true;
                                break;
                            }
                        }
                        if (!ret_type_ok) {
                            self.valid = false;
                            if (self.print_error) {
                                @compileError("Invalid return type: expected `" ++ @typeName(info.ret_type.?[0]) ++ "` was `" ++ @typeName(t));
                            }
                            return self;
                        }
                    }
                }

                self.valid = true;
                return self;
            }
        }

        /// Checks that `T` has an associated type with the given name (`pub const NAME`).
        pub fn hasAssociatedType(comptime self: *Self, comptime name: []const u8) *Self {
            comptime {
                if (!@hasDecl(T, name)) {
                    self.valid = false;
                    if (self.print_error) {
                        @compileError("Missing required associated type: `pub const " ++ name ++ "`");
                    }
                    return self;
                }
                self.valid = true;
                return self;
            }
        }

        /// Checks that `T` has the field with the given name and type (`NAME: FIELD_TYPE`).
        pub fn hasField(comptime self: *Self, comptime name: []const u8, comptime field_type: type) *Self {
            comptime {
                const INFO = @typeInfo(T);
                if (!@hasField(T, name)) {
                    self.valid = false;
                    if (self.print_error) {
                        @compileError("Missing required field: `" ++ name ++ ": " ++ @typeName(field_type) ++ "`");
                    }
                    return self;
                } else {
                    // TODO: Make this work for Enum and Unions!
                    var correct_type = false;
                    for (0..INFO.Struct.fields.len) |i| {
                        if (std.mem.eql(u8, INFO.Struct.fields[i].name, name)) {
                            if (INFO.Struct.fields[i].type == field_type) {
                                correct_type = true;
                            }
                            if (!correct_type) {
                                self.valid = false;
                                if (self.print_error) {
                                    @compileError("Incorrect field type: `" ++ name ++ "` field must be type `" ++ @typeName(field_type) ++ "`");
                                }
                                return self;
                            }
                        }
                    }
                }
                self.valid = true;
                return self;
            }
        }

        /// Allows the user to perform custom checks/validations.
        pub fn customCheck(
            comptime self: *Self,
            comptime check: *const fn (*Self) *Self,
        ) *Self {
            comptime {
                return check(self);
            }
        }
    };
}

test "Checker" {
    const Tst = struct {
        const Self = @This();
        pub const Inner = u8;

        info: []const u8,

        pub fn tst(self: *Self) void {
            _ = self;
        }
    };

    comptime {
        var checker = InterfaceChecker(Tst){ .print_error = true };

        // Valid
        {
            _ = checker
                .hasAssociatedType("Inner")
                .hasField("info", []const u8)
                .hasFunc(
                .{
                    .name = "tst",
                    .num_args = 1,
                    .arg_types = &[_]type{*Tst},
                    .ret_type = &[_]type{ void, anyerror!void },
                },
            )
                .customCheck(
                struct {
                    pub fn check(self: *InterfaceChecker(Tst)) *InterfaceChecker(Tst) {
                        const info = @typeInfo(@TypeOf(@field(Tst, "tst")));
                        const rt = info.Fn.return_type.?;
                        if ((rt != anyerror!void) and (rt != void)) {
                            if (self.print_error) {
                                @compileError("Oh No!");
                            }
                        }
                        return self;
                    }
                }.check,
            );
        }
    }
}
