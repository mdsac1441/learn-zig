const std = @import("std");
// ============================================================
// EXERCISE 2: Slices — The Safe Way to Handle Data
// ============================================================
// A slice `[]T` is a (pointer, length) pair. Unlike C arrays,
// slices KNOW their size and are bounds-checked in Debug mode.
//
// YOUR BLOCKCHAIN USE CASE:
//   Transaction data comes in as `[]const u8` (byte slices).
//   You slice into fields, parse them, validate them.
//   `[]const u8` is Zig's string type — no special String class.
// ============================================================
const Transaction = struct {
    sender: [32]u8,
    receiver: [32]u8,
    amount: u64,
    fee: u64,
    memo: []const u8, // variable-length! stored as a slice
    fn display(self: *const Transaction, idx: usize) void {
        std.debug.print("    [{d}] sender=0x{x:0>2}... amount={d} fee={d} memo=\"{s}\"\n", .{
            idx,
            self.sender[0],
            self.amount,
            self.fee,
            self.memo,
        });
    }
};
/// Accepts a SLICE of transactions — works for any length
fn totalFees(txns: []const Transaction) u64 {
    var total: u64 = 0;
    for (txns) |tx| {
        total += tx.fee;
    }
    return total;
}
/// Returns a sub-slice of high-value transactions
fn filterHighValue(txns: []const Transaction, min_amount: u64) []const Transaction {
    // Find the count first
    var count: usize = 0;
    for (txns) |tx| {
        if (tx.amount >= min_amount) count += 1;
    }
    // In real code you'd allocate — here we just return the
    // original slice to demonstrate slice semantics.
    // We'll show sub-slicing instead:
    std.debug.print("    High-value txns (>= {d}): {d}\n", .{ min_amount, count });
    return txns; // simplified for this exercise
}
pub fn main() !void {
    std.debug.print("\n=== Lesson 3.2: Slices — Safe Data Handling ===\n\n", .{});
    // ---------------------------------------------------------
    // STEP 1: Array to Slice
    // ---------------------------------------------------------
    std.debug.print("  --- Array to Slice ---\n", .{});
    var block_hashes: [5][32]u8 = undefined;
    for (&block_hashes, 0..) |*hash, i| {
        @memset(hash, @intCast(i + 1));
    }
    // Array → Slice: just take address with &
    const hash_slice: []const [32]u8 = &block_hashes;
    std.debug.print("    Array length: {d}\n", .{block_hashes.len});
    std.debug.print("    Slice length: {d}\n", .{hash_slice.len});
    std.debug.print("    First hash[0]: 0x{x:0>2}\n", .{hash_slice[0][0]});
    // ---------------------------------------------------------
    // STEP 2: Sub-slicing (getting a window into data)
    // ---------------------------------------------------------
    std.debug.print("\n  --- Sub-slicing ---\n", .{});
    // Get hashes 1..3 (indices 1, 2 — exclusive end)
    const middle = hash_slice[1..3];
    std.debug.print("    middle slice length: {d}\n", .{middle.len});
    std.debug.print("    middle[0][0]: 0x{x:0>2} (was index 1)\n", .{middle[0][0]});
    std.debug.print("    middle[1][0]: 0x{x:0>2} (was index 2)\n", .{middle[1][0]});
    // Open-ended slice (from index 3 to end)
    const tail = hash_slice[3..];
    std.debug.print("    tail length: {d} (from index 3 to end)\n", .{tail.len});
    // ---------------------------------------------------------
    // STEP 3: Byte slices = strings in Zig
    // ---------------------------------------------------------
    std.debug.print("\n  --- Byte Slices as Strings ---\n", .{});
    const block_id: []const u8 = "block_00000137";
    std.debug.print("    Block ID: \"{s}\"\n", .{block_id});
    std.debug.print("    Length: {d} bytes\n", .{block_id.len});
    std.debug.print("    First char: '{c}' (0x{x:0>2})\n", .{ block_id[0], block_id[0] });
    // Sub-slice a string
    const just_number = block_id[6..]; // "00000137"
    std.debug.print("    Block number: \"{s}\"\n", .{just_number});
    // ---------------------------------------------------------
    // STEP 4: Slices in structs
    // ---------------------------------------------------------
    std.debug.print("\n  --- Slices in Structs ---\n", .{});
    const txns = [_]Transaction{
        .{ .sender = [_]u8{0x01} ** 32, .receiver = [_]u8{0x02} ** 32, .amount = 5000, .fee = 50, .memo = "payment for server" },
        .{ .sender = [_]u8{0x03} ** 32, .receiver = [_]u8{0x04} ** 32, .amount = 120, .fee = 10, .memo = "coffee" },
        .{ .sender = [_]u8{0x05} ** 32, .receiver = [_]u8{0x06} ** 32, .amount = 99000, .fee = 200, .memo = "large transfer" },
        .{ .sender = [_]u8{0x07} ** 32, .receiver = [_]u8{0x08} ** 32, .amount = 42, .fee = 5, .memo = "tip" },
    };
    const txn_slice: []const Transaction = &txns;
    for (txn_slice, 0..) |*tx, i| {
        tx.display(i);
    }
    std.debug.print("\n    Total fees: {d}\n", .{totalFees(txn_slice)});
    // ---------------------------------------------------------
    // STEP 5: Mutable slices
    // ---------------------------------------------------------
    std.debug.print("\n  --- Mutable Slices ---\n", .{});
    var data = [_]u8{ 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07 };
    const mutable_slice: []u8 = &data;
    std.debug.print("    Before: ", .{});
    for (mutable_slice) |byte| std.debug.print("{x:0>2} ", .{byte});
    std.debug.print("\n", .{});
    // Modify through the slice — changes the original array!
    mutable_slice[0] = 0xFF;
    mutable_slice[7] = 0xEE;
    std.debug.print("    After:  ", .{});
    for (data) |byte| std.debug.print("{x:0>2} ", .{byte});
    std.debug.print("\n", .{});
    std.debug.print("    (Original array was modified through the slice!)\n", .{});
    // ---------------------------------------------------------
    // STEP 6: Slice equality & comparison
    // ---------------------------------------------------------
    std.debug.print("\n  --- Slice Comparison ---\n", .{});
    const hash_a = [_]u8{0xAB} ** 32;
    const hash_b = [_]u8{0xAB} ** 32;
    const hash_c = [_]u8{0xCD} ** 32;
    const eq_ab = std.mem.eql(u8, &hash_a, &hash_b);
    const eq_ac = std.mem.eql(u8, &hash_a, &hash_c);
    std.debug.print("    hash_a == hash_b: {}\n", .{eq_ab});
    std.debug.print("    hash_a == hash_c: {}\n", .{eq_ac});
    // Use this to verify block hashes match!
    if (eq_ab) {
        std.debug.print("    ✅ Hashes match — block chain is valid\n", .{});
    }
    // ---------------------------------------------------------
    // STEP 7: Bounds safety (Debug mode)
    // ---------------------------------------------------------
    std.debug.print("\n  --- Bounds Safety ---\n", .{});
    std.debug.print("    In Debug mode, slice[out_of_bounds] = PANIC\n", .{});
    std.debug.print("    In Release mode, it's undefined behavior\n", .{});
    std.debug.print("    This is why slices > raw pointers for your chain!\n", .{});
    _ = filterHighValue(txn_slice, 1000);
    std.debug.print("\n✅ Slices mastered!\n\n", .{});
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. `[]T` = pointer + length — safe and bounds-checked
// 2. `&array` converts array → slice automatically
// 3. Sub-slicing: `slice[start..end]` — zero-copy view
// 4. `[]const u8` = Zig's string type
// 5. std.mem.eql() for comparing byte sequences (hashes!)
// 6. Mutable slices modify the underlying data
//
// 🔬 EXPERIMENT:
//   - Try accessing txn_slice[100] — see the panic in Debug
//   - Build with -OReleaseFast and try again — UB, no panic!
//   - Create a function that takes []u8 and try passing
//     []const u8 — see the compile error (const safety)
// ============================================================
