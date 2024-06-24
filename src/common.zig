/// Represents the validity of an interface.
pub const InterfaceImplError = struct {
    pub const Reason = enum {
        /// Required method(s) for interface not provided.
        MissingRequiredMethod,

        /// Required associated type not provided.
        MissingRequiredType,

        /// Required field not provided.
        MissingRequiredField,

        /// Required method(s) has incorrect number of arguments.
        InvalidNumArgs,

        /// Required method(s) has incorrect argument type.
        InvalidArgType,

        /// Required method(s) has incorrect return type.
        InvalidReturnType,
    };

    valid: bool,
    reason: ?Reason = null,
};
