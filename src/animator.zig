const SDL = @import("sdl2");
const std = @import("std");
const cglm = @import("bindings/cglm.zig");
const Self = @This();
pub const AnimatorInitOpts = struct {
    allocator: std.mem.Allocator,
    screen_width: u32,
    screen_height: u32,
    renderer: SDL.Renderer,
};

const Point = struct {
    x: f32,
    y: f32,
    z: f32,
};
const star_num: u32 = 1000;

renderer: SDL.Renderer,
texture: SDL.Texture,
stars: []Point,
ticks: u32,
pixelBuffer: []u8,
allocator: std.mem.Allocator,
velocity: f32 = 1e-3,
focal: f32,
width: u32,
height: u32,

pub fn init(opts: *const AnimatorInitOpts) !Self {
    const texture = try SDL.createTexture(
        opts.renderer,
        .argb8888,
        .streaming,
        opts.screen_width,
        opts.screen_height,
    );

    const pixelBuf = try opts.allocator.alloc(
        u8,
        4 * opts.screen_height * opts.screen_width,
    );
    @memset(pixelBuf, 0);

    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();
    const stars = try opts.allocator.alloc(Point, star_num);
    for (stars) |*s| {
        s.x = rand.float(f32) * 2 - 1;
        s.y = rand.float(f32) * 2 - 1;
        s.z = rand.float(f32);
    }

    return Self{
        .stars = stars,
        .texture = texture,
        .renderer = opts.renderer,
        .ticks = SDL.getTicks(),
        .allocator = opts.allocator,
        .pixelBuffer = pixelBuf,
        .focal = @as(f32, @floatFromInt(opts.screen_height)) / 2,
        .height = opts.screen_height,
        .width = opts.screen_width,
    };
}

pub fn deinit(self: Self) void {
    self.renderer.destroy();
    self.allocator.free(self.pixelBuffer);
    self.allocator.free(self.stars);
}

fn update_star(self: *Self, delta_t: u32) void {
    const dt: f32 = @floatFromInt(delta_t);
    for (self.stars) |*star| {
        star.z = star.z - self.velocity * dt;
        if (star.z <= 0) {
            star.z += 1;
        }
        if (star.z > 1) {
            star.z -= 1;
        }
    }
}

pub fn update(self: *Self) !void {
    // update ticks and calculate delta_t
    const t = SDL.getTicks();
    const delta_t = t - self.ticks;
    self.ticks = t;

    self.update_star(delta_t);

    // reset the canvas to black again.
    @memset(self.pixelBuffer, 0);

    for (self.stars) |s| {
        const z = s.z;
        const faded_color_component = 0.2 / (z * z);
        const color_8bits: u8 = @intFromFloat(cglm.clamp(255 * faded_color_component, 0, 255));

        const width = @as(f32, @floatFromInt(self.width));
        const height = @as(f32, @floatFromInt(self.height));

        const u = self.focal * (s.x / s.z) + width / 2.0;
        const v = self.focal * (s.y / s.z) + height / 2.0;

        if (u < 0 or v < 0 or v >= height or u >= width) {
            continue;
        }

        const cursor = @as(u32, @intFromFloat(v)) * self.width * 4 + @as(u32, @intFromFloat(u)) * 4;
        //if (cursor >= self.pixelBuffer.len) {
        //    continue;
        //}
        for (0..4, [_]u8{ color_8bits, color_8bits, color_8bits, 255 }) |offset, c| {
            self.pixelBuffer[cursor + offset] = c;
        }
    }

    try self.texture.update(
        self.pixelBuffer,
        @sizeOf(u8) * 4 * self.width,
        null,
    );
}

pub fn draw(self: Self) !void {
    try self.renderer.clear();
    try self.renderer.copy(self.texture, null, null);
    self.renderer.present();
}
