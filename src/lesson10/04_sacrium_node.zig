const std = @import("std");
const builtin = @import("builtin");
// ============================================================
// EXERCISE 4: Sacrium Node Binary — Cross-Compile Ready
// ============================================================
// The FINAL exercise: a real blockchain node binary that
// detects its platform, configures itself, and runs a
// basic node loop. This is what you'd ship to production.
//
// Build & Run:
//   zig build run
//   zig build run -- --info
//   zig build run -- --mine
//
// Cross-compile:
//   zig build -Dtarget=x86_64-linux
//   zig build -Dtarget=aarch64-linux
//   zig build -Dtarget=x86_64-windows
//
// Check binary:
//   file zig-out/bin/sacrium-node
//   ls -la zig-out/bin/sacrium-node
// ============================================================
// ===================== Version Info =========================
const VERSION = "1.0.0";
const PROTOCOL_VERSION: u32 = 1;
const NETWORK_MAGIC: u32 = 0x5343524D;
const USER_AGENT = "sacrium-node/" ++ VERSION;
// ===================== Platform Config ======================
const PlatformInfo = struct {
    os_name: []const u8,
    arch_name: []const u8,
    data_dir: []const u8,
    max_peers: u32,
    default_port: u16,
    has_hw_crypto: bool,
    fn detect() PlatformInfo {
        const os_name = @tagName(builtin.os.tag);
        const arch_name = @tagName(builtin.cpu.arch);
        const data_dir = switch (builtin.os.tag) {
            .macos => "~/Library/Application Support/Sacrium",
            .linux => "~/.sacrium",
            .windows => "%APPDATA%\\Sacrium",
            else => "./sacrium_data",
        };
        const max_peers: u32 = switch (builtin.cpu.arch) {
            .x86_64 => 125,
            .aarch64 => 64,
            else => 25,
        };
        const has_hw_crypto = if (builtin.cpu.arch == .x86_64)
            std.Target.x86.featureSetHas(builtin.cpu.features, .aes)
        else if (builtin.cpu.arch == .aarch64)
            std.Target.aarch64.featureSetHas(builtin.cpu.features, .sha2)
        else
            false;
        return .{
            .os_name = os_name,
            .arch_name = arch_name,
            .data_dir = data_dir,
            .max_peers = max_peers,
            .default_port = 9333,
            .has_hw_crypto = has_hw_crypto,
        };
    }
};
// ===================== Block Types ==========================
const BlockHeader = extern struct {
    magic: u32 = NETWORK_MAGIC,
    version: u32 = PROTOCOL_VERSION,
    height: u64,
    timestamp: u64,
    prev_hash: [32]u8,
    merkle_root: [32]u8,
    difficulty: u32,
    nonce: u32,
    fn hash(self: *const BlockHeader) [32]u8 {
        const ptr: [*]const u8 = @ptrCast(self);
        var result: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(ptr[0..@sizeOf(BlockHeader)], &result, .{});
        return result;
    }
    fn meetsDifficulty(self: *const BlockHeader) bool {
        const h = self.hash();
        var zeros: u32 = 0;
        for (h) |byte| {
            if (byte == 0) {
                zeros += 8;
            } else {
                zeros += @clz(byte);
                break;
            }
        }
        return zeros >= self.difficulty;
    }
};
// ===================== Node State ===========================
const NodeState = struct {
    chain_height: u64 = 0,
    peer_count: u32 = 0,
    mempool_size: u32 = 0,
    blocks_mined: u64 = 0,
    last_block_hash: [32]u8 = .{0} ** 32,
    uptime_start: i64,
    fn init() NodeState {
        return .{
            .uptime_start = std.time.timestamp(),
        };
    }
    fn uptimeSeconds(self: *const NodeState) i64 {
        return std.time.timestamp() - self.uptime_start;
    }
};
// ===================== Commands =============================
fn showInfo(platform: PlatformInfo) void {
    std.debug.print("\n", .{});
    std.debug.print("  ╔══════════════════════════════════════════════╗\n", .{});
    std.debug.print("  ║                                              ║\n", .{});
    std.debug.print("  ║     ⛓️  SACRIUM NODE v{s}                  ║\n", .{VERSION});
    std.debug.print("  ║     Proof-Driven Hybrid Blockchain           ║\n", .{});
    std.debug.print("  ║                                              ║\n", .{});
    std.debug.print("  ╚══════════════════════════════════════════════╝\n\n", .{});
    std.debug.print("  Platform:\n", .{});
    std.debug.print("    OS:           {s}\n", .{platform.os_name});
    std.debug.print("    Architecture: {s}\n", .{platform.arch_name});
    std.debug.print("    Pointer size: {d}-bit\n", .{@bitSizeOf(usize)});
    std.debug.print("    Build mode:   {s}\n", .{@tagName(builtin.mode)});
    std.debug.print("    HW Crypto:    {s}\n", .{if (platform.has_hw_crypto) "✅ Accelerated" else "⚙️ Software"});
    std.debug.print("\n  Network:\n", .{});
    std.debug.print("    Protocol:     v{d}\n", .{PROTOCOL_VERSION});
    std.debug.print("    Magic:        0x{x:0>8}\n", .{NETWORK_MAGIC});
    std.debug.print("    Port:         {d}\n", .{platform.default_port});
    std.debug.print("    Max peers:    {d}\n", .{platform.max_peers});
    std.debug.print("    User agent:   {s}\n", .{USER_AGENT});
    std.debug.print("\n  Storage:\n", .{});
    std.debug.print("    Data dir:     {s}\n", .{platform.data_dir});
    std.debug.print("    Block size:   {d} bytes\n", .{@sizeOf(BlockHeader)});
    std.debug.print("\n  Wire Protocol Sizes:\n", .{});
    std.debug.print("    BlockHeader:  {d} bytes (same on ALL platforms ✅)\n", .{@sizeOf(BlockHeader)});
    std.debug.print("    Endianness:   {s}\n", .{@tagName(builtin.cpu.arch.endian())});
    std.debug.print("\n", .{});
}
fn simulateMining(state: *NodeState) void {
    std.debug.print("\n  ⛏️  Mining Simulation\n\n", .{});
    var prev_hash: [32]u8 = state.last_block_hash;
    for (0..3) |i| {
        var block = BlockHeader{
            .height = state.chain_height + i,
            .timestamp = @intCast(std.time.timestamp()),
            .prev_hash = prev_hash,
            .merkle_root = .{@as(u8, @intCast(i + 1))} ** 32,
            .difficulty = 8,
            .nonce = 0,
        };
        const start = std.time.milliTimestamp();
        var attempts: u32 = 0;
        while (attempts < 1_000_000) : (attempts += 1) {
            block.nonce = attempts;
            if (block.meetsDifficulty()) {
                const elapsed = std.time.milliTimestamp() - start;
                const h = block.hash();
                std.debug.print("    Block #{d}: mined in {d}ms ({d} attempts)\n", .{
                    block.height, elapsed, attempts + 1,
                });
                std.debug.print("    Hash: ", .{});
                for (h[0..8]) |byte| std.debug.print("{x:0>2}", .{byte});
                std.debug.print("...\n\n", .{});
                prev_hash = h;
                state.blocks_mined += 1;
                break;
            }
        }
    }
    state.chain_height += 3;
    state.last_block_hash = prev_hash;
    std.debug.print("    Chain height: {d}\n", .{state.chain_height});
    std.debug.print("    Total mined:  {d}\n\n", .{state.blocks_mined});
}
fn showStatus(state: *const NodeState, platform: PlatformInfo) void {
    const uptime = state.uptimeSeconds();
    std.debug.print("\n  📊 Node Status\n\n", .{});
    std.debug.print("    Chain height:   {d}\n", .{state.chain_height});
    std.debug.print("    Blocks mined:   {d}\n", .{state.blocks_mined});
    std.debug.print("    Mempool:        {d} txns\n", .{state.mempool_size});
    std.debug.print("    Peers:          {d}/{d}\n", .{ state.peer_count, platform.max_peers });
    std.debug.print("    Uptime:         {d}s\n", .{uptime});
    std.debug.print("    Last hash:      ", .{});
    for (state.last_block_hash[0..6]) |byte| std.debug.print("{x:0>2}", .{byte});
    std.debug.print("...\n\n", .{});
}
pub fn main() !void {
    const platform = PlatformInfo.detect();
    var state = NodeState.init();
    var args = std.process.args();
    _ = args.next(); // skip program name
    const command = args.next() orelse "--info";
    if (std.mem.eql(u8, command, "--info") or std.mem.eql(u8, command, "-i")) {
        showInfo(platform);
    } else if (std.mem.eql(u8, command, "--mine") or std.mem.eql(u8, command, "-m")) {
        showInfo(platform);
        simulateMining(&state);
        showStatus(&state, platform);
    } else if (std.mem.eql(u8, command, "--status") or std.mem.eql(u8, command, "-s")) {
        showStatus(&state, platform);
    } else if (std.mem.eql(u8, command, "--help") or std.mem.eql(u8, command, "-h")) {
        std.debug.print("\n  Sacrium Node v{s}\n\n", .{VERSION});
        std.debug.print("  Usage: sacrium-node [OPTIONS]\n\n", .{});
        std.debug.print("  Options:\n", .{});
        std.debug.print("    --info, -i      Show node & platform info\n", .{});
        std.debug.print("    --mine, -m      Mine 3 test blocks\n", .{});
        std.debug.print("    --status, -s    Show node status\n", .{});
        std.debug.print("    --help, -h      Show this help\n\n", .{});
        std.debug.print("  Cross-compile:\n", .{});
        std.debug.print("    zig build -Dtarget=x86_64-linux\n", .{});
        std.debug.print("    zig build -Dtarget=aarch64-linux\n", .{});
        std.debug.print("    zig build -Dtarget=x86_64-windows\n\n", .{});
    } else {
        std.debug.print("Unknown command: {s}. Try --help\n", .{command});
    }
}
// ===================== TESTS ================================
test "block hash is deterministic" {
    const block = BlockHeader{
        .height = 0,
        .timestamp = 1708900000,
        .prev_hash = .{0} ** 32,
        .merkle_root = .{0} ** 32,
        .difficulty = 1,
        .nonce = 0,
    };
    const h1 = block.hash();
    const h2 = block.hash();
    try std.testing.expectEqualSlices(u8, &h1, &h2);
}
test "wire protocol struct size is fixed" {
    // This MUST be the same on ALL platforms
    try std.testing.expectEqual(@as(usize, 96), @sizeOf(BlockHeader));
}
test "genesis block has zero prev_hash" {
    const genesis = BlockHeader{
        .height = 0,
        .timestamp = 1708900000,
        .prev_hash = .{0} ** 32,
        .merkle_root = .{0} ** 32,
        .difficulty = 8,
        .nonce = 0,
    };
    const zeros = [_]u8{0} ** 32;
    try std.testing.expectEqualSlices(u8, &zeros, &genesis.prev_hash);
}
test "platform info detects correctly" {
    const platform = PlatformInfo.detect();
    try std.testing.expect(platform.os_name.len > 0);
    try std.testing.expect(platform.arch_name.len > 0);
    try std.testing.expect(platform.default_port == 9333);
    try std.testing.expect(platform.max_peers > 0);
}
// ============================================================
// 🧠 KEY TAKEAWAYS — ENTIRE LESSON 10:
//
// 1. Zig cross-compiles to 40+ targets with ZERO setup
// 2. builtin.os.tag + builtin.cpu.arch = comptime platform info
// 3. build.zig = the build system (Makefile replacement)
// 4. -Dtarget=x86_64-linux = one flag to cross-compile
// 5. -Doptimize=ReleaseFast = production optimization
// 6. extern struct = SAME byte layout on ALL platforms
// 7. Tests verify wire protocol sizes are platform-independent
//
// ============================================================
//
// 🎓 CONGRATULATIONS — YOU'VE COMPLETED ALL 10 LESSONS!
//
//   Lesson 1:  Structs & Serialization
//   Lesson 2:  Memory Management & Allocators
//   Lesson 3:  Pointers & Slices
//   Lesson 4:  Error Handling
//   Lesson 5:  Comptime (Compile-Time Computation)
//   Lesson 6:  FFI with C Libraries
//   Lesson 7:  Testing in Zig
//   Lesson 8:  File I/O & Binary Formats
//   Lesson 9:  Networking (TCP/UDP)
//   Lesson 10: Cross-Compilation
//
// You now have ALL the Zig skills needed to build your
// Sacrium proof-driven hybrid blockchain. The next step:
//   → Combine everything into a single project with build.zig
//   → Implement consensus (PoS/PoW hybrid)
//   → Build the full P2P protocol
//   → Deploy cross-compiled binaries to validators
//
// 🚀 Time to build the real thing!
// ============================================================
