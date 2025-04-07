const std = @import("std");
const SDL = @import("sdl2");
const Animator = @import("./animator.zig");

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

    const renderer = try SDL.createRenderer(window, null, .{ .accelerated = true });
    const allocator = std.heap.page_allocator;

    var animator = try Animator.init(&.{
        .allocator = allocator,
        .renderer = renderer,
        .screen_height = screen_height,
        .screen_width = screen_width,
    });
    defer animator.deinit();

    mainLoop: while (true) {
        while (SDL.pollEvent()) |ev| {
            switch (ev) {
                .quit => break :mainLoop,
                else => {},
            }
        }

        try animator.update();
        try animator.draw();
    }
}
