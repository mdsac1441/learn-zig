const std = @import("std");
const builtin = @import("builtin");
// ============================================================
// EXERCISE 2: Conditional Compilation — Platform-Specific Code
// ============================================================
// Real blockchain nodes need different code per platform:
//   - Linux: epoll for networking, /var/lib for data
//   - macOS: kqueue for networking, ~/Library for data
//   - Windows: IOCP for networking, AppData for data
//
// Zig handles this with comptime `if` and `switch` — no
// preprocessor macros like C's #ifdef!
//
// Run: zig run 02_conditional.zig
// ============================================================
// ---------------------------------------------------------
// STEP 1: Comptime OS detection
// ---------------------------------------------------------
const PlatformConfig = struct {
    data_dir: []const u8,
    config_file: []const u8,
    log_file: []const u8,
    pid_file: []const u8,
    path_separator: u8,
    max_open_files: u32,
    use_color: bool,
};
/// Get platform-specific configuration at COMPILE TIME
fn getPlatformConfig() PlatformConfig {
    return switch (builtin.os.tag) {
        .macos => .{
            .data_dir = "Library/Application Support/Sacrium",
            .config_file = "Library/Application Support/Sacrium/config.toml",
            .log_file = "Library/Logs/sacrium.log",
            .pid_file = "/tmp/sacrium.pid",
            .path_separator = '/',
            .max_open_files = 256,
            .use_color = true,
        },
        .linux => .{
            .data_dir = ".sacrium",
            .config_file = ".sacrium/config.toml",
            .log_file = ".sacrium/sacrium.log",
            .pid_file = "/var/run/sacrium.pid",
            .path_separator = '/',
            .max_open_files = 1024,
            .use_color = true,
        },
        .windows => .{
            .data_dir = "AppData\\Roaming\\Sacrium",
            .config_file = "AppData\\Roaming\\Sacrium\\config.toml",
            .log_file = "AppData\\Roaming\\Sacrium\\sacrium.log",
            .pid_file = "AppData\\Local\\Temp\\sacrium.pid",
            .path_separator = '\\',
            .max_open_files = 512,
            .use_color = false, // Windows terminal color is tricky
        },
        else => .{
            .data_dir = "sacrium_data",
            .config_file = "sacrium_data/config.toml",
            .log_file = "sacrium_data/sacrium.log",
            .pid_file = "/tmp/sacrium.pid",
            .path_separator = '/',
            .max_open_files = 128,
            .use_color = false,
        },
    };
}
const config = getPlatformConfig(); // Resolved at COMPILE TIME!
// ---------------------------------------------------------
// STEP 2: Architecture-specific optimizations
// ---------------------------------------------------------
/// Choose hash function based on hardware crypto support
fn selectHashEngine() []const u8 {
    if (builtin.cpu.arch == .x86_64) {
        if (std.Target.x86.featureSetHas(builtin.cpu.features, .aes)) {
            return "AES-NI accelerated SHA-256";
        }
    }
    if (builtin.cpu.arch == .aarch64) {
        if (std.Target.aarch64.featureSetHas(builtin.cpu.features, .sha2)) {
            return "ARM SHA-256 hardware extension";
        }
    }
    return "Software SHA-256 (portable)";
}
/// Choose memory alignment based on architecture
fn optimalAlignment() u29 {
    return switch (builtin.cpu.arch) {
        .x86_64 => 64, // Cache line size on x86
        .aarch64 => 64, // Cache line size on ARM
        .wasm32 => 16, // WASM alignment
        else => 32, // Conservative default
    };
}
// ---------------------------------------------------------
// STEP 3: Conditional compilation with if (comptime)
// ---------------------------------------------------------
/// Platform-specific timestamp
fn getTimestamp() i64 {
    return std.time.timestamp();
}
/// Platform-specific temp directory
fn getTempDir() []const u8 {
    if (builtin.os.tag == .windows) {
        return "C:\\Temp";
    } else {
        return "/tmp";
    }
}
/// Platform-specific line ending
fn getLineEnding() []const u8 {
    if (builtin.os.tag == .windows) {
        return "\r\n";
    } else {
        return "\n";
    }
}
// ---------------------------------------------------------
// STEP 4: Build mode optimizations
// ---------------------------------------------------------
fn getBuildModeConfig() struct {
    enable_debug_log: bool,
    enable_assertions: bool,
    mining_threads: u32,
    tx_pool_size: u32,
} {
    return switch (builtin.mode) {
        .Debug => .{
            .enable_debug_log = true,
            .enable_assertions = true,
            .mining_threads = 1,
            .tx_pool_size = 100,
        },
        .ReleaseSafe => .{
            .enable_debug_log = false,
            .enable_assertions = true, // keep safety checks
            .mining_threads = 4,
            .tx_pool_size = 10_000,
        },
        .ReleaseFast => .{
            .enable_debug_log = false,
            .enable_assertions = false,
            .mining_threads = 8,
            .tx_pool_size = 50_000,
        },
        .ReleaseSmall => .{
            .enable_debug_log = false,
            .enable_assertions = false,
            .mining_threads = 2,
            .tx_pool_size = 1_000,
        },
    };
}
const build_config = getBuildModeConfig();
// ---------------------------------------------------------
// STEP 5: Cross-platform struct layout safety
// ---------------------------------------------------------
/// SAFE: uses fixed-size types (works on ALL platforms)
const WireBlock = extern struct {
    height: u64, // 8 bytes everywhere
    timestamp: u64, // 8 bytes everywhere
    hash: [32]u8, // 32 bytes everywhere
    difficulty: u32, // 4 bytes everywhere
    nonce: u32, // 4 bytes everywhere
};
/// UNSAFE for wire protocol: uses platform-dependent types!
const UnsafeBlock = struct {
    height: usize, // 4 bytes on 32-bit, 8 bytes on 64-bit!
    timestamp: isize, // same problem!
    ptr: ?*u8, // pointer size varies!
};
pub fn main() !void {
    std.debug.print("\n=== Lesson 10.2: Conditional Compilation ===\n\n", .{});
    // Platform config (resolved at compile time)
    std.debug.print("  --- Platform Config (comptime) ---\n\n", .{});
    std.debug.print("    OS:              {s}\n", .{@tagName(builtin.os.tag)});
    std.debug.print("    Arch:            {s}\n", .{@tagName(builtin.cpu.arch)});
    std.debug.print("    Data dir:        ~/{s}\n", .{config.data_dir});
    std.debug.print("    Config file:     ~/{s}\n", .{config.config_file});
    std.debug.print("    Log file:        {s}\n", .{config.log_file});
    std.debug.print("    Path separator:  '{c}'\n", .{config.path_separator});
    std.debug.print("    Max open files:  {d}\n", .{config.max_open_files});
    std.debug.print("    Color output:    {}\n", .{config.use_color});
    // Hash engine selection
    std.debug.print("\n  --- Hardware Optimization ---\n\n", .{});
    std.debug.print("    Hash engine:     {s}\n", .{selectHashEngine()});
    std.debug.print("    Alignment:       {d} bytes\n", .{optimalAlignment()});
    std.debug.print("    Temp dir:        {s}\n", .{getTempDir()});
    std.debug.print("    Line ending:     {s}\n", .{if (std.mem.eql(u8, getLineEnding(), "\n")) "LF (Unix)" else "CRLF (Windows)"});
    // Build mode config
    std.debug.print("\n  --- Build Mode Config ---\n\n", .{});
    std.debug.print("    Build mode:      {s}\n", .{@tagName(builtin.mode)});
    std.debug.print("    Debug logging:   {}\n", .{build_config.enable_debug_log});
    std.debug.print("    Assertions:      {}\n", .{build_config.enable_assertions});
    std.debug.print("    Mining threads:  {d}\n", .{build_config.mining_threads});
    std.debug.print("    TX pool size:    {d}\n", .{build_config.tx_pool_size});
    // Cross-platform safety
    std.debug.print("\n  --- Wire Protocol Safety ---\n\n", .{});
    std.debug.print("    WireBlock (extern):  {d} bytes ← SAME on all platforms ✅\n", .{@sizeOf(WireBlock)});
    std.debug.print("    UnsafeBlock:         {d} bytes ← VARIES by platform ❌\n", .{@sizeOf(UnsafeBlock)});
    std.debug.print("    usize:               {d} bytes (platform-dependent!)\n", .{@sizeOf(usize)});
    std.debug.print("    u64:                 {d} bytes (always 8 — use this!)\n", .{@sizeOf(u64)});
    // Build commands cheat sheet
    std.debug.print("\n  --- Cross-Compile Commands ---\n\n", .{});
    std.debug.print("    # Current platform:\n", .{});
    std.debug.print("    zig build-exe 02_conditional.zig\n\n", .{});
    std.debug.print("    # Release builds:\n", .{});
    std.debug.print("    zig build-exe -OReleaseFast 02_conditional.zig\n", .{});
    std.debug.print("    zig build-exe -OReleaseSmall 02_conditional.zig\n\n", .{});
    std.debug.print("    # Cross-compile:\n", .{});
    std.debug.print("    zig build-exe -target x86_64-linux 02_conditional.zig\n", .{});
    std.debug.print("    zig build-exe -target aarch64-linux 02_conditional.zig\n", .{});
    std.debug.print("    zig build-exe -target x86_64-windows 02_conditional.zig\n", .{});
    std.debug.print("\n✅ Conditional compilation mastered!\n\n", .{});
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. switch (builtin.os.tag) replaces C's #ifdef _WIN32
// 2. All branches are COMPILED — Zig checks all paths even
//    for other targets (catches bugs before cross-compile!)
// 3. builtin.cpu.features detects hardware crypto support
// 4. Use extern struct + u64/u32 for wire protocols (portable)
// 5. Build mode (Debug/Release) configures behavior at comptime
// 6. NO preprocessor needed — just regular Zig control flow
//
// 🔬 EXPERIMENT:
//   - Cross-compile this file to Linux and check the output
//   - Build with -OReleaseFast — see config changes
//   - Add RISC-V target support (riscv64-linux)
//   - Add FreeBSD platform config
// ============================================================
