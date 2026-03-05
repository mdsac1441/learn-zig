const std = @import("std");
// ============================================================
// EXERCISE 1: Pointer Basics — *T, *const T, Dereferencing
// ============================================================
// In Zig, pointers are EXPLICIT. A function that modifies data
// must take `*T` (mutable pointer). A function that only reads
// takes `*const T`.
//
// YOUR BLOCKCHAIN USE CASE:
//   When your consensus engine wants to update a block's nonce
//   for mining, it takes *BlockHeader. When it only reads the
//   block to verify, it takes *const BlockHeader.
// ============================================================
const BlockHeader = struct {
    version: u32,
    prev_hash: [32]u8,
    timestamp: u64,
    difficulty: u32,
    nonce: u64,
    tx_count: u32,
    fn init(version: u32, timestamp: u64, difficulty: u32) BlockHeader {
        var h: BlockHeader = undefined;
        h.version = version;
        @memset(&h.prev_hash, 0xAA);
        h.timestamp = timestamp;
        h.difficulty = difficulty;
        h.nonce = 0;
        h.tx_count = 0;
        return h;
    }
};
// ---------------------------------------------------------
// Takes a MUTABLE pointer — can modify the block
// ---------------------------------------------------------
fn incrementNonce(header: *BlockHeader) void {
    header.nonce += 1;
}
// ---------------------------------------------------------
// Takes a CONST pointer — read-only access
// ---------------------------------------------------------
fn displayHeader(header: *const BlockHeader) void {
    std.debug.print("    version={d} nonce={d} difficulty={d} timestamp={d} txs={d}\n", .{
        header.version,
        header.nonce,
        header.difficulty,
        header.timestamp,
        header.tx_count,
    });
}
// ---------------------------------------------------------
// Takes a mutable pointer to update transaction count
// ---------------------------------------------------------
fn addTransactions(header: *BlockHeader, count: u32) void {
    header.tx_count += count;
}
pub fn main() !void {
    std.debug.print("\n=== Lesson 3.1: Pointer Basics ===\n\n", .{});
    // ---------------------------------------------------------
    // STEP 1: Creating pointers with & (address-of)
    // ---------------------------------------------------------
    var header = BlockHeader.init(1, 1708900000, 20);
    // `&header` gives you a *BlockHeader (mutable pointer)
    const header_ptr: *BlockHeader = &header;
    // `&header` for const gives *const BlockHeader
    const header_const_ptr: *const BlockHeader = &header;
    std.debug.print("  Initial state:\n", .{});
    displayHeader(header_const_ptr);
    // ---------------------------------------------------------
    // STEP 2: Mutating through pointers
    // ---------------------------------------------------------
    std.debug.print("\n  Mining (incrementing nonce 5 times):\n", .{});
    for (0..5) |_| {
        incrementNonce(header_ptr);
    }
    displayHeader(&header);
    // ---------------------------------------------------------
    // STEP 3: Dereferencing with .*
    // ---------------------------------------------------------
    std.debug.print("\n  Dereferencing:\n", .{});
    const nonce_value = header_ptr.nonce; // auto-deref for field access
    const full_copy = header_ptr.*; // explicit deref = full copy
    std.debug.print("    nonce via ptr: {d}\n", .{nonce_value});
    std.debug.print("    full copy nonce: {d}\n", .{full_copy.nonce});
    // Modify original — copy is NOT affected
    incrementNonce(header_ptr);
    std.debug.print("    original nonce after +1: {d}\n", .{header_ptr.nonce});
    std.debug.print("    copy nonce (unchanged):  {d}\n", .{full_copy.nonce});
    std.debug.print("    auto-deref (unchanged):  {d}\n", .{nonce_value});
    // ---------------------------------------------------------
    // STEP 4: Pointer to individual fields
    // ---------------------------------------------------------
    std.debug.print("\n  Field pointers:\n", .{});
    const nonce_ptr: *u64 = &header.nonce;
    nonce_ptr.* = 999;
    std.debug.print("    Set nonce via field ptr: {d}\n", .{header.nonce});
    // ---------------------------------------------------------
    // STEP 5: Why Zig prevents pointer arithmetic
    // ---------------------------------------------------------
    std.debug.print("\n  Pointer safety:\n", .{});
    std.debug.print("    Zig does NOT allow: ptr + 1 (pointer arithmetic)\n", .{});
    std.debug.print("    Use slices [] instead — they carry length!\n", .{});
    std.debug.print("    This prevents buffer overflows in your blockchain.\n", .{});
    // ---------------------------------------------------------
    // STEP 6: Passing by value vs pointer
    // ---------------------------------------------------------
    std.debug.print("\n  Pass by value vs pointer:\n", .{});
    addTransactions(&header, 10);
    std.debug.print("    After addTransactions(&header, 10): tx_count={d}\n", .{header.tx_count});
    // This would NOT work — Zig structs > 16 bytes are not
    // passed by pointer automatically. You must be explicit.
    // addTransactions(header, 10); // COMPILE ERROR
    std.debug.print("\n✅ Pointer basics complete!\n\n", .{});
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. `*T` = mutable pointer, `*const T` = read-only pointer
// 2. `&x` takes the address, `.* ` dereferences
// 3. Field access auto-derefs: `ptr.field` = `ptr.*.field`
// 4. No pointer arithmetic in Zig — use slices instead
// 5. Large structs must be explicitly passed as `*T`
//
// 🔬 EXPERIMENT:
//   - Try passing `header` (by value) to incrementNonce
//     → See the compile error
//   - Make displayHeader take `BlockHeader` (by value)
//     → It works but copies the entire struct!
// ============================================================

// zig run src/lesson2/01_page_allocator.zig -O ReleaseFast
