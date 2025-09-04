const std = @import("std");

pub const Dimensions = struct {
    width: u32,
    height: u32,
};

/// The various resolutions supported when building as the 'default' resolution.
pub const Resolution = enum {
    x800x600,
    x1024x768,
    x1280x720,
    x1280x1024,
    x1440x900,
    x1600x900,
    x1920x1080,
    x2560x1440,

    pub fn getDimensions(self: Resolution) Dimensions {
        return switch (self) {
            .x800x600 => Dimensions{ .width = 800, .height = 600 },
            .x1024x768 => Dimensions{ .width = 1024, .height = 768 },
            .x1280x720 => Dimensions{ .width = 1280, .height = 720 },
            .x1280x1024 => Dimensions{ .width = 1280, .height = 1024 },
            .x1440x900 => Dimensions{ .width = 1440, .height = 900 },
            .x1600x900 => Dimensions{ .width = 1600, .height = 900 },
            .x1920x1080 => Dimensions{ .width = 1920, .height = 1080 },
            .x2560x1440 => Dimensions{ .width = 2560, .height = 1440 },
        };
    }
};

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .x86_64, .os_tag = .uefi });
    const native_target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    var mode = b.option(Resolution, "resolution", "The screen resolution to use as default");
    if (mode == null) {
        std.debug.print("Warning: No resolution specified, defaulting to 800x600.\n", .{});
        mode = .x800x600;
    } else {
        mode = mode.?;
    }

    const lib = b.createModule(.{
        .root_source_file = b.path("boot/lib.zig"),
    });

    const options = b.addOptions();
    options.addOption(Dimensions, "default_resolution", mode.?.getDimensions());

    lib.addOptions("config", options);

    const exe = b.addExecutable(.{
        .name = "rouge",
        .root_module = b.createModule(.{
            .root_source_file = b.path("boot/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .use_llvm = true,
    });

    exe.root_module.addOptions("config", options);

    exe.root_module.strip = false;
    if (optimize == .Debug) {
        exe.root_module.omit_frame_pointer = false;
    }

    exe.root_module.addImport("rouge", lib);

    exe.subsystem = .EfiApplication;
    exe.is_linking_libc = false;

    const tests = b.addTest(.{
        .name = "tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/test.zig"),
            .target = native_target,
            .optimize = optimize,
        }),
        .use_llvm = true,
    });

    tests.root_module.addImport("rouge", lib);

    b.installArtifact(exe);

    const lint_step = b.step("lint", "Run static analysis");
    lint_step.dependOn(&exe.step);

    const test_lint_step = b.step("test-lint", "Run static analysis on tests");
    test_lint_step.dependOn(&tests.step);

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}
