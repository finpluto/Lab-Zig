const std = @import("std");
const sdl = @import("SDL2");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sdl_wrapper = b.dependency("SDL2", .{
        .target = target,
        .optimize = optimize,
    });

    var sdl_artifact: ?*std.Build.Step.Compile = null;

    // use static link to SDL under windows
    if (target.result.os.tag == .windows) {
        if (b.lazyDependency("SDL2_lib", .{
            .target = target,
            .optimize = optimize,
        })) |sdl_lib| {
            sdl_artifact = sdl_lib.artifact("SDL2");
            b.installArtifact(sdl_artifact.?);
        }
    }

    // HACK: use the dependency builder, then set dep_name to null to avoid creating new builder.
    // This sdk object is only used for linking.
    const sdk = sdl.init(sdl_wrapper.builder, .{
        .dep_name = null,
    });

    const color_mod = b.createModule(.{
        .root_source_file = b.path("src/interpolation.zig"),
        .target = target,
        .optimize = optimize,
    });

    color_mod.addImport("sdl2", sdl_wrapper.module("wrapper"));

    const color_exe = b.addExecutable(.{
        .name = "color",
        .root_module = color_mod,
    });

    // link sdl dependencies
    if (sdl_artifact) |artifact| {
        color_exe.linkLibrary(artifact);
    } else {
        sdk.link(color_exe, .dynamic, .SDL2);
    }
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

    star_mod.addImport("sdl2", sdl_wrapper.module("wrapper"));

    const star = b.addExecutable(.{
        .name = "star",
        .root_module = star_mod,
    });

    // link sdl dependencies
    if (sdl_artifact) |artifact| {
        star.linkLibrary(artifact);
    } else {
        sdk.link(star, .dynamic, .SDL2);
    }
    star.linkLibC();

    b.installArtifact(star);

    const star_cmd = b.addRunArtifact(star);
    star_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        star_cmd.addArgs(args);
    }

    const star_step = b.step("star", "Run the app");
    star_step.dependOn(&star_cmd.step);

    // testing
    const test_step = b.step("test", "Run Unit Testing");
    const test_exe = b.addTest(.{
        .name = "test",
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("test.zig"),
    });
    const test_runner = b.addRunArtifact(test_exe);
    test_step.dependOn(&test_runner.step);
}
