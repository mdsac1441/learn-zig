const std = @import("std");
const testing = std.testing;
// ============================================================
// EXERCISE 2: Test Allocator — Memory Leak Detection
// ============================================================
// std.testing.allocator is a SPECIAL allocator that detects
// memory leaks. If you forget to free ANYTHING, the test FAILS.
//
// YOUR BLOCKCHAIN USE CASE:
//   Your mempool, block builder, and state manager all allocate.
//   One leak in a long-running node = eventually OOM and crash.
//   The test allocator catches this BEFORE deployment.
// ============================================================
// ===================== Blockchain Code ======================
const Transaction = struct {
    id: u64,
    amount: u64,
    fee: u64,
};
const Mempool = struct {
    transactions: std.ArrayList(Transaction),
    total_fees: u64,
    fn init(allocator: std.mem.Allocator) Mempool {
        return .{
            .transactions = std.ArrayList(Transaction).init(allocator),
            .total_fees = 0,
        };
    }
    fn deinit(self: *Mempool) void {
        self.transactions.deinit();
    }
    fn addTransaction(self: *Mempool, tx: Transaction) !void {
        try self.transactions.append(tx);
        self.total_fees += tx.fee;
    }
    fn removeFirst(self: *Mempool) ?Transaction {
        if (self.transactions.items.len == 0) return null;
        const tx = self.transactions.orderedRemove(0);
        self.total_fees -= tx.fee;
        return tx;
    }
    fn count(self: *const Mempool) usize {
        return self.transactions.items.len;
    }
    fn clear(self: *Mempool) void {
        self.transactions.clearRetainingCapacity();
        self.total_fees = 0;
    }
};
/// Build a block from mempool transactions
fn buildBlockData(allocator: std.mem.Allocator, mempool: *Mempool, max_txns: usize) ![]Transaction {
    const take = @min(max_txns, mempool.count());
    if (take == 0) return error.EmptyMempool;
    const block_txns = try allocator.alloc(Transaction, take);
    // errdefer: if we fail later, free what we allocated
    errdefer allocator.free(block_txns);
    for (0..take) |i| {
        block_txns[i] = mempool.removeFirst() orelse break;
    }
    return block_txns;
}
/// Create a formatted transaction receipt (allocates a string)
fn createReceipt(allocator: std.mem.Allocator, tx: *const Transaction) ![]u8 {
    return try std.fmt.allocPrint(allocator, "RECEIPT: TX#{d} amount={d} fee={d}", .{
        tx.id, tx.amount, tx.fee,
    });
}
// ===================== TESTS ================================
// ---------------------------------------------------------
// STEP 1: Testing with the leak-detecting allocator
// ---------------------------------------------------------
test "mempool init and deinit — no leaks" {
    // std.testing.allocator tracks every allocation
    // If we forget deinit → TEST FAILS with leak report!
    var pool = Mempool.init(testing.allocator);
    defer pool.deinit(); // Remove this line to see the leak error!
    try pool.addTransaction(.{ .id = 0, .amount = 100, .fee = 10 });
    try pool.addTransaction(.{ .id = 1, .amount = 200, .fee = 20 });
    try testing.expectEqual(@as(usize, 2), pool.count());
}
test "mempool tracks total fees correctly" {
    var pool = Mempool.init(testing.allocator);
    defer pool.deinit();
    try pool.addTransaction(.{ .id = 0, .amount = 100, .fee = 10 });
    try pool.addTransaction(.{ .id = 1, .amount = 200, .fee = 25 });
    try pool.addTransaction(.{ .id = 2, .amount = 300, .fee = 15 });
    try testing.expectEqual(@as(u64, 50), pool.total_fees);
}
test "mempool removeFirst returns correct transaction" {
    var pool = Mempool.init(testing.allocator);
    defer pool.deinit();
    try pool.addTransaction(.{ .id = 42, .amount = 500, .fee = 50 });
    try pool.addTransaction(.{ .id = 99, .amount = 100, .fee = 10 });
    const first = pool.removeFirst();
    try testing.expect(first != null);
    try testing.expectEqual(@as(u64, 42), first.?.id);
    try testing.expectEqual(@as(usize, 1), pool.count());
}
test "mempool removeFirst on empty returns null" {
    var pool = Mempool.init(testing.allocator);
    defer pool.deinit();
    try testing.expectEqual(@as(?Transaction, null), pool.removeFirst());
}
// ---------------------------------------------------------
// STEP 2: Testing functions that allocate (must free!)
// ---------------------------------------------------------
test "buildBlockData allocates and returns transactions" {
    var pool = Mempool.init(testing.allocator);
    defer pool.deinit();
    try pool.addTransaction(.{ .id = 0, .amount = 100, .fee = 10 });
    try pool.addTransaction(.{ .id = 1, .amount = 200, .fee = 20 });
    try pool.addTransaction(.{ .id = 2, .amount = 300, .fee = 30 });
    // buildBlockData ALLOCATES — we must free it!
    const block = try buildBlockData(testing.allocator, &pool, 2);
    defer testing.allocator.free(block); // Forget this → leak!
    try testing.expectEqual(@as(usize, 2), block.len);
    try testing.expectEqual(@as(u64, 0), block[0].id);
    try testing.expectEqual(@as(u64, 1), block[1].id);
    try testing.expectEqual(@as(usize, 1), pool.count()); // 1 remaining
}
test "buildBlockData fails on empty mempool" {
    var pool = Mempool.init(testing.allocator);
    defer pool.deinit();
    const result = buildBlockData(testing.allocator, &pool, 5);
    try testing.expectError(error.EmptyMempool, result);
}
// ---------------------------------------------------------
// STEP 3: Testing string allocations
// ---------------------------------------------------------
test "createReceipt produces correct format" {
    const tx = Transaction{ .id = 42, .amount = 5000, .fee = 50 };
    const receipt = try createReceipt(testing.allocator, &tx);
    defer testing.allocator.free(receipt); // Free the string!
    try testing.expectEqualStrings("RECEIPT: TX#42 amount=5000 fee=50", receipt);
}
test "createReceipt for different transactions" {
    const txns = [_]Transaction{
        .{ .id = 0, .amount = 100, .fee = 10 },
        .{ .id = 999, .amount = 1, .fee = 1 },
    };
    for (&txns) |*tx| {
        const receipt = try createReceipt(testing.allocator, tx);
        defer testing.allocator.free(receipt);
        // Just verify it starts with "RECEIPT:"
        try testing.expect(std.mem.startsWith(u8, receipt, "RECEIPT:"));
    }
}
// ---------------------------------------------------------
// STEP 4: Testing with many allocations (stress test)
// ---------------------------------------------------------
test "mempool handles 1000 transactions without leaks" {
    var pool = Mempool.init(testing.allocator);
    defer pool.deinit();
    // Add 1000 transactions
    for (0..1000) |i| {
        try pool.addTransaction(.{
            .id = i,
            .amount = (i + 1) * 100,
            .fee = i + 1,
        });
    }
    try testing.expectEqual(@as(usize, 1000), pool.count());
    // Remove half
    for (0..500) |_| {
        _ = pool.removeFirst();
    }
    try testing.expectEqual(@as(usize, 500), pool.count());
    // Clear the rest
    pool.clear();
    try testing.expectEqual(@as(usize, 0), pool.count());
    try testing.expectEqual(@as(u64, 0), pool.total_fees);
}
// ---------------------------------------------------------
// STEP 5: Testing HashMap (common in blockchain state)
// ---------------------------------------------------------
test "account balance map — no leaks" {
    var balances = std.AutoHashMap(u64, u64).init(testing.allocator);
    defer balances.deinit();
    // Set balances
    try balances.put(1, 10000);
    try balances.put(2, 5000);
    try balances.put(3, 7500);
    // Check balance
    try testing.expectEqual(@as(u64, 10000), balances.get(1).?);
    // Transfer: 1 → 2, amount 3000
    const sender_bal = balances.get(1).?;
    const receiver_bal = balances.get(2).?;
    try balances.put(1, sender_bal - 3000);
    try balances.put(2, receiver_bal + 3000);
    try testing.expectEqual(@as(u64, 7000), balances.get(1).?);
    try testing.expectEqual(@as(u64, 8000), balances.get(2).?);
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. std.testing.allocator = allocator that DETECTS MEMORY LEAKS
// 2. If test code leaks → test FAILS with detailed report
// 3. Always `defer allocator.free()` or `defer obj.deinit()`
// 4. Test functions that allocate by verifying they're freed
// 5. Use testing.allocator in ALL tests — catch leaks early
// 6. This is Zig's secret weapon: leak detection without Valgrind
//
// 🔬 EXPERIMENT:
//   - Remove a `defer ...deinit()` and see the leak report
//   - Remove a `defer ...free()` and see which test fails
//   - Create a function that intentionally leaks and test it
//   - Add a test for 10,000 transactions — still no leaks?
// ============================================================
