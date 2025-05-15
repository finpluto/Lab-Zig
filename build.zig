const std = @import("std");
const sdl = @import("SDL2");

var sdl_artifact: ?*std.Build.Step.Compile = null;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sdl_wrapper = b.dependency("SDL2", .{
        .target = target,
        .optimize = optimize,
    });

    // use static link to SDL under windows
    if (target.result.os.tag != .linux) {
        if (b.lazyDependency("SDL2_lib", .{
            .target = target,
            .optimize = optimize,
        })) |sdl_lib| {
            sdl_artifact = sdl_lib.artifact("SDL2");
        }
    }

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
    linkSDL2(color_exe);

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

    const star_exe = b.addExecutable(.{
        .name = "star",
        .root_module = star_mod,
    });
    linkSDL2(star_exe);
    b.installArtifact(star_exe);

    const star_cmd = b.addRunArtifact(star_exe);
    star_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        star_cmd.addArgs(args);
    }

    const star_step = b.step("star", "Run the app");
    star_step.dependOn(&star_cmd.step);

    // raytracer
    const as_dep = b.dependency("aegleseeker", .{
        // pass target to aegleseeker builder
        .target = target,
        .optimize = optimize,
    });
    const rt_module = b.createModule(.{
        .root_source_file = b.path("src/raytracer.zig"),
        .optimize = optimize,
        .target = target,
    });
    rt_module.addImport("sdl2", sdl_wrapper.module("wrapper"));
    rt_module.addImport("aegleseeker", as_dep.module("aegleseeker"));
    switch (target.result.os.tag) {
        .linux => {
            const as_install = b.addInstallLibFile(
                as_dep.module("libaegleseeker.so").root_source_file.?,
                "libaegleseeker.so",
            );
            b.getInstallStep().dependOn(&as_install.step);
        },
        .windows => {
            b.getInstallStep().dependOn(&b.addInstallBinFile(
                as_dep.module("libaegleseeker.dll").root_source_file.?,
                "libaegleseeker.dll",
            ).step);
            b.getInstallStep().dependOn(&b.addInstallBinFile(
                as_dep.module("libaegleseeker.lib").root_source_file.?,
                "libaegleseeker.lib",
            ).step);
        },
        else => {},
    }

    const rt_exe = b.addExecutable(.{
        .name = "raytracer",
        .root_module = rt_module,
    });
    rt_exe.addLibraryPath(as_dep.module("libaegleseeker.so").root_source_file.?.dirname());
    rt_exe.linkSystemLibrary2("aegleseeker", .{
        .needed = true,
    });
    linkSDL2(rt_exe);
    b.installArtifact(rt_exe);
    const rt_run = b.addRunArtifact(rt_exe);
    const rt_step = b.step("raytracer", "Run raytracer");
    rt_step.dependOn(&rt_run.step);

    // rasterizer
    //const rz_dep = b.dependency("rusterizer", .{
    //    // pass target to aegleseeker builder
    //    .target = target,
    //    .optimize = optimize,
    //});
    const rz_module = b.createModule(.{
        .root_source_file = b.path("src/rasterizer.zig"),
        .optimize = optimize,
        .target = target,
    });
    const rz_dep_mod = b.createModule(.{
        .root_source_file = b.path("../../../../KTH/DH2323/rusterizer/binding/rusterizer.zig"),
        .optimize = optimize,
        .target = target,
    });
    rz_module.addImport("sdl2", sdl_wrapper.module("wrapper"));
    //rz_module.addImport("rusterizer", rz_dep.module("rusterizer"));
    rz_module.addImport("rusterizer", rz_dep_mod);
    //switch (target.result.os.tag) {
    //    .linux => {
    //        const rz_install = b.addInstallLibFile(
    //            rz_dep.module("librusterizer.so").root_source_file.?,
    //            "librusterizer.so",
    //        );
    //        b.getInstallStep().dependOn(&rz_install.step);
    //    },
    //    else => {},
    //}

    const rz_exe = b.addExecutable(.{
        .name = "rasterizer",
        .root_module = rz_module,
    });
    //rz_exe.addLibraryPath(rz_dep.module("librusterizer.so").root_source_file.?.dirname());
    rz_exe.addLibraryPath(b.path("../../../../KTH/DH2323/rusterizer/target/debug/"));
    rz_exe.linkSystemLibrary2("rusterizer", .{
        .needed = true,
    });
    linkSDL2(rz_exe);
    b.installArtifact(rz_exe);
    const rz_run = b.addRunArtifact(rz_exe);
    const rz_step = b.step("rasterizer", "Run rasterizer");
    rz_step.dependOn(&rz_run.step);

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

fn linkSDL2(exe: *std.Build.Step.Compile) void {
    if (sdl_artifact) |sdl_lib| {
        exe.linkLibrary(sdl_lib);
    } else {
        // dynamic link to system SDL2
        exe.linkSystemLibrary("SDL2");
    }
    exe.linkLibC();
}
