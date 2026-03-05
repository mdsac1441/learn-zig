const std = @import("std");
// ============================================================
// EXERCISE 3: Sentinel-Terminated Arrays — C Interop Prep
// ============================================================
// C strings end with '\0' (null terminator). Zig has first-class
// support for sentinel-terminated types: [N:S]T, [*:S]T, [:S]T.
//
// YOUR BLOCKCHAIN USE CASE:
//   When you call C crypto libraries (OpenSSL, libsodium) in
//   Lesson 6, you'll pass data as C strings and raw buffers.
//   Understanding sentinel types is essential for safe FFI.
// ============================================================
/// Simulates a C library function that expects a null-terminated string
fn c_log_message(msg: [*:0]const u8) void {
    // C-style: walk until null terminator
    var i: usize = 0;
    while (msg[i] != 0) : (i += 1) {}
    std.debug.print("    [C_LOG] ({d} bytes): {s}\n", .{ i, msg[0..i] });
}
pub fn main() !void {
    std.debug.print("\n=== Lesson 3.3: Sentinel-Terminated Arrays ===\n\n", .{});
    // ---------------------------------------------------------
    // STEP 1: String literals are sentinel-terminated
    // ---------------------------------------------------------
    std.debug.print("  --- String Literals ---\n", .{});
    // String literal type is *const [N:0]u8
    // It coerces to both []const u8 AND [*:0]const u8
    const node_name = "sacrium-mainnet-01";
    // Use as a Zig slice (carries length)
    const as_slice: []const u8 = node_name;
    std.debug.print("    Zig slice: \"{s}\" (len={d})\n", .{ as_slice, as_slice.len });
    // Use as a C string (null-terminated pointer)
    const as_cstr: [*:0]const u8 = node_name;
    c_log_message(as_cstr);
    // ---------------------------------------------------------
    // STEP 2: Sentinel-terminated arrays
    // ---------------------------------------------------------
    std.debug.print("\n  --- Sentinel Arrays ---\n", .{});
    // [5:0]u8 = array of 5 u8s, terminated with 0
    const chain_id: [5:0]u8 = .{ 's', 'c', 'r', 'm', '1' };
    std.debug.print("    chain_id: \"{s}\"\n", .{@as([]const u8, &chain_id)});
    std.debug.print("    chain_id length: {d} (not counting sentinel)\n", .{chain_id.len});
    std.debug.print("    sentinel value: {d} (the hidden null byte)\n", .{chain_id[chain_id.len]});
    // Can be passed to C functions directly
    c_log_message(&chain_id);
    // ---------------------------------------------------------
    // STEP 3: Converting between Zig slices and C strings
    // ---------------------------------------------------------
    std.debug.print("\n  --- Conversion ---\n", .{});
    // Zig slice → C string: only works if the slice IS sentinel-terminated
    const genesis_msg: [:0]const u8 = "Genesis Block v1.0";
    const c_genesis: [*:0]const u8 = genesis_msg.ptr;
    c_log_message(c_genesis);
    // C string → Zig slice: use std.mem.span
    const c_str: [*:0]const u8 = "peer://192.168.1.1:8333";
    const zig_slice = std.mem.span(c_str);
    std.debug.print("    C string as Zig slice: \"{s}\" (len={d})\n", .{ zig_slice, zig_slice.len });
    // ---------------------------------------------------------
    // STEP 4: Building C-compatible buffers for FFI
    // ---------------------------------------------------------
    std.debug.print("\n  --- C-Compatible Buffers ---\n", .{});
    // Simulate building a protocol message for a C networking lib
    var msg_buf: [256:0]u8 = .{0} ** 256;
    const prefix = "BLOCK:";
    const hash_hex = "a1b2c3d4e5f6";
    // Copy into buffer
    @memcpy(msg_buf[0..prefix.len], prefix);
    @memcpy(msg_buf[prefix.len..][0..hash_hex.len], hash_hex);
    // Already null-terminated because we zero-initialized!
    const msg_slice = std.mem.span(@as([*:0]const u8, &msg_buf));
    std.debug.print("    Protocol message: \"{s}\" (len={d})\n", .{ msg_slice, msg_slice.len });
    c_log_message(&msg_buf);
    // ---------------------------------------------------------
    // STEP 5: Sentinel slices from runtime data
    // ---------------------------------------------------------
    std.debug.print("\n  --- Runtime Sentinel Slices ---\n", .{});
    const data = [_]u8{ 'h', 'e', 'l', 'l', 'o', 0, 'w', 'o', 'r', 'l', 'd' };
    // Find the sentinel (0) and create a sentinel-terminated slice
    if (std.mem.indexOfScalar(u8, &data, 0)) |sentinel_pos| {
        const until_null = data[0..sentinel_pos];
        std.debug.print("    Data until null: \"{s}\" (len={d})\n", .{ until_null, until_null.len });
        std.debug.print("    Full data length: {d}\n", .{data.len});
    }
    // ---------------------------------------------------------
    // STEP 6: Why this matters for your blockchain
    // ---------------------------------------------------------
    std.debug.print("\n  --- Blockchain FFI Preview ---\n", .{});
    std.debug.print("    In Lesson 6, you'll do this:\n", .{});
    std.debug.print("    \n", .{});
    std.debug.print("      // Zig calling C's SHA256 function:\n", .{});
    std.debug.print("      // extern fn SHA256(data: [*]const u8, len: c_ulong, out: [*]u8) [*]u8;\n", .{});
    std.debug.print("      // const hash = SHA256(block_bytes.ptr, block_bytes.len, &output);\n", .{});
    std.debug.print("    \n", .{});
    std.debug.print("    Slice.ptr gives you the [*]T that C expects!\n", .{});
    std.debug.print("    Slice.len gives you the length C needs!\n", .{});
    std.debug.print("\n✅ Sentinel-terminated arrays mastered!\n\n", .{});
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. [N:0]u8 = fixed array with null terminator (C-compatible)
// 2. [*:0]const u8 = C string pointer type
// 3. [:0]const u8 = Zig sentinel-terminated slice (length + null)
// 4. std.mem.span() converts C string → Zig slice
// 5. .ptr extracts raw pointer from any slice (for C FFI)
// 6. String literals are BOTH []const u8 AND [*:0]const u8
//
// 🔬 EXPERIMENT:
//   - Create a [*:0]u8 buffer and pass it to c_log_message
//   - Try forgetting the null terminator — what happens?
//   - Use @ptrCast to convert between pointer types
// ============================================================
