const std = @import("std");
// ============================================================
// EXERCISE 3: Protocol Message Framing
// ============================================================
// When sending binary data over TCP, you need MESSAGE FRAMING:
// how does the receiver know where one message ends and the
// next begins? TCP is a byte STREAM, not message-based.
//
// Solution: [MAGIC][TYPE][LENGTH][PAYLOAD][CHECKSUM]
//
// This exercise builds a complete protocol encoder/decoder
// using in-memory streams (no network needed).
//
// YOUR BLOCKCHAIN USE CASE:
//   This is your P2P WIRE PROTOCOL — every block, transaction,
//   and peer message gets framed this way.
// ============================================================
const PROTOCOL_MAGIC: u32 = 0x5343524D; // "SCRM"
/// Message types in the Sacrium protocol
const MessageType = enum(u8) {
    version = 0x01,
    verack = 0x02,
    ping = 0x03,
    pong = 0x04,
    getblocks = 0x10,
    blocks = 0x11,
    tx = 0x20,
    getpeers = 0x30,
    peers = 0x31,
    reject = 0xFF,
};
/// Protocol message header (fixed size, precedes every message)
const MessageHeader = extern struct {
    magic: u32 = PROTOCOL_MAGIC,
    msg_type: u8,
    _reserved: [3]u8 = .{ 0, 0, 0 },
    payload_length: u32,
    checksum: u32, // CRC32 of payload
};
// ===================== Payload Structs ======================
const VersionPayload = extern struct {
    protocol_version: u32 = 1,
    node_id: u64,
    block_height: u64,
    timestamp: u64,
    user_agent: [32]u8,
};
const PingPayload = extern struct {
    nonce: u64,
    timestamp: u64,
};
const GetBlocksPayload = extern struct {
    start_height: u64,
    count: u32,
    _pad: u32 = 0,
};
const TxPayload = extern struct {
    sender: u64,
    receiver: u64,
    amount: u64,
    fee: u64,
    nonce_val: u64,
    signature: [64]u8,
};
// ===================== Protocol Encoder =====================
const ProtocolEncoder = struct {
    fn encode(
        comptime T: type,
        msg_type: MessageType,
        payload: *const T,
        out_buffer: []u8,
    ) !usize {
        if (out_buffer.len < @sizeOf(MessageHeader) + @sizeOf(T)) {
            return error.BufferTooSmall;
        }
        const payload_bytes: [*]const u8 = @ptrCast(payload);
        const payload_slice = payload_bytes[0..@sizeOf(T)];
        // Compute checksum (CRC32 of payload)
        const checksum = std.hash.Crc32.hash(payload_slice);
        // Write header
        const header = MessageHeader{
            .msg_type = @intFromEnum(msg_type),
            .payload_length = @sizeOf(T),
            .checksum = checksum,
        };
        const header_bytes: [*]const u8 = @ptrCast(&header);
        @memcpy(out_buffer[0..@sizeOf(MessageHeader)], header_bytes[0..@sizeOf(MessageHeader)]);
        // Write payload
        @memcpy(out_buffer[@sizeOf(MessageHeader)..][0..@sizeOf(T)], payload_slice);
        return @sizeOf(MessageHeader) + @sizeOf(T);
    }
    /// Encode a header-only message (no payload)
    fn encodeEmpty(msg_type: MessageType, out_buffer: []u8) !usize {
        if (out_buffer.len < @sizeOf(MessageHeader)) return error.BufferTooSmall;
        const header = MessageHeader{
            .msg_type = @intFromEnum(msg_type),
            .payload_length = 0,
            .checksum = 0,
        };
        const header_bytes: [*]const u8 = @ptrCast(&header);
        @memcpy(out_buffer[0..@sizeOf(MessageHeader)], header_bytes[0..@sizeOf(MessageHeader)]);
        return @sizeOf(MessageHeader);
    }
};
// ===================== Protocol Decoder =====================
const DecodeError = error{
    InvalidMagic,
    InvalidChecksum,
    PayloadTooLarge,
    BufferTooSmall,
    UnknownMessageType,
};
const DecodedMessage = struct {
    msg_type: u8,
    payload: []const u8,
    checksum_valid: bool,
};
const ProtocolDecoder = struct {
    fn decode(data: []const u8) DecodeError!DecodedMessage {
        if (data.len < @sizeOf(MessageHeader)) return error.BufferTooSmall;
        const header: *const MessageHeader = @ptrCast(@alignCast(data.ptr));
        // Verify magic
        if (header.magic != PROTOCOL_MAGIC) return error.InvalidMagic;
        // Check payload bounds
        const total = @sizeOf(MessageHeader) + header.payload_length;
        if (data.len < total) return error.BufferTooSmall;
        if (header.payload_length > 1024 * 1024) return error.PayloadTooLarge;
        // Extract and verify payload
        const payload = data[@sizeOf(MessageHeader)..total];
        var checksum_valid = true;
        if (header.payload_length > 0) {
            const actual_checksum = std.hash.Crc32.hash(payload);
            checksum_valid = (actual_checksum == header.checksum);
        }
        return DecodedMessage{
            .msg_type = header.msg_type,
            .payload = payload,
            .checksum_valid = checksum_valid,
        };
    }
    /// Cast a decoded payload to a typed struct
    fn castPayload(comptime T: type, payload: []const u8) !*const T {
        if (payload.len < @sizeOf(T)) return error.BufferTooSmall;
        return @ptrCast(@alignCast(payload.ptr));
    }
};
fn msgTypeName(t: u8) []const u8 {
    return switch (t) {
        @intFromEnum(MessageType.version) => "VERSION",
        @intFromEnum(MessageType.verack) => "VERACK",
        @intFromEnum(MessageType.ping) => "PING",
        @intFromEnum(MessageType.pong) => "PONG",
        @intFromEnum(MessageType.getblocks) => "GETBLOCKS",
        @intFromEnum(MessageType.blocks) => "BLOCKS",
        @intFromEnum(MessageType.tx) => "TX",
        @intFromEnum(MessageType.getpeers) => "GETPEERS",
        @intFromEnum(MessageType.peers) => "PEERS",
        @intFromEnum(MessageType.reject) => "REJECT",
        else => "UNKNOWN",
    };
}
pub fn main() !void {
    std.debug.print("\n=== Lesson 9.3: Protocol Message Framing ===\n\n", .{});
    var wire_buffer: [4096]u8 = undefined;
    // ---------------------------------------------------------
    // STEP 1: Encode a VERSION message
    // ---------------------------------------------------------
    std.debug.print("  --- Encode Messages ---\n\n", .{});
    var ua: [32]u8 = .{0} ** 32;
    @memcpy(ua[0..15], "sacrium-node/1.");
    const version_msg = VersionPayload{
        .node_id = 42,
        .block_height = 15001,
        .timestamp = @intCast(std.time.timestamp()),
        .user_agent = ua,
    };
    const ver_len = try ProtocolEncoder.encode(VersionPayload, .version, &version_msg, &wire_buffer);
    std.debug.print("    VERSION: {d} bytes (header={d} + payload={d})\n", .{
        ver_len, @sizeOf(MessageHeader), @sizeOf(VersionPayload),
    });
    // Encode PING
    const ping_msg = PingPayload{
        .nonce = 0xDEADBEEF,
        .timestamp = @intCast(std.time.timestamp()),
    };
    const ping_len = try ProtocolEncoder.encode(PingPayload, .ping, &ping_msg, wire_buffer[ver_len..]);
    std.debug.print("    PING:    {d} bytes\n", .{ping_len});
    // Encode TX
    const tx_msg = TxPayload{
        .sender = 1,
        .receiver = 2,
        .amount = 50000,
        .fee = 100,
        .nonce_val = 0,
        .signature = .{0xAB} ** 64,
    };
    const tx_len = try ProtocolEncoder.encode(TxPayload, .tx, &tx_msg, wire_buffer[ver_len + ping_len ..]);
    std.debug.print("    TX:      {d} bytes\n", .{tx_len});
    // Encode VERACK (no payload)
    const verack_len = try ProtocolEncoder.encodeEmpty(.verack, wire_buffer[ver_len + ping_len + tx_len ..]);
    std.debug.print("    VERACK:  {d} bytes (header only, no payload)\n", .{verack_len});
    const total_wire = ver_len + ping_len + tx_len + verack_len;
    std.debug.print("\n    Total wire data: {d} bytes\n", .{total_wire});
    // ---------------------------------------------------------
    // STEP 2: Decode messages from the wire buffer
    // ---------------------------------------------------------
    std.debug.print("\n  --- Decode Messages ---\n\n", .{});
    var offset: usize = 0;
    var msg_num: u32 = 0;
    while (offset < total_wire) {
        msg_num += 1;
        const remaining = wire_buffer[offset..total_wire];
        const decoded = ProtocolDecoder.decode(remaining) catch |err| {
            std.debug.print("    [{d}] Decode error: {s}\n", .{ msg_num, @errorName(err) });
            break;
        };
        const checkmark = if (decoded.checksum_valid) "✅" else "❌";
        std.debug.print("    [{d}] {s} {s} — payload={d} bytes\n", .{
            msg_num, msgTypeName(decoded.msg_type), checkmark, decoded.payload.len,
        });
        // Decode payload based on type
        switch (decoded.msg_type) {
            @intFromEnum(MessageType.version) => {
                const ver = try ProtocolDecoder.castPayload(VersionPayload, decoded.payload);
                // Find actual agent length
                var agent_len: usize = 0;
                for (ver.user_agent) |c| {
                    if (c == 0) break;
                    agent_len += 1;
                }
                std.debug.print("        node_id={d} height={d} agent=\"{s}\"\n", .{
                    ver.node_id, ver.block_height, ver.user_agent[0..agent_len],
                });
            },
            @intFromEnum(MessageType.ping) => {
                const p = try ProtocolDecoder.castPayload(PingPayload, decoded.payload);
                std.debug.print("        nonce=0x{x:0>8}\n", .{p.nonce});
            },
            @intFromEnum(MessageType.tx) => {
                const tx = try ProtocolDecoder.castPayload(TxPayload, decoded.payload);
                std.debug.print("        {d}→{d} amount={d} fee={d}\n", .{
                    tx.sender, tx.receiver, tx.amount, tx.fee,
                });
            },
            @intFromEnum(MessageType.verack) => {
                std.debug.print("        (handshake acknowledged)\n", .{});
            },
            else => {},
        }
        // Advance past this message
        const header: *const MessageHeader = @ptrCast(@alignCast(remaining.ptr));
        offset += @sizeOf(MessageHeader) + header.payload_length;
    }
    // ---------------------------------------------------------
    // STEP 3: Tamper detection
    // ---------------------------------------------------------
    std.debug.print("\n  --- Tamper Detection ---\n\n", .{});
    {
        // Corrupt one byte in the VERSION payload
        var tampered = wire_buffer;
        tampered[@sizeOf(MessageHeader) + 5] ^= 0xFF; // flip a byte
        const decoded = try ProtocolDecoder.decode(&tampered);
        std.debug.print("    Tampered VERSION: checksum_valid={}\n", .{decoded.checksum_valid});
        if (!decoded.checksum_valid) {
            std.debug.print("    ✅ Corruption detected! Message rejected.\n", .{});
        }
    }
    // ---------------------------------------------------------
    // Message size summary
    // ---------------------------------------------------------
    std.debug.print("\n  --- Message Sizes ---\n\n", .{});
    std.debug.print("    ┌──────────────┬────────┬─────────┬────────┐\n", .{});
    std.debug.print("    │ Message      │ Header │ Payload │ Total  │\n", .{});
    std.debug.print("    ├──────────────┼────────┼─────────┼────────┤\n", .{});
    std.debug.print("    │ VERSION      │ {d:>4}   │ {d:>5}   │ {d:>4}   │\n", .{ @sizeOf(MessageHeader), @sizeOf(VersionPayload), @sizeOf(MessageHeader) + @sizeOf(VersionPayload) });
    std.debug.print("    │ PING/PONG    │ {d:>4}   │ {d:>5}   │ {d:>4}   │\n", .{ @sizeOf(MessageHeader), @sizeOf(PingPayload), @sizeOf(MessageHeader) + @sizeOf(PingPayload) });
    std.debug.print("    │ TX           │ {d:>4}   │ {d:>5}   │ {d:>4}   │\n", .{ @sizeOf(MessageHeader), @sizeOf(TxPayload), @sizeOf(MessageHeader) + @sizeOf(TxPayload) });
    std.debug.print("    │ GETBLOCKS    │ {d:>4}   │ {d:>5}   │ {d:>4}   │\n", .{ @sizeOf(MessageHeader), @sizeOf(GetBlocksPayload), @sizeOf(MessageHeader) + @sizeOf(GetBlocksPayload) });
    std.debug.print("    │ VERACK       │ {d:>4}   │     0   │ {d:>4}   │\n", .{ @sizeOf(MessageHeader), @sizeOf(MessageHeader) });
    std.debug.print("    └──────────────┴────────┴─────────┴────────┘\n", .{});
    std.debug.print("\n✅ Protocol framing mastered!\n\n", .{});
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. Wire format: [MAGIC][TYPE][LENGTH][PAYLOAD][CHECKSUM]
// 2. MAGIC bytes identify your protocol (reject foreign data)
// 3. LENGTH field tells receiver how many bytes to read
// 4. CRC32 checksum detects corruption on the wire
// 5. Decoder validates magic, checksum, and payload size
// 6. @ptrCast to interpret raw bytes as typed structs
//
// 🔬 EXPERIMENT:
//   - Add a BLOCK message type with BlockHeader payload
//   - Implement message compression (zlib on payload)
//   - Add encryption (ChaCha20 on payload before checksum)
//   - Send these framed messages over the TCP socket from Ex.1
// ============================================================
