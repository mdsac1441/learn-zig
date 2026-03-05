const std = @import("std");
const net = std.net;
// ============================================================
// EXERCISE 1: TCP Echo Server + Client
// ============================================================
// TCP = reliable, ordered, connection-based. Perfect for
// block sync and peer-to-peer message exchange.
//
// Run in TWO terminals:
//   Terminal 1: zig run 01_tcp_echo.zig -- server
//   Terminal 2: zig run 01_tcp_echo.zig -- client
//
// YOUR BLOCKCHAIN USE CASE:
//   Nodes connect via TCP to exchange blocks and transactions.
//   The echo server pattern is the foundation for your P2P layer.
// ============================================================
const PORT: u16 = 9333;
const HOST = "127.0.0.1";
fn runServer() !void {
    std.debug.print("\n=== TCP Echo Server (port {d}) ===\n\n", .{PORT});
    // ---------------------------------------------------------
    // STEP 1: Create a TCP listener
    // ---------------------------------------------------------
    const address = try net.Address.parseIp4(HOST, PORT);
    var server = try address.listen(.{
        .reuse_address = true,
    });
    defer server.deinit();
    std.debug.print("  🟢 Listening on {s}:{d}\n", .{ HOST, PORT });
    std.debug.print("  Waiting for connections...\n\n", .{});
    // ---------------------------------------------------------
    // STEP 2: Accept a connection
    // ---------------------------------------------------------
    const connection = try server.accept();
    defer connection.stream.close();
    const peer_addr = connection.address;
    std.debug.print("  📡 Client connected from {any}\n\n", .{peer_addr});
    // ---------------------------------------------------------
    // STEP 3: Echo loop — read and echo back
    // ---------------------------------------------------------
    var buf: [1024]u8 = undefined;
    var msg_count: u32 = 0;
    while (true) {
        const bytes_read = connection.stream.read(&buf) catch |err| {
            std.debug.print("  Read error: {s}\n", .{@errorName(err)});
            break;
        };
        if (bytes_read == 0) {
            std.debug.print("  Client disconnected.\n", .{});
            break;
        }
        msg_count += 1;
        const msg = buf[0..bytes_read];
        std.debug.print("  [{d}] Received ({d} bytes): \"{s}\"\n", .{ msg_count, bytes_read, msg });
        // Check for quit command
        if (std.mem.startsWith(u8, msg, "QUIT")) {
            _ = connection.stream.write("GOODBYE\n") catch {};
            std.debug.print("  Client requested disconnect.\n", .{});
            break;
        }
        // Echo back with prefix
        var response_buf: [1100]u8 = undefined;
        const response = std.fmt.bufPrint(&response_buf, "ECHO: {s}", .{msg}) catch msg;
        _ = connection.stream.write(response) catch |err| {
            std.debug.print("  Write error: {s}\n", .{@errorName(err)});
            break;
        };
    }
    std.debug.print("\n  Server handled {d} messages.\n", .{msg_count});
    std.debug.print("  ✅ Server shutdown cleanly.\n\n", .{});
}
fn runClient() !void {
    std.debug.print("\n=== TCP Echo Client → {s}:{d} ===\n\n", .{ HOST, PORT });
    // ---------------------------------------------------------
    // STEP 1: Connect to the server
    // ---------------------------------------------------------
    const address = try net.Address.parseIp4(HOST, PORT);
    const stream = try net.tcpConnectToAddress(address);
    defer stream.close();
    std.debug.print("  🔗 Connected to server!\n\n", .{});
    // ---------------------------------------------------------
    // STEP 2: Send messages
    // ---------------------------------------------------------
    const messages = [_][]const u8{
        "HELLO SACRIUM NODE",
        "GETBLOCKS 0 10",
        "TX: Alice→Bob 100 SCR",
        "PING",
        "GETPEERS",
        "QUIT",
    };
    var buf: [1024]u8 = undefined;
    for (messages) |msg| {
        std.debug.print("  → Sending: \"{s}\"\n", .{msg});
        _ = try stream.write(msg);
        // Read response
        const bytes_read = try stream.read(&buf);
        if (bytes_read > 0) {
            std.debug.print("  ← Received: \"{s}\"\n\n", .{buf[0..bytes_read]});
        }
        // Small delay between messages
        std.Thread.sleep(100 * std.time.ns_per_ms);
    }
    std.debug.print("  ✅ Client done.\n\n", .{});
}
pub fn main() !void {
    var args = std.process.args();
    _ = args.next(); // skip program name
    const mode = args.next() orelse {
        std.debug.print("\nUsage:\n", .{});
        std.debug.print("  Terminal 1: zig run 01_tcp_echo.zig -- server\n", .{});
        std.debug.print("  Terminal 2: zig run 01_tcp_echo.zig -- client\n\n", .{});
        return;
    };
    if (std.mem.eql(u8, mode, "server")) {
        try runServer();
    } else if (std.mem.eql(u8, mode, "client")) {
        try runClient();
    } else {
        std.debug.print("Unknown mode: {s}. Use 'server' or 'client'.\n", .{mode});
    }
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. net.Address.parseIp4() creates a socket address
// 2. address.listen(.{}) starts a TCP server
// 3. server.accept() waits for a client connection
// 4. net.tcpConnectToAddress() connects as a client
// 5. stream.read()/write() for bidirectional data
// 6. defer stream.close() ensures cleanup
//
// 🔬 EXPERIMENT:
//   - Send binary data (struct bytes) instead of strings
//   - Modify server to handle multiple clients sequentially
//   - Add a heartbeat — server pings client every 5 seconds
//   - Measure round-trip time (latency) for each message
// ============================================================
