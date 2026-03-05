const std = @import("std");
const builtin = @import("builtin");
// ============================================================
// EXERCISE 1: Target Detection — Know Your Platform
// ============================================================
// Before cross-compiling, you need to understand what the
// current target IS. Zig provides builtin info about the
// OS, CPU architecture, endianness, and more at comptime.
//
// Run: zig run 01_targets.zig
//
// YOUR BLOCKCHAIN USE CASE:
//   Your node needs to know its platform for:
//   - Choosing the right network interface
//   - Selecting file system paths (Linux vs Windows vs macOS)
//   - Enabling platform-specific optimizations (AES-NI, NEON)
//   - Adjusting default configs (data dir, port ranges)
// ============================================================
pub fn main() !void {
    std.debug.print("\n=== Lesson 10.1: Target Detection ===\n\n", .{});
    // ---------------------------------------------------------
    // STEP 1: Current target info (from @import("builtin"))
    // ---------------------------------------------------------
    std.debug.print("  --- Current Build Target ---\n\n", .{});
    std.debug.print("    CPU Architecture: {s}\n", .{@tagName(builtin.cpu.arch)});
    std.debug.print("    OS:              {s}\n", .{@tagName(builtin.os.tag)});
    std.debug.print("    ABI:             {s}\n", .{@tagName(builtin.abi)});
    std.debug.print("    Endianness:      {s}\n", .{@tagName(builtin.cpu.arch.endian())});
    std.debug.print("    Pointer size:    {d} bits\n", .{@bitSizeOf(usize)});
    std.debug.print("    Build mode:      {s}\n", .{@tagName(builtin.mode)});
    // ---------------------------------------------------------
    // STEP 2: CPU feature detection
    // ---------------------------------------------------------
    std.debug.print("\n  --- CPU Features ---\n\n", .{});
    const cpu = builtin.cpu;
    std.debug.print("    CPU model: {s}\n", .{cpu.model.name});
    // Check for specific features at comptime
    if (builtin.cpu.arch == .x86_64) {
        const has_aes = std.Target.x86.featureSetHas(cpu.features, .aes);
        const has_avx2 = std.Target.x86.featureSetHas(cpu.features, .avx2);
        const has_sse42 = std.Target.x86.featureSetHas(cpu.features, .sse4_2);
        std.debug.print("    AES-NI:    {s} {s}\n", .{
            if (has_aes) "✅" else "❌",
            if (has_aes) "(hardware crypto acceleration!)" else "(software fallback)",
        });
        std.debug.print("    AVX2:      {s}\n", .{if (has_avx2) "✅" else "❌"});
        std.debug.print("    SSE4.2:    {s} (CRC32 hardware)\n", .{if (has_sse42) "✅" else "❌"});
    } else if (builtin.cpu.arch == .aarch64) {
        const has_aes = std.Target.aarch64.featureSetHas(cpu.features, .aes);
        const has_sha2 = std.Target.aarch64.featureSetHas(cpu.features, .sha2);
        std.debug.print("    AES:       {s}\n", .{if (has_aes) "✅" else "❌"});
        std.debug.print("    SHA2:      {s} (hardware SHA-256!)\n", .{if (has_sha2) "✅" else "❌"});
    }
    // ---------------------------------------------------------
    // STEP 3: Platform-specific paths
    // ---------------------------------------------------------
    std.debug.print("\n  --- Platform-Specific Defaults ---\n\n", .{});
    const data_dir = switch (builtin.os.tag) {
        .macos => "~/Library/Application Support/Sacrium",
        .linux => "~/.sacrium",
        .windows => "%APPDATA%\\Sacrium",
        else => "./sacrium_data",
    };
    const default_port: u16 = switch (builtin.os.tag) {
        .macos, .linux => 9333,
        .windows => 9334,
        else => 9333,
    };
    const max_connections: u32 = switch (builtin.cpu.arch) {
        .x86_64 => 125,
        .aarch64 => 50, // ARM servers may have less resources
        .wasm32 => 8, // Browser light client
        else => 25,
    };
    std.debug.print("    Data directory:    {s}\n", .{data_dir});
    std.debug.print("    Default port:      {d}\n", .{default_port});
    std.debug.print("    Max connections:   {d}\n", .{max_connections});
    // ---------------------------------------------------------
    // STEP 4: Size information (important for cross-compile)
    // ---------------------------------------------------------
    std.debug.print("\n  --- Type Sizes (platform-dependent!) ---\n\n", .{});
    std.debug.print("    ┌──────────────┬──────────┐\n", .{});
    std.debug.print("    │ Type         │ Size     │\n", .{});
    std.debug.print("    ├──────────────┼──────────┤\n", .{});
    std.debug.print("    │ usize        │ {d:>4} bit │\n", .{@bitSizeOf(usize)});
    std.debug.print("    │ *anyopaque   │ {d:>4} bit │\n", .{@bitSizeOf(*anyopaque)});
    std.debug.print("    │ c_int        │ {d:>4} bit │\n", .{@bitSizeOf(c_int)});
    std.debug.print("    │ c_long       │ {d:>4} bit │\n", .{@bitSizeOf(c_long)});
    std.debug.print("    └──────────────┴──────────┘\n", .{});
    std.debug.print("\n    ⚠️  Use u64/u32 (fixed size) in wire protocols,\n", .{});
    std.debug.print("       NOT usize (changes per platform)!\n", .{});
    // ---------------------------------------------------------
    // STEP 5: Available targets you can cross-compile to
    // ---------------------------------------------------------
    std.debug.print("\n  --- Key Cross-Compilation Targets ---\n\n", .{});
    std.debug.print("    zig build -Dtarget=TARGET\n\n", .{});
    std.debug.print("    ┌─────────────────────────┬────────────────────────┐\n", .{});
    std.debug.print("    │ Target                  │ Use Case               │\n", .{});
    std.debug.print("    ├─────────────────────────┼────────────────────────┤\n", .{});
    std.debug.print("    │ x86_64-linux-gnu        │ Cloud servers (AWS)    │\n", .{});
    std.debug.print("    │ x86_64-linux-musl       │ Static binary (Alpine) │\n", .{});
    std.debug.print("    │ aarch64-linux-gnu       │ Raspberry Pi, Graviton │\n", .{});
    std.debug.print("    │ aarch64-linux-musl      │ Static ARM binary      │\n", .{});
    std.debug.print("    │ x86_64-macos            │ macOS Intel            │\n", .{});
    std.debug.print("    │ aarch64-macos           │ macOS Apple Silicon    │\n", .{});
    std.debug.print("    │ x86_64-windows-gnu      │ Windows desktop        │\n", .{});
    std.debug.print("    │ wasm32-freestanding      │ Browser light client   │\n", .{});
    std.debug.print("    └─────────────────────────┴────────────────────────┘\n", .{});
    std.debug.print("\n✅ Target detection mastered!\n\n", .{});
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. @import("builtin") gives comptime platform info
// 2. builtin.cpu.arch, builtin.os.tag = current target
// 3. Platform-specific code via switch on OS/arch
// 4. CPU feature detection for hardware crypto acceleration
// 5. ALWAYS use fixed-size types (u64) in wire protocols
// 6. `zig targets` lists ALL available cross-compile targets
//
// 🔬 EXPERIMENT:
//   - Cross-compile this file: zig build-exe -target x86_64-linux 01_targets.zig
//   - Check what changes in the output (it will show Linux info!)
//   - Try wasm32-freestanding — see what usize becomes (32-bit!)
// ============================================================