const std = @import("std");
// ============================================================
// EXERCISE 2: FixedBufferAllocator — Zero Heap, Stack Only
// ============================================================
// FixedBufferAllocator uses a PRE-ALLOCATED buffer (stack or
// static) — it never touches the heap or calls the OS.
//
// YOUR BLOCKCHAIN USE CASE:
//   When hashing a block header or verifying a signature,
//   you need small temp buffers. You KNOW the max size.
//   Using FixedBuffer = zero syscalls = blazing fast.
//   Perfect for hot paths in consensus and validation.
// ============================================================
const BlockHeader = struct {
    version: u32,
    prev_hash: [32]u8,
    merkle_root: [32]u8,
    timestamp: u64,
    difficulty: u32,
    nonce: u64,
    fn init(version: u32, timestamp: u64, difficulty: u32, nonce: u64) BlockHeader {
        var header: BlockHeader = undefined;
        header.version = version;
        @memset(&header.prev_hash, 0xAB);
        @memset(&header.merkle_root, 0xCD);
        header.timestamp = timestamp;
        header.difficulty = difficulty;
        header.nonce = nonce;
        return header;
    }
    /// Serialize the block header into raw bytes for hashing
    fn toBytes(self: *const BlockHeader) []const u8 {
        const ptr: [*]const u8 = @ptrCast(self);
        return ptr[0..@sizeOf(BlockHeader)];
    }
};
pub fn main() !void {
    std.debug.print("\n=== Lesson 2.2: FixedBufferAllocator — Stack-Only Allocation ===\n\n", .{});
    // ---------------------------------------------------------
    // STEP 1: Create a stack-based buffer
    // ---------------------------------------------------------
    // This 1KB buffer lives on the STACK — no heap involved.
    var buffer: [1024]u8 = undefined;
    // Wrap it in a FixedBufferAllocator
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();
    // ---------------------------------------------------------
    // STEP 2: Allocate from the fixed buffer
    // ---------------------------------------------------------
    // Allocate space for a formatted string (like sprintf)
    const label = try allocator.alloc(u8, 64);
    @memcpy(label[0..12], "Block #1337");
    label[12] = 0; // null terminate for display
    std.debug.print("  Label: {s}\n", .{label[0..12]});
    std.debug.print("  Buffer used so far: ~{d} bytes\n", .{fba.end_index});
    // ---------------------------------------------------------
    // STEP 3: Use it for block header serialization
    // ---------------------------------------------------------
    const header = BlockHeader.init(1, 1708900000, 24, 0xDEADBEEF);
    const raw_bytes = header.toBytes();
    // Allocate space to store hash input (header bytes + extra)
    const hash_input = try allocator.alloc(u8, raw_bytes.len);
    @memcpy(hash_input, raw_bytes);
    std.debug.print("\n  Block Header Serialized: {d} bytes\n", .{raw_bytes.len});
    std.debug.print("  First 8 bytes: ", .{});
    for (raw_bytes[0..8]) |byte| {
        std.debug.print("{x:0>2} ", .{byte});
    }
    std.debug.print("\n", .{});
    // ---------------------------------------------------------
    // STEP 4: Hash the header using SHA-256
    // ---------------------------------------------------------
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(hash_input, &hash, .{});
    std.debug.print("\n  SHA-256 Hash: ", .{});
    for (hash) |byte| {
        std.debug.print("{x:0>2}", .{byte});
    }
    std.debug.print("\n", .{});
    // ---------------------------------------------------------
    // STEP 5: Check difficulty (leading zeros)
    // ---------------------------------------------------------
    var leading_zeros: u32 = 0;
    for (hash) |byte| {
        if (byte == 0) {
            leading_zeros += 8;
        } else {
            // Count leading zero bits in this byte
            leading_zeros += @clz(byte);
            break;
        }
    }
    std.debug.print("  Leading zero bits: {d}\n", .{leading_zeros});
    std.debug.print("  Difficulty target:  {d}\n", .{header.difficulty});
    if (leading_zeros >= header.difficulty) {
        std.debug.print("  ✅ Block meets difficulty!\n", .{});
    } else {
        std.debug.print("  ❌ Block does NOT meet difficulty (need more mining)\n", .{});
    }
    // ---------------------------------------------------------
    // STEP 6: Show buffer usage
    // ---------------------------------------------------------
    std.debug.print("\n  --- Buffer Stats ---\n", .{});
    std.debug.print("  Total buffer size:  {d} bytes\n", .{buffer.len});
    std.debug.print("  Used:               {d} bytes\n", .{fba.end_index});
    std.debug.print("  Remaining:          {d} bytes\n", .{buffer.len - fba.end_index});
    // ---------------------------------------------------------
    // STEP 7: What happens when the buffer runs out?
    // ---------------------------------------------------------
    std.debug.print("\n  --- Overflow Demo ---\n", .{});
    // Reset the allocator to reuse the buffer
    fba.reset();
    std.debug.print("  After reset, used: {d} bytes\n", .{fba.end_index});
    // Try to allocate more than the buffer can hold
    const big_alloc = allocator.alloc(u8, 2048);
    if (big_alloc) |_| {
        std.debug.print("  Allocated 2048 bytes (unexpected!)\n", .{});
    } else |_| {
        std.debug.print("  ⚠️  Allocation of 2048 bytes FAILED (buffer is only 1024)\n", .{});
        std.debug.print("  This is GOOD — no silent heap fallback!\n", .{});
    }
    std.debug.print("\n✅ Zero heap allocations were made!\n\n", .{});
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. FixedBufferAllocator = stack memory, zero syscalls
// 2. Perfect for hashing, signature checks, serialization
// 3. .reset() lets you reuse the buffer for the next block
// 4. If you run out of buffer → error, NOT silent heap usage
// 5. This is how you build a GAS-efficient blockchain VM
//
// 🔬 EXPERIMENT:
//   - Change buffer size to 64 bytes — watch allocations fail
//   - Remove the .reset() and keep allocating — see it fill up
//   - Time this vs page_allocator — notice the speed difference
// ============================================================
