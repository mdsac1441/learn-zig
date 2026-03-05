const std = @import("std");
const c = @cImport({
    @cInclude("string.h");
});
// ============================================================
// EXERCISE 2: C-Compatible Struct Layouts — extern struct
// ============================================================
// When passing structs to C functions, the memory layout must
// match C's rules. Zig's default struct layout is OPTIMIZED
// (fields may be reordered). `extern struct` forces C layout.
//
// YOUR BLOCKCHAIN USE CASE:
//   - Wire protocol structs must have deterministic byte layout
//   - C crypto libs expect specific struct alignment
//   - Embedded hardware may require packed structs
// ============================================================
// ---------------------------------------------------------
// STEP 1: extern struct — C-compatible layout
// ---------------------------------------------------------
/// C-compatible block header for wire protocol
/// `extern` means: fields are laid out EXACTLY as written,
/// with C alignment rules. No reordering, no Zig optimizations.
const WireBlockHeader = extern struct {
    version: u32, // 4 bytes, offset 0
    _pad1: u32 = 0, // 4 bytes padding for alignment
    height: u64, // 8 bytes, offset 8
    timestamp: u64, // 8 bytes, offset 16
    prev_hash: [32]u8, // 32 bytes, offset 24
    merkle_root: [32]u8, // 32 bytes, offset 56
    difficulty: u32, // 4 bytes, offset 88
    nonce_value: u32, // 4 bytes, offset 92 (renamed to avoid keyword)
};
/// Zig's default struct layout — fields may be reordered!
const ZigBlockHeader = struct {
    version: u32,
    height: u64,
    timestamp: u64,
    prev_hash: [32]u8,
    merkle_root: [32]u8,
    difficulty: u32,
    nonce_value: u32,
};
// ---------------------------------------------------------
// STEP 2: packed struct — exact bit layout, no padding
// ---------------------------------------------------------
/// Packed transaction header — every bit is accounted for.
/// Used for compact wire format (no padding bytes).
const PackedTxFlags = packed struct {
    tx_type: u4, // 4 bits: 0=transfer, 1=stake, 2=unstake, ...
    priority: u2, // 2 bits: 0=low, 1=med, 2=high, 3=urgent
    has_memo: bool, // 1 bit
    is_contract: bool, // 1 bit
    // Total: exactly 1 byte (8 bits)
};
const PackedTxHeader = packed struct {
    flags: PackedTxFlags, // 1 byte
    sender_id: u16, // 2 bytes
    receiver_id: u16, // 2 bytes
    amount: u32, // 4 bytes
    nonce_val: u16, // 2 bytes
    fee: u8, // 1 byte
    // Total: exactly 12 bytes, no gaps
};
// ---------------------------------------------------------
// STEP 3: Simulated C function that expects extern struct
// ---------------------------------------------------------
/// Simulates a C library function that processes a block header.
/// In real code, this would be an `extern "c" fn` from a C lib.
fn c_process_header(header_ptr: *const WireBlockHeader, size: usize) void {
    std.debug.print("    [C_LIB] Received header: {d} bytes\n", .{size});
    std.debug.print("    [C_LIB] version={d} height={d} difficulty={d}\n", .{
        header_ptr.version,
        header_ptr.height,
        header_ptr.difficulty,
    });
    // Use C's memcmp to verify hash
    const zeros: [32]u8 = .{0} ** 32;
    const is_genesis = c.memcmp(&header_ptr.prev_hash, &zeros, 32) == 0;
    if (is_genesis) {
        std.debug.print("    [C_LIB] This is the GENESIS block\n", .{});
    }
}
/// Simulates a C serialization function
fn c_serialize_to_buffer(src: *const anyopaque, dst: [*]u8, size: usize) void {
    _ = c.memcpy(dst, src, size);
}
pub fn main() !void {
    std.debug.print("\n=== Lesson 6.2: C-Compatible Struct Layouts ===\n\n", .{});
    // ---------------------------------------------------------
    // Size comparison: extern vs Zig layout
    // ---------------------------------------------------------
    std.debug.print("  --- Layout Comparison ---\n", .{});
    std.debug.print("    WireBlockHeader (extern): {d} bytes\n", .{@sizeOf(WireBlockHeader)});
    std.debug.print("    ZigBlockHeader (default): {d} bytes\n", .{@sizeOf(ZigBlockHeader)});
    std.debug.print("    PackedTxFlags:            {d} byte(s)\n", .{@sizeOf(PackedTxFlags)});
    std.debug.print("    PackedTxHeader:           {d} bytes\n", .{@sizeOf(PackedTxHeader)});
    // ---------------------------------------------------------
    // Field offsets (critical for wire protocol!)
    // ---------------------------------------------------------
    std.debug.print("\n  --- extern struct Field Offsets ---\n", .{});
    std.debug.print("    version:     offset {d}, size {d}\n", .{ @offsetOf(WireBlockHeader, "version"), @sizeOf(u32) });
    std.debug.print("    height:      offset {d}, size {d}\n", .{ @offsetOf(WireBlockHeader, "height"), @sizeOf(u64) });
    std.debug.print("    timestamp:   offset {d}, size {d}\n", .{ @offsetOf(WireBlockHeader, "timestamp"), @sizeOf(u64) });
    std.debug.print("    prev_hash:   offset {d}, size {d}\n", .{ @offsetOf(WireBlockHeader, "prev_hash"), 32 });
    std.debug.print("    merkle_root: offset {d}, size {d}\n", .{ @offsetOf(WireBlockHeader, "merkle_root"), 32 });
    std.debug.print("    difficulty:  offset {d}, size {d}\n", .{ @offsetOf(WireBlockHeader, "difficulty"), @sizeOf(u32) });
    std.debug.print("    nonce_value: offset {d}, size {d}\n", .{ @offsetOf(WireBlockHeader, "nonce_value"), @sizeOf(u32) });
    // ---------------------------------------------------------
    // Create and pass to "C" function
    // ---------------------------------------------------------
    std.debug.print("\n  --- Passing extern struct to C ---\n", .{});
    var header = WireBlockHeader{
        .version = 1,
        .height = 0,
        .timestamp = 1708900000,
        .prev_hash = .{0} ** 32, // genesis
        .merkle_root = .{0xCD} ** 32,
        .difficulty = 24,
        .nonce_value = 0,
    };
    c_process_header(&header, @sizeOf(WireBlockHeader));
    // ---------------------------------------------------------
    // Serialize to raw bytes (wire format)
    // ---------------------------------------------------------
    std.debug.print("\n  --- Wire Serialization ---\n", .{});
    var wire_buffer: [256]u8 = undefined;
    c_serialize_to_buffer(&header, &wire_buffer, @sizeOf(WireBlockHeader));
    std.debug.print("    Serialized {d} bytes to wire buffer\n", .{@sizeOf(WireBlockHeader)});
    std.debug.print("    First 16 bytes: ", .{});
    for (wire_buffer[0..16]) |byte| std.debug.print("{x:0>2} ", .{byte});
    std.debug.print("\n", .{});
    // Deserialize: cast raw bytes back to struct
    const deserialized: *const WireBlockHeader = @ptrCast(@alignCast(&wire_buffer));
    std.debug.print("    Deserialized: version={d} height={d}\n", .{
        deserialized.version,
        deserialized.height,
    });
    // Verify round-trip
    const match = c.memcmp(&header, deserialized, @sizeOf(WireBlockHeader)) == 0;
    std.debug.print("    Round-trip match: {s}\n", .{if (match) "✅ YES" else "❌ NO"});
    // ---------------------------------------------------------
    // Packed struct demo
    // ---------------------------------------------------------
    std.debug.print("\n  --- Packed Struct (Compact Wire Format) ---\n", .{});
    const flags = PackedTxFlags{
        .tx_type = 1, // stake
        .priority = 3, // urgent
        .has_memo = true,
        .is_contract = false,
    };
    const tx_header = PackedTxHeader{
        .flags = flags,
        .sender_id = 42,
        .receiver_id = 99,
        .amount = 50000,
        .nonce_val = 7,
        .fee = 25,
    };
    std.debug.print("    TX flags: type={d} priority={d} memo={} contract={}\n", .{
        flags.tx_type,
        flags.priority,
        flags.has_memo,
        flags.is_contract,
    });
    const flags_byte: u8 = @bitCast(flags);
    std.debug.print("    Flags as byte: 0x{x:0>2} (all 4 fields in 1 byte!)\n", .{flags_byte});
    // Serialize packed struct
    const tx_bytes: [*]const u8 = @ptrCast(&tx_header);
    std.debug.print("    TX header bytes: ", .{});
    for (tx_bytes[0..@sizeOf(PackedTxHeader)]) |byte| {
        std.debug.print("{x:0>2} ", .{byte});
    }
    std.debug.print("\n    ({d} bytes — zero waste!)\n", .{@sizeOf(PackedTxHeader)});
    // ---------------------------------------------------------
    // Alignment matters!
    // ---------------------------------------------------------
    std.debug.print("\n  --- Alignment ---\n", .{});
    std.debug.print("    WireBlockHeader align: {d} bytes\n", .{@alignOf(WireBlockHeader)});
    std.debug.print("    PackedTxHeader align:  {d} byte(s)\n", .{@alignOf(PackedTxHeader)});
    std.debug.print("    u64 align: {d} bytes (why we have _pad1)\n", .{@alignOf(u64)});
    std.debug.print("\n✅ C-compatible structs mastered!\n\n", .{});
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. `extern struct` = C memory layout (no reordering, C padding)
// 2. `packed struct` = exact bit layout, no padding at all
// 3. @offsetOf(T, "field") = verify wire protocol field positions
// 4. @ptrCast + @alignCast = cast raw bytes ↔ typed struct
// 5. @bitCast(flags) = convert packed flags to a single byte
// 6. Use extern for C interop, packed for compact wire format
//
// 🔬 EXPERIMENT:
//   - Remove _pad1 from WireBlockHeader — see offset changes
//   - Add a bool field to the packed struct — see it uses 1 BIT
//   - Change field order in extern struct — offsets change too
//   - Compare @sizeOf with manual calculation for packed structs
// ============================================================
