const std = @import("std");
const net = std.net;
// ============================================================
// EXERCISE 4: P2P Blockchain Node — Block Propagation
// ============================================================
// Two nodes connect, perform a handshake, then exchange blocks.
// This is the foundation of your blockchain's P2P layer.
//
// Run in TWO terminals:
//   Terminal 1: zig run 04_p2p_node.zig -- node1
//   Terminal 2: zig run 04_p2p_node.zig -- node2
//
// node1 = listener (has blocks 0-4, listens on port 9335)
// node2 = connector (has no blocks, connects and syncs)
// ============================================================
const MAGIC: u32 = 0x5343524D;
const PORT: u16 = 9335;
// ===================== Protocol Types =======================
const MsgType = enum(u8) {
    version = 0x01,
    verack = 0x02,
    getblocks = 0x10,
    block = 0x11,
    no_more = 0x12,
};
const MsgHeader = extern struct {
    magic: u32 = MAGIC,
    msg_type: u8,
    _pad: [3]u8 = .{ 0, 0, 0 },
    payload_len: u32,
    checksum: u32,
};
const VersionMsg = extern struct {
    node_id: u64,
    block_height: u64,
    timestamp: u64,
};
const GetBlocksMsg = extern struct {
    start_height: u64,
    max_count: u64,
};
const BlockMsg = extern struct {
    height: u64,
    timestamp: u64,
    prev_hash: [32]u8,
    merkle_root: [32]u8,
    difficulty: u32,
    nonce_val: u32,
    tx_count: u32,
    _pad: u32 = 0,
    fn hash(self: *const BlockMsg) [32]u8 {
        const ptr: [*]const u8 = @ptrCast(self);
        var result: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(ptr[0..@sizeOf(BlockMsg)], &result, .{});
        return result;
    }
};
// ===================== Send / Receive =======================
fn sendMessage(comptime T: type, stream: net.Stream, msg_type: MsgType, payload: *const T) !void {
    const payload_bytes: [*]const u8 = @ptrCast(payload);
    const payload_slice = payload_bytes[0..@sizeOf(T)];
    const header = MsgHeader{
        .msg_type = @intFromEnum(msg_type),
        .payload_len = @sizeOf(T),
        .checksum = std.hash.Crc32.hash(payload_slice),
    };
    const header_bytes: [*]const u8 = @ptrCast(&header);
    _ = try stream.write(header_bytes[0..@sizeOf(MsgHeader)]);
    _ = try stream.write(payload_slice);
}
fn sendEmpty(stream: net.Stream, msg_type: MsgType) !void {
    const header = MsgHeader{
        .msg_type = @intFromEnum(msg_type),
        .payload_len = 0,
        .checksum = 0,
    };
    const header_bytes: [*]const u8 = @ptrCast(&header);
    _ = try stream.write(header_bytes[0..@sizeOf(MsgHeader)]);
}
fn recvHeader(stream: net.Stream) !MsgHeader {
    var buf: [@sizeOf(MsgHeader)]u8 = undefined;
    var total: usize = 0;
    while (total < @sizeOf(MsgHeader)) {
        const n = try stream.read(buf[total..]);
        if (n == 0) return error.ConnectionClosed;
        total += n;
    }
    return @as(*const MsgHeader, @ptrCast(@alignCast(&buf))).*;
}
fn recvPayload(comptime T: type, stream: net.Stream) !T {
    var buf: [@sizeOf(T)]u8 = undefined;
    var total: usize = 0;
    while (total < @sizeOf(T)) {
        const n = try stream.read(buf[total..]);
        if (n == 0) return error.ConnectionClosed;
        total += n;
    }
    return @as(*const T, @ptrCast(@alignCast(&buf))).*;
}
// ===================== Node 1: Listener =====================
fn runNode1() !void {
    std.debug.print("\n=== Node 1 (Listener) — Port {d} ===\n\n", .{PORT});
    // Create some blocks to serve
    var blocks: [5]BlockMsg = undefined;
    var prev: [32]u8 = .{0} ** 32;
    for (&blocks, 0..) |*b, i| {
        b.* = BlockMsg{
            .height = i,
            .timestamp = 1708900000 + i * 600,
            .prev_hash = prev,
            .merkle_root = .{@as(u8, @intCast(i + 1))} ** 32,
            .difficulty = 16,
            .nonce_val = @intCast(i * 1337),
            .tx_count = @intCast(i + 1),
        };
        prev = b.hash();
    }
    std.debug.print("  Generated {d} blocks (chain ready)\n\n", .{blocks.len});
    // Listen for connections
    const address = try net.Address.parseIp4("127.0.0.1", PORT);
    var server = try address.listen(.{ .reuse_address = true });
    defer server.deinit();
    std.debug.print("  🟢 Listening... (run node2 in another terminal)\n\n", .{});
    const conn = try server.accept();
    defer conn.stream.close();
    std.debug.print("  📡 Peer connected!\n\n", .{});
    // --- HANDSHAKE ---
    // 1. Receive VERSION from peer
    const header1 = try recvHeader(conn.stream);
    if (header1.msg_type != @intFromEnum(MsgType.version)) {
        std.debug.print("  ❌ Expected VERSION, got {d}\n", .{header1.msg_type});
        return;
    }
    const peer_version = try recvPayload(VersionMsg, conn.stream);
    std.debug.print("  ← VERSION from node #{d} (height={d})\n", .{
        peer_version.node_id, peer_version.block_height,
    });
    // 2. Send our VERSION
    const our_version = VersionMsg{
        .node_id = 1,
        .block_height = blocks.len,
        .timestamp = @intCast(std.time.timestamp()),
    };
    try sendMessage(VersionMsg, conn.stream, .version, &our_version);
    std.debug.print("  → VERSION sent (our height={d})\n", .{blocks.len});
    // 3. Send VERACK
    try sendEmpty(conn.stream, .verack);
    std.debug.print("  → VERACK sent\n", .{});
    // 4. Receive VERACK
    const header2 = try recvHeader(conn.stream);
    if (header2.msg_type == @intFromEnum(MsgType.verack)) {
        std.debug.print("  ← VERACK received\n", .{});
    }
    std.debug.print("  ✅ Handshake complete!\n\n", .{});
    // --- BLOCK SERVING ---
    // Wait for GETBLOCKS
    const header3 = try recvHeader(conn.stream);
    if (header3.msg_type == @intFromEnum(MsgType.getblocks)) {
        const req = try recvPayload(GetBlocksMsg, conn.stream);
        std.debug.print("  ← GETBLOCKS: start={d} max={d}\n", .{ req.start_height, req.max_count });
        // Send requested blocks
        const start = @min(req.start_height, blocks.len);
        const end = @min(start + req.max_count, blocks.len);
        for (blocks[start..end]) |*block| {
            try sendMessage(BlockMsg, conn.stream, .block, block);
            const h = block.hash();
            std.debug.print("  → BLOCK #{d} (hash={x:0>2}{x:0>2}{x:0>2}{x:0>2}...)\n", .{
                block.height, h[0], h[1], h[2], h[3],
            });
        }
        // Signal end of blocks
        try sendEmpty(conn.stream, .no_more);
        std.debug.print("  → NO_MORE (sync complete)\n", .{});
    }
    std.debug.print("\n  ✅ Node 1 done. Served {d} blocks.\n\n", .{blocks.len});
}
// ===================== Node 2: Connector ====================
fn runNode2() !void {
    std.debug.print("\n=== Node 2 (Connector) → 127.0.0.1:{d} ===\n\n", .{PORT});
    // Connect to Node 1
    const address = try net.Address.parseIp4("127.0.0.1", PORT);
    const stream = try net.tcpConnectToAddress(address);
    defer stream.close();
    std.debug.print("  🔗 Connected to Node 1!\n\n", .{});
    // --- HANDSHAKE ---
    // 1. Send VERSION
    const our_version = VersionMsg{
        .node_id = 2,
        .block_height = 0, // we have no blocks
        .timestamp = @intCast(std.time.timestamp()),
    };
    try sendMessage(VersionMsg, stream, .version, &our_version);
    std.debug.print("  → VERSION sent (our height=0)\n", .{});
    // 2. Receive VERSION from peer
    const header1 = try recvHeader(stream);
    if (header1.msg_type == @intFromEnum(MsgType.version)) {
        const peer_ver = try recvPayload(VersionMsg, stream);
        std.debug.print("  ← VERSION from node #{d} (height={d})\n", .{
            peer_ver.node_id, peer_ver.block_height,
        });
    }
    // 3. Receive VERACK
    const header2 = try recvHeader(stream);
    if (header2.msg_type == @intFromEnum(MsgType.verack)) {
        std.debug.print("  ← VERACK received\n", .{});
    }
    // 4. Send VERACK
    try sendEmpty(stream, .verack);
    std.debug.print("  → VERACK sent\n", .{});
    std.debug.print("  ✅ Handshake complete!\n\n", .{});
    // --- CHAIN SYNC ---
    std.debug.print("  📥 Requesting blocks...\n\n", .{});
    const getblocks = GetBlocksMsg{
        .start_height = 0,
        .max_count = 100,
    };
    try sendMessage(GetBlocksMsg, stream, .getblocks, &getblocks);
    // Receive blocks
    var chain: [64]BlockMsg = undefined;
    var chain_len: usize = 0;
    var prev_hash: [32]u8 = .{0} ** 32;
    while (true) {
        const header = try recvHeader(stream);
        if (header.msg_type == @intFromEnum(MsgType.no_more)) {
            std.debug.print("  ← NO_MORE — sync complete\n", .{});
            break;
        }
        if (header.msg_type == @intFromEnum(MsgType.block)) {
            const block = try recvPayload(BlockMsg, stream);
            // Validate chain link
            const chain_valid = std.mem.eql(u8, &block.prev_hash, &prev_hash);
            const status = if (chain_valid) "✅" else "❌ BROKEN CHAIN";
            const h = block.hash();
            std.debug.print("  ← BLOCK #{d}: hash={x:0>2}{x:0>2}{x:0>2}{x:0>2}... {s}\n", .{
                block.height, h[0], h[1], h[2], h[3], status,
            });
            chain[chain_len] = block;
            chain_len += 1;
            prev_hash = block.hash();
        }
    }
    // --- SHOW SYNCED CHAIN ---
    std.debug.print("\n  📊 Synced Chain ({d} blocks):\n\n", .{chain_len});
    std.debug.print("    ┌────────┬─────────────┬──────────┬──────────────┐\n", .{});
    std.debug.print("    │ Height │ Timestamp   │ Nonce    │ Hash         │\n", .{});
    std.debug.print("    ├────────┼─────────────┼──────────┼──────────────┤\n", .{});
    for (chain[0..chain_len]) |block| {
        const h = block.hash();
        std.debug.print("    │ {d:>6} │ {d:>11} │ {d:>8} │ {x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}.. │\n", .{
            block.height, block.timestamp, block.nonce_val,
            h[0],         h[1],            h[2],
            h[3],         h[4],            h[5],
        });
    }
    std.debug.print("    └────────┴─────────────┴──────────┴──────────────┘\n", .{});
    std.debug.print("\n  ✅ Node 2 synced! Now at height {d}.\n\n", .{chain_len});
}
pub fn main() !void {
    var args = std.process.args();
    _ = args.next();
    const mode = args.next() orelse {
        std.debug.print("\nUsage:\n", .{});
        std.debug.print("  Terminal 1: zig run 04_p2p_node.zig -- node1\n", .{});
        std.debug.print("  Terminal 2: zig run 04_p2p_node.zig -- node2\n\n", .{});
        std.debug.print("  node1 = listener (has blocks, serves them)\n", .{});
        std.debug.print("  node2 = connector (syncs chain from node1)\n\n", .{});
        return;
    };
    if (std.mem.eql(u8, mode, "node1")) {
        try runNode1();
    } else if (std.mem.eql(u8, mode, "node2")) {
        try runNode2();
    } else {
        std.debug.print("Unknown mode: {s}. Use 'node1' or 'node2'.\n", .{mode});
    }
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. HANDSHAKE: VERSION → VERSION → VERACK → VERACK
//    (Both nodes learn each other's height before syncing)
//
// 2. CHAIN SYNC: GETBLOCKS(start, count) → BLOCK, BLOCK, ... → NO_MORE
//    (Node with fewer blocks downloads from node with more)
//
// 3. CHAIN VALIDATION: verify prev_hash links during sync
//    (Don't trust the peer — validate everything!)
//
// 4. Binary framing: [HEADER][PAYLOAD] per message
//    (Same pattern as Exercise 3, now over real TCP!)
//
// 5. This is EXACTLY how Bitcoin's P2P protocol works
//    (Simplified, but the same architecture: version, getblocks, block)
//
// 🔬 EXPERIMENT:
//   - Add TX message broadcasting (node1 sends new TX to node2)
//   - Implement PING/PONG heartbeat every 30 seconds
//   - Add peer banning (disconnect if invalid magic)
//   - Support multiple simultaneous peer connections
//   - Add block verification (check difficulty/hash on receive)
// ============================================================
