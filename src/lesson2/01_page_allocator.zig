const std = @import("std");
// ============================================================
// EXERCISE 1: Page Allocator — Dynamic Transaction List
// ============================================================
// The page_allocator asks the OS for memory (like malloc).
// It's the simplest allocator — good for long-lived data.
//
// YOUR BLOCKCHAIN USE CASE:
//   Your node starts up and needs to load the UTXO set or
//   a list of known peers — data that lives for the entire
//   runtime of the process.
// ===========================================================
const Transaction = struct {
    sender: [32]u8,
    receiver: [32]u8,
    amount: u64,
    nonce: u64,
    fn init(sender_id: u8, receiver_id: u8, amount: u64, nonce: u64) Transaction {
        var tx: Transaction = undefined;
        @memset(&tx.sender, sender_id);
        @memset(&tx.receiver, receiver_id);
        tx.amount = amount;
        tx.nonce = nonce;
        return tx;
    }
    fn display(self: *const Transaction) void {
        std.debug.print("  TX: sender=0x{x:0>2}... receiver=0x{x:0>2}... amount={d} nonce={d}\n", .{
            self.sender[0],
            self.receiver[0],
            self.amount,
            self.nonce,
        });
    }
};
pub fn main() !void {
    // ---------------------------------------------------------
    // STEP 1: Get the page allocator
    // ---------------------------------------------------------
    // page_allocator is a global, OS-backed allocator.
    // Every allocation is at least one page (usually 4KB).
    const allocator = std.heap.page_allocator;
    // ---------------------------------------------------------
    // STEP 2: Create a dynamic list (ArrayList)
    // ---------------------------------------------------------
    // ArrayList is like a Vec in Rust or a dynamic array in C.
    // It takes an allocator so it knows WHERE to get memory.
    var txn_list = std.ArrayList(Transaction){};
    // CRITICAL: defer ensures cleanup even if we return early
    // or hit an error. Try commenting this out and see leaks!
    defer txn_list.deinit(allocator);
    // ---------------------------------------------------------
    // STEP 3: Add transactions to the list
    // ---------------------------------------------------------
    std.debug.print("\n=== Lesson 2.1: Page Allocator — Dynamic Transaction List ===\n\n", .{});
    // Simulate receiving 5 transactions
    for (0..5) |i| {
        const tx = Transaction.init(
            @intCast(i + 1), // sender ID
            @intCast(i + 10), // receiver ID
            (i + 1) * 1000, // amount
            i, // nonce
        );
        try txn_list.append(allocator, tx);
        std.debug.print("  [+] Added transaction #{d}\n", .{i});
    }
    std.debug.print("\n  Total transactions: {d}\n", .{txn_list.items.len});
    std.debug.print("  List capacity: {d}\n", .{txn_list.capacity});
    // ---------------------------------------------------------
    // STEP 4: Iterate and display
    // ---------------------------------------------------------
    std.debug.print("\n  --- All Transactions ---\n", .{});
    for (txn_list.items) |*tx| {
        tx.display();
    }
    // ---------------------------------------------------------
    // STEP 5: Manual single allocation (alloc / free)
    // ---------------------------------------------------------
    std.debug.print("\n  --- Manual Allocation ---\n", .{});
    // Allocate a single Transaction on the heap
    const single_tx = try allocator.create(Transaction);
    defer allocator.destroy(single_tx);
    single_tx.* = Transaction.init(0xFF, 0xAA, 999_999, 42);
    std.debug.print("  Manually allocated TX:\n", .{});
    single_tx.display();
    // Allocate a slice of 3 transactions
    const tx_slice = try allocator.alloc(Transaction, 3);
    defer allocator.free(tx_slice);
    for (tx_slice, 0..) |*tx, idx| {
        tx.* = Transaction.init(@intCast(idx), @intCast(idx + 50), (idx + 1) * 500, idx);
    }
    std.debug.print("\n  Slice-allocated TXs:\n", .{});
    for (tx_slice) |*tx| {
        tx.display();
    }
    std.debug.print("\n✅ All memory freed via defer — no leaks!\n\n", .{});
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. page_allocator is the simplest — OS gives you whole pages
// 2. ArrayList needs an allocator — nothing is implicit
// 3. `defer .deinit()` / `defer .destroy()` = automatic cleanup
// 4. `allocator.create(T)` = single item on heap
// 5. `allocator.alloc(T, n)` = n items on heap (returns []T)
//
// 🔬 EXPERIMENT:
//   - Comment out the `defer txn_list.deinit();` line
//   - In a real project with GeneralPurposeAllocator, you'd
//     see a leak report. page_allocator doesn't track leaks.
//   - We'll use GPA for leak detection in Lesson 7 (Testing).
// ============================================================
