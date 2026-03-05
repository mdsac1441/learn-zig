const std = @import("std");
const net = std.net;
const posix = std.posix;
// ============================================================
// EXERCISE 2: UDP Peer Discovery — Broadcast & Listen
// ============================================================
// UDP = connectionless, fire-and-forget. Perfect for:
//   - Peer discovery (broadcast "I'm here!" on the LAN)
//   - Heartbeats / keep-alive pings
//   - Fast, lossy data (block height announcements)
//
// This exercise simulates peer discovery on localhost.
//
// Run: zig run 02_udp_discovery.zig
//
// YOUR BLOCKCHAIN USE CASE:
//   New node joins the network → broadcasts a DISCOVER message
//   → existing nodes respond with their peer lists.
// ============================================================
const DISCOVERY_PORT: u16 = 9334;
const MAGIC: u32 = 0x5343524D; // "SCRM"
/// Discovery message — sent via UDP
const DiscoveryMsg = extern struct {
    magic: u32 = MAGIC,
    msg_type: u8, // 1=DISCOVER, 2=ANNOUNCE, 3=PEERS
    version: u8 = 1,
    _pad: [2]u8 = .{ 0, 0 },
    node_id: u64,
    port: u16,
    _pad2: [6]u8 = .{0} ** 6,
    block_height: u64,
    timestamp: u64,
};
const MsgType = struct {
    const DISCOVER: u8 = 1;
    const ANNOUNCE: u8 = 2;
    const PEERS: u8 = 3;
};
fn msgTypeName(t: u8) []const u8 {
    return switch (t) {
        MsgType.DISCOVER => "DISCOVER",
        MsgType.ANNOUNCE => "ANNOUNCE",
        MsgType.PEERS => "PEERS",
        else => "UNKNOWN",
    };
}
pub fn main() !void {
    std.debug.print("\n=== Lesson 9.2: UDP Peer Discovery ===\n\n", .{});
    // ---------------------------------------------------------
    // STEP 1: Create a UDP socket
    // ---------------------------------------------------------
    std.debug.print("  --- UDP Socket Setup ---\n", .{});
    const sock = try posix.socket(posix.AF.INET, posix.SOCK.DGRAM, 0);
    defer posix.close(sock);
    // Allow address reuse
    try posix.setsockopt(sock, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
    // Bind to the discovery port
    const bind_addr = net.Address.initIp4(.{ 127, 0, 0, 1 }, DISCOVERY_PORT);
    try posix.bind(sock, &bind_addr.any, bind_addr.getOsSockLen());
    std.debug.print("    Bound UDP socket to port {d}\n", .{DISCOVERY_PORT});
    // Set receive timeout (so we don't block forever)
    const timeout = posix.timeval{ .sec = 0, .usec = 500_000 }; // 500ms
    try posix.setsockopt(sock, posix.SOL.SOCKET, posix.SO.RCVTIMEO, &std.mem.toBytes(timeout));
    // ---------------------------------------------------------
    // STEP 2: Simulate sending discovery messages
    // ---------------------------------------------------------
    std.debug.print("\n  --- Sending Discovery Messages ---\n\n", .{});
    const target_addr = net.Address.initIp4(.{ 127, 0, 0, 1 }, DISCOVERY_PORT);
    // Simulate 3 different nodes discovering the network
    const nodes = [_]struct { id: u64, port: u16, height: u64 }{
        .{ .id = 1001, .port = 9001, .height = 0 }, // New node
        .{ .id = 2002, .port = 9002, .height = 15000 }, // Synced node
        .{ .id = 3003, .port = 9003, .height = 14998 }, // Slightly behind
    };
    for (nodes) |node| {
        const msg = DiscoveryMsg{
            .msg_type = MsgType.DISCOVER,
            .node_id = node.id,
            .port = node.port,
            .block_height = node.height,
            .timestamp = @intCast(std.time.timestamp()),
        };
        const msg_bytes: [*]const u8 = @ptrCast(&msg);
        _ = posix.sendto(
            sock,
            msg_bytes[0..@sizeOf(DiscoveryMsg)],
            0,
            &target_addr.any,
            target_addr.getOsSockLen(),
        ) catch |err| {
            std.debug.print("    Send error: {s}\n", .{@errorName(err)});
            continue;
        };
        std.debug.print("    📡 Sent {s} from node #{d} (height={d}, port={d})\n", .{
            msgTypeName(msg.msg_type), node.id, node.height, node.port,
        });
    }
    // ---------------------------------------------------------
    // STEP 3: Receive and process discovery messages
    // ---------------------------------------------------------
    std.debug.print("\n  --- Receiving Discovery Messages ---\n\n", .{});
    var received: u32 = 0;
    var peer_list: [16]struct { id: u64, height: u64 } = undefined;
    var peer_count: usize = 0;
    for (0..10) |_| {
        var recv_buf: [@sizeOf(DiscoveryMsg)]u8 = undefined;
        var src_addr: posix.sockaddr = undefined;
        var addr_len: posix.socklen_t = @sizeOf(posix.sockaddr);
        const bytes = posix.recvfrom(sock, &recv_buf, 0, &src_addr, &addr_len) catch {
            // Timeout — no more messages
            break;
        };
        if (bytes < @sizeOf(DiscoveryMsg)) continue;
        const msg: *const DiscoveryMsg = @ptrCast(@alignCast(&recv_buf));
        // Verify magic
        if (msg.magic != MAGIC) {
            std.debug.print("    ⚠️  Unknown protocol message, skipping\n", .{});
            continue;
        }
        received += 1;
        std.debug.print("    📥 [{d}] {s} from node #{d} — height={d}\n", .{
            received, msgTypeName(msg.msg_type), msg.node_id, msg.block_height,
        });
        // Build peer list
        if (peer_count < 16) {
            peer_list[peer_count] = .{ .id = msg.node_id, .height = msg.block_height };
            peer_count += 1;
        }
    }
    // ---------------------------------------------------------
    // STEP 4: Display discovered peers
    // ---------------------------------------------------------
    std.debug.print("\n  --- Discovered Peers ---\n\n", .{});
    if (peer_count == 0) {
        std.debug.print("    No peers discovered (normal for localhost demo)\n", .{});
    } else {
        // Find best peer (highest block height) for chain sync
        var best_peer: usize = 0;
        for (peer_list[0..peer_count], 0..) |peer, i| {
            std.debug.print("    Peer #{d}: height={d}\n", .{ peer.id, peer.height });
            if (peer.height > peer_list[best_peer].height) {
                best_peer = i;
            }
        }
        std.debug.print("\n    🏆 Best peer for sync: #{d} (height={d})\n", .{
            peer_list[best_peer].id, peer_list[best_peer].height,
        });
    }
    // ---------------------------------------------------------
    // STEP 5: Announce response
    // ---------------------------------------------------------
    std.debug.print("\n  --- Sending Announce Response ---\n\n", .{});
    const announce = DiscoveryMsg{
        .msg_type = MsgType.ANNOUNCE,
        .node_id = 9999,
        .port = 9333,
        .block_height = 15001, // We're the most up-to-date
        .timestamp = @intCast(std.time.timestamp()),
    };
    const announce_bytes: [*]const u8 = @ptrCast(&announce);
    _ = posix.sendto(
        sock,
        announce_bytes[0..@sizeOf(DiscoveryMsg)],
        0,
        &target_addr.any,
        target_addr.getOsSockLen(),
    ) catch {};
    std.debug.print("    📢 Sent ANNOUNCE: node #9999, height=15001\n", .{});
    // ---------------------------------------------------------
    // Summary
    // ---------------------------------------------------------
    std.debug.print("\n  --- UDP vs TCP for Blockchain ---\n\n", .{});
    std.debug.print("    ┌──────────────────┬──────────────────────────────┐\n", .{});
    std.debug.print("    │ Use UDP for      │ Use TCP for                  │\n", .{});
    std.debug.print("    ├──────────────────┼──────────────────────────────┤\n", .{});
    std.debug.print("    │ Peer discovery   │ Block transfer               │\n", .{});
    std.debug.print("    │ Height announce  │ Transaction relay            │\n", .{});
    std.debug.print("    │ Heartbeats       │ Chain sync (IBD)             │\n", .{});
    std.debug.print("    │ Fast pings       │ State queries                │\n", .{});
    std.debug.print("    └──────────────────┴──────────────────────────────┘\n", .{});
    std.debug.print("\n✅ UDP peer discovery mastered!\n\n", .{});
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. posix.socket(AF.INET, SOCK.DGRAM, 0) = UDP socket
// 2. posix.sendto() sends datagrams to a specific address
// 3. posix.recvfrom() receives datagrams with sender address
// 4. Set SO.RCVTIMEO to avoid blocking forever on recv
// 5. UDP is fire-and-forget — messages may be lost/reordered
// 6. extern struct messages can be sent/received as raw bytes
//
// 🔬 EXPERIMENT:
//   - Run multiple instances on different ports — real discovery
//   - Add a PING/PONG heartbeat protocol
//   - Implement peer scoring (prefer high-height peers)
//   - Add TTL to discovery messages (expire after 30 seconds)
// ============================================================
