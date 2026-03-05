const std = @import("std");
// ============================================================
// EXERCISE 4: Blockchain Mempool — All Allocators Combined
// ============================================================
// A MEMPOOL holds unconfirmed transactions waiting to be
// included in the next block. This exercise combines:
//
//   - page_allocator → long-lived mempool storage
//   - ArenaAllocator → temp workspace for batch operations
//   - FixedBufferAllocator → stack buffer for hashing
//
// This is a REAL blockchain component you'll use in your node.
// ============================================================
const Transaction = struct {
    id: u64,
    sender: [32]u8,
    receiver: [32]u8,
    amount: u64,
    fee: u64,
    hash: [32]u8,
    fn init(id: u64, sender_id: u8, receiver_id: u8, amount: u64, fee: u64) Transaction {
        var tx = Transaction{
            .id = id,
            .sender = undefined,
            .receiver = undefined,
            .amount = amount,
            .fee = fee,
            .hash = undefined,
        };
        @memset(&tx.sender, sender_id);
        @memset(&tx.receiver, receiver_id);
        // Hash the transaction using a STACK buffer (no heap!)
        var hash_buf: [128]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&hash_buf);
        _ = fba.allocator();
        // Hash the raw transaction data
        const raw: [*]const u8 = @ptrCast(&tx);
        const tx_bytes = raw[0..@sizeOf(Transaction)];
        std.crypto.hash.sha2.Sha256.hash(tx_bytes, &tx.hash, .{});
        return tx;
    }
    fn display(self: *const Transaction, index: usize) void {
        std.debug.print("    [{d:>3}] TX#{d:<4}  {d:>8} tokens  fee={d:<4}  hash=", .{
            index,
            self.id,
            self.amount,
            self.fee,
        });
        for (self.hash[0..4]) |byte| {
            std.debug.print("{x:0>2}", .{byte});
        }
        std.debug.print("...\n", .{});
    }
};
/// Compare transactions by fee (descending) for priority ordering
fn compareFees(_: void, a: Transaction, b: Transaction) bool {
    return a.fee > b.fee; // highest fee first
}
const Mempool = struct {
    /// Long-lived storage for pending transactions
    transactions: std.ArrayList(Transaction),
    /// Stats
    total_added: u64,
    total_removed: u64,
    fn init(allocator: std.mem.Allocator) Mempool {
        return .{
            .transactions = std.ArrayList(Transaction).init(allocator),
            .total_added = 0,
            .total_removed = 0,
        };
    }
    fn deinit(self: *Mempool) void {
        self.transactions.deinit();
    }
    /// Add a transaction to the mempool
    fn addTransaction(self: *Mempool, tx: Transaction) !void {
        try self.transactions.append(tx);
        self.total_added += 1;
    }
    /// Select the best transactions for a new block (by fee)
    /// Uses an ARENA for temporary sorting workspace
    fn selectForBlock(self: *Mempool, max_txns: usize) ![]const Transaction {
        if (self.transactions.items.len == 0) return &[_]Transaction{};
        // Sort by fee (highest first) — miners want max revenue
        std.mem.sort(Transaction, self.transactions.items, {}, compareFees);
        const count = @min(max_txns, self.transactions.items.len);
        return self.transactions.items[0..count];
    }
    /// Remove transactions that were included in a block
    fn removeConfirmed(self: *Mempool, count: usize) void {
        const to_remove = @min(count, self.transactions.items.len);
        // Remove from the front (highest fee txns were selected)
        for (0..to_remove) |_| {
            _ = self.transactions.orderedRemove(0);
        }
        self.total_removed += to_remove;
    }
    fn displayStats(self: *const Mempool) void {
        std.debug.print("    Pending:  {d} transactions\n", .{self.transactions.items.len});
        std.debug.print("    Added:    {d} total\n", .{self.total_added});
        std.debug.print("    Removed:  {d} total\n", .{self.total_removed});
    }
};
pub fn main() !void {
    std.debug.print("\n=== Lesson 2.4: Blockchain Mempool — Combined Allocators ===\n\n", .{});
    // ==========================================================
    // LAYER 1: page_allocator for long-lived mempool
    // ==========================================================
    std.debug.print("  🏗️  Initializing mempool (page_allocator)...\n\n", .{});
    var mempool = Mempool.init(std.heap.page_allocator);
    defer mempool.deinit();
    // ==========================================================
    // LAYER 2: Simulate receiving transactions from the network
    // ==========================================================
    std.debug.print("  📡 Receiving transactions from network...\n", .{});
    // Each transaction hashes itself using FixedBufferAllocator
    // internally (see Transaction.init) — zero heap for hashing!
    const tx_data = [_]struct { sender: u8, receiver: u8, amount: u64, fee: u64 }{
        .{ .sender = 0x01, .receiver = 0x02, .amount = 5000, .fee = 50 },
        .{ .sender = 0x03, .receiver = 0x04, .amount = 1200, .fee = 15 },
        .{ .sender = 0x05, .receiver = 0x06, .amount = 8000, .fee = 120 },
        .{ .sender = 0x07, .receiver = 0x08, .amount = 300, .fee = 5 },
        .{ .sender = 0x09, .receiver = 0x0A, .amount = 15000, .fee = 200 },
        .{ .sender = 0x0B, .receiver = 0x0C, .amount = 750, .fee = 30 },
        .{ .sender = 0x0D, .receiver = 0x0E, .amount = 22000, .fee = 350 },
        .{ .sender = 0x0F, .receiver = 0x10, .amount = 100, .fee = 8 },
        .{ .sender = 0x11, .receiver = 0x12, .amount = 4500, .fee = 45 },
        .{ .sender = 0x13, .receiver = 0x14, .amount = 9999, .fee = 150 },
    };
    for (tx_data, 0..) |data, i| {
        const tx = Transaction.init(
            i,
            data.sender,
            data.receiver,
            data.amount,
            data.fee,
        );
        try mempool.addTransaction(tx);
    }
    std.debug.print("    Added {d} transactions to mempool\n\n", .{tx_data.len});
    // ==========================================================
    // LAYER 3: Arena-based block building
    // ==========================================================
    std.debug.print("  ⛏️  Building Block #1 (selecting top 5 by fee)...\n", .{});
    // Use an arena for the block-building workspace
    var block_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer block_arena.deinit();
    {
        const selected = try mempool.selectForBlock(5);
        std.debug.print("\n    Selected transactions (sorted by fee ↓):\n", .{});
        for (selected, 0..) |*tx, i| {
            tx.display(i);
        }
        // Calculate block reward
        var total_fees: u64 = 0;
        for (selected) |tx| {
            total_fees += tx.fee;
        }
        std.debug.print("\n    Block reward (fees): {d} tokens\n", .{total_fees});
        // "Confirm" these transactions
        mempool.removeConfirmed(selected.len);
    }
    // ==========================================================
    // Show final state
    // ==========================================================
    std.debug.print("\n  📊 Mempool Status:\n", .{});
    mempool.displayStats();
    std.debug.print("\n    Remaining transactions:\n", .{});
    for (mempool.transactions.items, 0..) |*tx, i| {
        tx.display(i);
    }
    std.debug.print("\n✅ Mempool demo complete!\n", .{});
    std.debug.print("   - page_allocator: long-lived mempool storage\n", .{});
    std.debug.print("   - FixedBuffer: per-transaction hashing (inside Transaction.init)\n", .{});
    std.debug.print("   - Arena: block-building workspace (freed after block mined)\n\n", .{});
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. REAL PATTERN: Different allocators for different lifetimes
//    - page_allocator → node lifetime (mempool, chain state)
//    - ArenaAllocator → request lifetime (block validation)
//    - FixedBuffer    → operation lifetime (single hash)
//
// 2. The Allocator interface means your mempool doesn't CARE
//    which allocator it uses — you decide at the call site!
//
// 3. This is why Zig is ideal for blockchains:
//    - No GC pauses during consensus
//    - Deterministic memory usage
//    - You can audit every single allocation
//
// 🔬 EXPERIMENT:
//   - Add a "maximum mempool size" that rejects low-fee txns
//   - Implement transaction expiry (remove txns older than N)
//   - Add duplicate detection (reject txns with same hash)
//   - Use GeneralPurposeAllocator to detect memory leaks
// ============================================================
