const std = @import("std");
const sdl = @import("SDL2");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sdl_pkg = b.dependency("SDL2", .{
        .target = target,
        .optimize = optimize,
    });

    const cglm_pkg = b.dependency("cglm", .{
        .target = target,
        .optimize = optimize,
    });

    // HACK: use the dependency builder, then set dep_name to null to avoid creating new builder.
    // This sdk object is only used for linking.
    const sdk = sdl.init(sdl_pkg.builder, .{
        .dep_name = null,
    });

    const color_mod = b.createModule(.{
        .root_source_file = b.path("src/interpolation.zig"),
        .target = target,
        .optimize = optimize,
    });

    color_mod.addImport("sdl2", sdl_pkg.module("wrapper"));
    color_mod.addImport("cglm-binding", cglm_pkg.module("cglm-binding"));

    const color_exe = b.addExecutable(.{
        .name = "lab_zig",
        .root_module = color_mod,
    });

    // link sdl dependencies
    sdk.link(color_exe, .dynamic, .SDL2);
    color_exe.linkLibC();

    b.installArtifact(color_exe);

    const color_cmd = b.addRunArtifact(color_exe);
    color_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        color_cmd.addArgs(args);
    }

    const color_step = b.step("color", "Run the app");
    color_step.dependOn(&color_cmd.step);

    // starfield
    const star_mod = b.createModule(.{
        .root_source_file = b.path("src/starfield.zig"),
        .target = target,
        .optimize = optimize,
    });

    star_mod.addImport("sdl2", sdl_pkg.module("wrapper"));
    star_mod.addImport("cglm-binding", cglm_pkg.module("cglm-binding"));

    const star = b.addExecutable(.{
        .name = "lab_zig",
        .root_module = star_mod,
    });

    // link sdl dependencies
    sdk.link(star, .dynamic, .SDL2);
    star.linkLibC();

    b.installArtifact(star);

    const star_cmd = b.addRunArtifact(star);
    star_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        star_cmd.addArgs(args);
    }

    const star_step = b.step("starfield", "Run the app");
    star_step.dependOn(&star_cmd.step);

    // testing
    const test_step = b.step("test", "Run Unit Testing");
    const test_exe = b.addTest(.{
        .name = "test",
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("test.zig"),
    });
    test_exe.root_module.addImport("cglm-binding", cglm_pkg.module("cglm-binding"));
    const test_runner = b.addRunArtifact(test_exe);
    test_step.dependOn(&test_runner.step);
}
