const std = @import("std");
const SDL = @import("sdl2"); // Add this package by using sdk.getNativeModule
const cglm = @import("bindings/cglm.zig");

const screen_height = 480;
const screen_width = 640;

pub fn main() !void {
    try SDL.init(.{
        .video = true,
        .events = true,
        .audio = true,
    });
    defer SDL.quit();

    var window = try SDL.createWindow(
        "SDL2 Wrapper Demo",
        .{ .centered = {} },
        .{ .centered = {} },
        screen_width,
        screen_height,
        .{ .vis = .shown },
    );
    defer window.destroy();

    // TODO: extract the renderer
    var renderer = try SDL.createRenderer(window, null, .{ .accelerated = true });
    defer renderer.destroy();

    const allocator = std.heap.page_allocator;
    const pixel_buf = try screen_bilerp(screen_width, screen_height, allocator);
    defer allocator.free(pixel_buf);

    const texture = try SDL.createTexture(
        renderer,
        .argb8888,
        .streaming,
        screen_width,
        screen_height,
    );
    try texture.update(pixel_buf, @sizeOf(u8) * 4 * screen_width, null);

    mainLoop: while (true) {
        while (SDL.pollEvent()) |ev| {
            switch (ev) {
                .quit => break :mainLoop,
                else => {},
            }
        }

        try renderer.clear();
        try renderer.copy(texture, null, null);
        renderer.present();
    }
}

fn screen_bilerp(comptime width: u32, comptime height: u32, allocator: std.mem.Allocator) ![]u8 {
    const left_side = try allocator.alloc(cglm.Vec3, height);
    defer allocator.free(left_side);
    const right_side = try allocator.alloc(cglm.Vec3, height);
    defer allocator.free(right_side);

    // LERP between top left & bottom left
    interpolate(&.{ 1, 0, 0 }, &.{ 0, 1, 0 }, left_side);
    // ... and top right & bottom right
    interpolate(&.{ 0, 0, 1 }, &.{ 1, 1, 0 }, right_side);

    const pixel_buf = try allocator.alloc(u8, width * height * 4);

    const col_color_buf = try allocator.alloc(cglm.Vec3, width);
    defer allocator.free(col_color_buf);

    for (0..height) |row_idx| {
        const left_color = left_side[row_idx];
        const right_color = right_side[row_idx];

        interpolate(&left_color, &right_color, col_color_buf);

        for (0..width) |col_idx| {
            const rgb_vec = col_color_buf[col_idx];
            const alpha: u8 = 255;
            const r: u8 = @intFromFloat(cglm.clamp(255 * rgb_vec[0], 0, 255));
            const g: u8 = @intFromFloat(cglm.clamp(255 * rgb_vec[1], 0, 255));
            const b: u8 = @intFromFloat(cglm.clamp(255 * rgb_vec[2], 0, 255));

            // TODO: should check big endian and little endian here, cuz we're using 4 u8 to represent a u32.
            // here is big endian
            for (0..4, [_]u8{ b, g, r, alpha }) |offset, v| {
                pixel_buf[row_idx * width * 4 + col_idx * 4 + offset] = v;
            }
        }
    }

    return pixel_buf;
}

// LERP between two Vec3
fn interpolate(a: *const cglm.Vec3, b: *const cglm.Vec3, result: []cglm.Vec3) void {
    // how many vertices need to interpolate
    const l = result.len;
    for (0..l, result) |i, *vertex| {
        var left_tmp = [_]f32{ 0, 0, 0 };
        var right_tmp = [_]f32{ 0, 0, 0 };
        cglm.vec3Scale(a, @floatFromInt(l - i - 1), &left_tmp);
        cglm.vec3Scale(b, @floatFromInt(i), &right_tmp);

        var vec_sum = [_]f32{ 0, 0, 0 };
        cglm.vec3Add(&left_tmp, &right_tmp, &vec_sum);
        cglm.vec3DivScalar(&vec_sum, @floatFromInt(l - 1), vertex);
    }
}

// This test will fail, the `cglm` lib doesn't output f32 in tolerant machine float eps, WEIRD.
test "vec3 lerp" {
    const expectVec3Equal = struct {
        fn call(a: cglm.Vec3, b: cglm.Vec3) !void {
            for (0..3) |i| {
                try std.testing.expectApproxEqAbs(a[i], b[i], std.math.floatEps(f32));
            }
        }
    }.call;

    const a = &[_]f32{ 1, 4, 9.2 };
    const b = &[_]f32{ 4, 1, 9.8 };
    var result: [4]cglm.Vec3 = undefined;
    interpolate(a, b, &result);
    // this test case come from LAB1 instruction.
    try expectVec3Equal([3]f32{ 1, 4, 9.2 }, result[0]);
    try expectVec3Equal([3]f32{ 2, 3, 9.4 }, result[1]);
    try expectVec3Equal([3]f32{ 3, 2, 9.6 }, result[2]);
    try expectVec3Equal([3]f32{ 4, 1, 9.8 }, result[3]);
}
