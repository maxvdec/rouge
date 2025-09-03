const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{ .abi = .msvc, .cpu_arch = .x86_64, .os_tag = .uefi });
    const native_target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "rouge",
        .root_module = b.createModule(.{
            .root_source_file = b.path("boot/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .use_llvm = true,
    });

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

    b.installArtifact(exe);

    const lint_step = b.step("lint", "Run static analysis");
    lint_step.dependOn(&exe.step);

    const test_lint_step = b.step("test-lint", "Run static analysis on tests");
    test_lint_step.dependOn(&tests.step);

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}
