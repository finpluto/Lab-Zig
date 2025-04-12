const std = @import("std");
const SDL = @import("sdl2"); // Add this package by using sdk.getNativeModule
const math = std.math;

const screen_height = 480;
const screen_width = 640;

const Vec3 = @Vector(3, f32);

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
    const left_side = try allocator.alloc(Vec3, height);
    defer allocator.free(left_side);
    const right_side = try allocator.alloc(Vec3, height);
    defer allocator.free(right_side);

    // LERP between top left & bottom left
    interpolate(Vec3{ 1, 0, 0 }, Vec3{ 0, 1, 0 }, left_side);
    // ... and top right & bottom right
    interpolate(Vec3{ 0, 0, 1 }, Vec3{ 1, 1, 0 }, right_side);

    const pixel_buf = try allocator.alloc(u8, width * height * 4);

    const col_color_buf = try allocator.alloc(Vec3, width);
    defer allocator.free(col_color_buf);

    for (0..height) |row_idx| {
        const left_color = left_side[row_idx];
        const right_color = right_side[row_idx];

        interpolate(left_color, right_color, col_color_buf);

        for (0..width) |col_idx| {
            const alpha: u8 = 255;
            const upper: Vec3 = @splat(255);
            const lower: Vec3 = @splat(0);
            const ret: @Vector(3, u8) = @intFromFloat(math.clamp(
                col_color_buf[col_idx] * @as(Vec3, @splat(255)),
                lower,
                upper,
            ));
            const r, const g, const b = ret;

            // TODO: should check big endian and little endian here, cuz we're using 4 u8 to represent a u32.
            // here is big endian
            for (0..4, [_]u8{ b, g, r, alpha }) |offset, v| {
                pixel_buf[row_idx * width * 4 + col_idx * 4 + offset] = v;
            }
        }
    }

    return pixel_buf;
}

fn interpolate(a: Vec3, b: Vec3, result: []Vec3) void {
    // how many vertices need to interpolate
    const l = result.len;
    for (0..l, result) |i, *vertex| {
        const left_tmp: Vec3 = a * @as(Vec3, @splat(@floatFromInt(l - i - 1)));
        const right_tmp: Vec3 = b * @as(Vec3, @splat(@floatFromInt(i)));

        const vec_sum = left_tmp + right_tmp;
        vertex.* = vec_sum / @as(Vec3, @splat(@floatFromInt(l - 1)));
    }
}

test "native @Vector lerp test" {
    const meta = @import("std").meta;
    const expect = @import("std").testing.expect;

    const a: Vec3 = .{ 1, 4, 9.2 };
    const b: Vec3 = .{ 4, 1, 9.8 };
    var result: [4]Vec3 = undefined;
    interpolate(a, b, &result);

    try expect(meta.eql(Vec3{ 1, 4, 9.2 }, result[0]));
    try expect(meta.eql(Vec3{ 2, 3, 9.4 }, result[1]));
    try expect(meta.eql(Vec3{ 3, 2, 9.6 }, result[2]));
    try expect(meta.eql(Vec3{ 4, 1, 9.8 }, result[3]));
}
