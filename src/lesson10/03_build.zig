const std = @import("std");
// ============================================================
// EXERCISE 3: Build System — build.zig
// ============================================================
// `zig build` uses build.zig as the build script. This is
// Zig's equivalent of Makefile, CMake, or Cargo.toml.
//
// Commands:
//   zig build                              # build for current platform
//   zig build run                          # build and run
//   zig build -Dtarget=x86_64-linux        # cross-compile to Linux
//   zig build -Dtarget=aarch64-linux       # cross-compile to ARM
//   zig build -Dtarget=x86_64-windows      # cross-compile to Windows
//   zig build -Doptimize=ReleaseFast       # optimized build
//   zig build test                         # run tests
// ============================================================
pub fn build(b: *std.Build) void {
    // ---------------------------------------------------------
    // STEP 1: Standard options (target + optimization)
    // ---------------------------------------------------------
    // These create -Dtarget and -Doptimize command-line options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    // ---------------------------------------------------------
    // STEP 2: Main executable — the blockchain node
    // ---------------------------------------------------------
    const exe = b.addExecutable(.{
        .name = "sacrium-node",
        .root_source_file = b.path("04_sacrium_node.zig"),
        .target = target,
        .optimize = optimize,
    });
    // Link libc (needed for C interop exercises)
    exe.linkLibC();
    // Install the executable to zig-out/bin/
    b.installArtifact(exe);
    // ---------------------------------------------------------
    // STEP 3: Run step — `zig build run`
    // ---------------------------------------------------------
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    // Forward command-line args to the executable
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the sacrium node");
    run_step.dependOn(&run_cmd.step);
    // ---------------------------------------------------------
    // STEP 4: Test step — `zig build test`
    // ---------------------------------------------------------
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("04_sacrium_node.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run sacrium node tests");
    test_step.dependOn(&run_tests.step);
    // ---------------------------------------------------------
    // STEP 5: Additional build targets
    // ---------------------------------------------------------
    // Build the targets exercise too
    const targets_exe = b.addExecutable(.{
        .name = "sacrium-targets",
        .root_source_file = b.path("01_targets.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(targets_exe);
    // Build the conditional compilation exercise
    const conditional_exe = b.addExecutable(.{
        .name = "sacrium-conditional",
        .root_source_file = b.path("02_conditional.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(conditional_exe);
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. build.zig replaces Makefile/CMake — it's just Zig code!
// 2. standardTargetOptions() enables -Dtarget=... flag
// 3. standardOptimizeOption() enables -Doptimize=... flag
// 4. b.addExecutable() defines a build target
// 5. b.installArtifact(exe) puts binary in zig-out/bin/
// 6. Cross-compile by just adding -Dtarget=...
//
// 🔬 EXPERIMENT:
//   - zig build -Dtarget=x86_64-linux && file zig-out/bin/sacrium-node
//   - zig build -Dtarget=aarch64-linux && file zig-out/bin/sacrium-node
//   - zig build -Doptimize=ReleaseSmall && ls -la zig-out/bin/
//   - Compare binary sizes: Debug vs ReleaseFast vs ReleaseSmall
// ============================================================
