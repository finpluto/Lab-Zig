pub const mainTests = @import("src/main.zig");

// root source file that exposes all test case, consumed by build.zig.
test {
    @import("std").testing.refAllDecls(@This());
}
