const std = @import("std");
const SDL = @import("sdl2"); // Add this package by using sdk.getNativeModule
const math = std.math;
const rusterizer = @import("rusterizer");

const screen_height = 300;
const screen_width = 300;

const Vec3 = @Vector(3, f32);

pub fn main() !void {
    try SDL.init(.{
        .video = true,
        .events = true,
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
    const pixel_buf = try allocator.alloc(u8, 4 * screen_height * screen_width);
    defer allocator.free(pixel_buf);
    @memset(pixel_buf, 0);

    _ = rusterizer.rusterizer_init_scene(screen_height, screen_width);
    _ = rusterizer.rusterizer_draw_to_pixel_buf(pixel_buf.ptr);

    const texture = try SDL.createTexture(
        renderer,
        .argb8888,
        .streaming,
        screen_width,
        screen_height,
    );
    try texture.update(pixel_buf, @sizeOf(u8) * 4 * screen_width, null);

    const delta = 1e-2;

    var yaw: f32 = 0.0;
    var z_translate: f32 = 0.0;
    var light_x: f32 = 0.0;
    var light_y: f32 = 0.0;
    var light_z: f32 = 0.0;
    mainLoop: while (true) {
        while (SDL.pollEvent()) |ev| {
            switch (ev) {
                .quit => break :mainLoop,
                .key_down => switch (ev.key_down.scancode) {
                    .up => {
                        z_translate += delta;
                    },
                    .down => {
                        z_translate -= delta;
                    },
                    .left => {
                        yaw -= delta;
                    },
                    .right => {
                        yaw += delta;
                    },
                    .w => {
                        light_z += delta;
                    },
                    .a => {
                        light_x -= delta;
                    },
                    .s => {
                        light_z -= delta;
                    },
                    .d => {
                        light_x += delta;
                    },
                    .q => {
                        light_y -= delta;
                    },
                    .e => {
                        light_y += delta;
                    },
                    else => {},
                },
                else => {},
            }
        }

        _ = rusterizer.rusterizer_camera_yaw(yaw);
        _ = rusterizer.rusterizer_draw_to_pixel_buf(pixel_buf.ptr);
        rusterizer.rusterizer_light_position_offset(light_x, light_y, light_z);
        try texture.update(pixel_buf, @sizeOf(u8) * 4 * screen_width, null);
        try renderer.clear();
        try renderer.copy(texture, null, null);
        renderer.present();
    }
}
