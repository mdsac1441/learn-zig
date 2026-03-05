const std = @import("std");
const testing = std.testing;
// ============================================================
// EXERCISE 4: Full Blockchain Test Suite
// ============================================================
// A comprehensive test suite for blockchain components:
//   - Block construction & hashing
//   - Merkle tree correctness
//   - State transitions
//   - Chain validation
//
// This is what a REAL blockchain project's test file looks like.
// ============================================================
// ===================== Blockchain Types =====================
const Transaction = struct {
    sender: u64,
    receiver: u64,
    amount: u64,
    fee: u64,
    nonce: u64,
    fn hash(self: *const Transaction) [32]u8 {
        const ptr: [*]const u8 = @ptrCast(self);
        var result: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(ptr[0..@sizeOf(Transaction)], &result, .{});
        return result;
    }
};
const BlockHeader = struct {
    height: u64,
    prev_hash: [32]u8,
    merkle_root: [32]u8,
    timestamp: u64,
    difficulty: u32,
    nonce: u64,
    fn hash(self: *const BlockHeader) [32]u8 {
        const ptr: [*]const u8 = @ptrCast(self);
        var result: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(ptr[0..@sizeOf(BlockHeader)], &result, .{});
        return result;
    }
};
// ===================== Core Functions =======================
fn computeMerkleRoot(allocator: std.mem.Allocator, tx_hashes: []const [32]u8) !?[32]u8 {
    if (tx_hashes.len == 0) return null;
    if (tx_hashes.len == 1) return tx_hashes[0];
    var current = try allocator.alloc([32]u8, tx_hashes.len);
    defer allocator.free(current);
    @memcpy(current, tx_hashes);
    while (current.len > 1) {
        const pairs = (current.len + 1) / 2;
        var next = try allocator.alloc([32]u8, pairs);
        for (0..pairs) |i| {
            const left = current[i * 2];
            const right = if (i * 2 + 1 < current.len) current[i * 2 + 1] else current[i * 2];
            var combined: [64]u8 = undefined;
            @memcpy(combined[0..32], &left);
            @memcpy(combined[32..64], &right);
            std.crypto.hash.sha2.Sha256.hash(&combined, &next[i], .{});
        }
        allocator.free(current);
        current = next;
    }
    const result = current[0];
    return result;
}
const StateManager = struct {
    balances: std.AutoHashMap(u64, u64),
    nonces: std.AutoHashMap(u64, u64),
    fn init(allocator: std.mem.Allocator) StateManager {
        return .{
            .balances = std.AutoHashMap(u64, u64).init(allocator),
            .nonces = std.AutoHashMap(u64, u64).init(allocator),
        };
    }
    fn deinit(self: *StateManager) void {
        self.balances.deinit();
        self.nonces.deinit();
    }
    fn setBalance(self: *StateManager, account: u64, balance: u64) !void {
        try self.balances.put(account, balance);
        if (!self.nonces.contains(account)) {
            try self.nonces.put(account, 0);
        }
    }
    fn getBalance(self: *const StateManager, account: u64) u64 {
        return self.balances.get(account) orelse 0;
    }
    fn getNonce(self: *const StateManager, account: u64) u64 {
        return self.nonces.get(account) orelse 0;
    }
    fn applyTransaction(self: *StateManager, tx: *const Transaction) !void {
        const sender_balance = self.getBalance(tx.sender);
        const total_cost = tx.amount + tx.fee;
        if (sender_balance < total_cost) return error.InsufficientBalance;
        if (tx.nonce != self.getNonce(tx.sender)) return error.NonceMismatch;
        // Debit sender
        try self.balances.put(tx.sender, sender_balance - total_cost);
        // Credit receiver
        const receiver_balance = self.getBalance(tx.receiver);
        try self.balances.put(tx.receiver, receiver_balance + tx.amount);
        // Increment nonce
        try self.nonces.put(tx.sender, tx.nonce + 1);
    }
};
// ================ TEST SUITE: Hashing ======================
test "transaction hash is deterministic" {
    const tx = Transaction{ .sender = 1, .receiver = 2, .amount = 100, .fee = 10, .nonce = 0 };
    const h1 = tx.hash();
    const h2 = tx.hash();
    try testing.expectEqualSlices(u8, &h1, &h2);
}
test "changing any field changes the hash" {
    const base = Transaction{ .sender = 1, .receiver = 2, .amount = 100, .fee = 10, .nonce = 0 };
    const base_hash = base.hash();
    // Change sender
    const diff_sender = Transaction{ .sender = 99, .receiver = 2, .amount = 100, .fee = 10, .nonce = 0 };
    try testing.expect(!std.mem.eql(u8, &base_hash, &diff_sender.hash()));
    // Change amount
    const diff_amount = Transaction{ .sender = 1, .receiver = 2, .amount = 101, .fee = 10, .nonce = 0 };
    try testing.expect(!std.mem.eql(u8, &base_hash, &diff_amount.hash()));
    // Change nonce
    const diff_nonce = Transaction{ .sender = 1, .receiver = 2, .amount = 100, .fee = 10, .nonce = 1 };
    try testing.expect(!std.mem.eql(u8, &base_hash, &diff_nonce.hash()));
}
// ================ TEST SUITE: Merkle Tree ===================
test "merkle root of single transaction" {
    const tx = Transaction{ .sender = 1, .receiver = 2, .amount = 100, .fee = 10, .nonce = 0 };
    const hashes = [_][32]u8{tx.hash()};
    const root = try computeMerkleRoot(testing.allocator, &hashes);
    try testing.expect(root != null);
    // Single tx merkle root = the tx hash itself
    try testing.expectEqualSlices(u8, &hashes[0], &root.?);
}
test "merkle root of empty list is null" {
    const root = try computeMerkleRoot(testing.allocator, &[_][32]u8{});
    try testing.expectEqual(@as(?[32]u8, null), root);
}
test "merkle root changes when any transaction changes" {
    const tx1 = Transaction{ .sender = 1, .receiver = 2, .amount = 100, .fee = 10, .nonce = 0 };
    const tx2 = Transaction{ .sender = 3, .receiver = 4, .amount = 200, .fee = 20, .nonce = 0 };
    const tx3 = Transaction{ .sender = 5, .receiver = 6, .amount = 300, .fee = 30, .nonce = 0 };
    const hashes_original = [_][32]u8{ tx1.hash(), tx2.hash(), tx3.hash() };
    const root_original = try computeMerkleRoot(testing.allocator, &hashes_original);
    // Change one transaction
    const tx2_modified = Transaction{ .sender = 3, .receiver = 4, .amount = 999, .fee = 20, .nonce = 0 };
    const hashes_modified = [_][32]u8{ tx1.hash(), tx2_modified.hash(), tx3.hash() };
    const root_modified = try computeMerkleRoot(testing.allocator, &hashes_modified);
    try testing.expect(root_original != null);
    try testing.expect(root_modified != null);
    try testing.expect(!std.mem.eql(u8, &root_original.?, &root_modified.?));
}
test "merkle root is order-dependent" {
    const tx1 = Transaction{ .sender = 1, .receiver = 2, .amount = 100, .fee = 10, .nonce = 0 };
    const tx2 = Transaction{ .sender = 3, .receiver = 4, .amount = 200, .fee = 20, .nonce = 0 };
    const order_a = [_][32]u8{ tx1.hash(), tx2.hash() };
    const order_b = [_][32]u8{ tx2.hash(), tx1.hash() };
    const root_a = try computeMerkleRoot(testing.allocator, &order_a);
    const root_b = try computeMerkleRoot(testing.allocator, &order_b);
    // Different order → different root (ensures transaction ordering matters)
    try testing.expect(!std.mem.eql(u8, &root_a.?, &root_b.?));
}
// ================ TEST SUITE: State Transitions =============
test "basic transfer updates balances correctly" {
    var state = StateManager.init(testing.allocator);
    defer state.deinit();
    try state.setBalance(1, 10000);
    try state.setBalance(2, 5000);
    const tx = Transaction{ .sender = 1, .receiver = 2, .amount = 3000, .fee = 100, .nonce = 0 };
    try state.applyTransaction(&tx);
    try testing.expectEqual(@as(u64, 6900), state.getBalance(1)); // 10000 - 3000 - 100
    try testing.expectEqual(@as(u64, 8000), state.getBalance(2)); // 5000 + 3000
}
test "nonce increments after transaction" {
    var state = StateManager.init(testing.allocator);
    defer state.deinit();
    try state.setBalance(1, 10000);
    try state.setBalance(2, 5000);
    try testing.expectEqual(@as(u64, 0), state.getNonce(1));
    const tx = Transaction{ .sender = 1, .receiver = 2, .amount = 100, .fee = 10, .nonce = 0 };
    try state.applyTransaction(&tx);
    try testing.expectEqual(@as(u64, 1), state.getNonce(1));
}
test "sequential transactions with incrementing nonces" {
    var state = StateManager.init(testing.allocator);
    defer state.deinit();
    try state.setBalance(1, 10000);
    try state.setBalance(2, 0);
    // TX 0: send 100
    const tx0 = Transaction{ .sender = 1, .receiver = 2, .amount = 100, .fee = 10, .nonce = 0 };
    try state.applyTransaction(&tx0);
    // TX 1: send 200
    const tx1 = Transaction{ .sender = 1, .receiver = 2, .amount = 200, .fee = 10, .nonce = 1 };
    try state.applyTransaction(&tx1);
    // TX 2: send 300
    const tx2 = Transaction{ .sender = 1, .receiver = 2, .amount = 300, .fee = 10, .nonce = 2 };
    try state.applyTransaction(&tx2);
    try testing.expectEqual(@as(u64, 9370), state.getBalance(1)); // 10000 - 600 - 30
    try testing.expectEqual(@as(u64, 600), state.getBalance(2));
    try testing.expectEqual(@as(u64, 3), state.getNonce(1));
}
test "reject transaction with wrong nonce" {
    var state = StateManager.init(testing.allocator);
    defer state.deinit();
    try state.setBalance(1, 10000);
    try state.setBalance(2, 5000);
    const tx = Transaction{ .sender = 1, .receiver = 2, .amount = 100, .fee = 10, .nonce = 5 }; // wrong!
    try testing.expectError(error.NonceMismatch, state.applyTransaction(&tx));
    // Balance should be unchanged
    try testing.expectEqual(@as(u64, 10000), state.getBalance(1));
}
test "reject transaction exceeding balance" {
    var state = StateManager.init(testing.allocator);
    defer state.deinit();
    try state.setBalance(1, 100);
    try state.setBalance(2, 5000);
    const tx = Transaction{ .sender = 1, .receiver = 2, .amount = 90, .fee = 20, .nonce = 0 }; // 110 > 100
    try testing.expectError(error.InsufficientBalance, state.applyTransaction(&tx));
    // Balance unchanged (atomic — either all applies or none)
    try testing.expectEqual(@as(u64, 100), state.getBalance(1));
    try testing.expectEqual(@as(u64, 5000), state.getBalance(2));
}
test "transfer to new account creates balance" {
    var state = StateManager.init(testing.allocator);
    defer state.deinit();
    try state.setBalance(1, 10000);
    // Account 99 does not exist yet
    const tx = Transaction{ .sender = 1, .receiver = 99, .amount = 500, .fee = 10, .nonce = 0 };
    try state.applyTransaction(&tx);
    try testing.expectEqual(@as(u64, 500), state.getBalance(99)); // created!
    try testing.expectEqual(@as(u64, 9490), state.getBalance(1));
}
test "fee is deducted from sender but not credited to receiver" {
    var state = StateManager.init(testing.allocator);
    defer state.deinit();
    try state.setBalance(1, 10000);
    try state.setBalance(2, 0);
    const tx = Transaction{ .sender = 1, .receiver = 2, .amount = 1000, .fee = 500, .nonce = 0 };
    try state.applyTransaction(&tx);
    // Fee is burned (or goes to miner — not modeled here)
    const total_after = state.getBalance(1) + state.getBalance(2);
    try testing.expectEqual(@as(u64, 9500), total_after); // 10000 - 500 fee
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. Structure tests by component: Hashing, Merkle, State
// 2. Test PROPERTIES: determinism, sensitivity, ordering
// 3. Test STATE INVARIANTS: balances sum correctly, nonces inc
// 4. Test ATOMICITY: failed TX leaves state unchanged
// 5. Test EDGE CASES: empty merkle, new accounts, exact balance
// 6. testing.allocator catches leaks in Merkle tree allocs!
//
// 🔬 EXPERIMENT:
//   - Add a test for "double spend" (same nonce twice)
//   - Test a chain of 100 transactions — final balance correct?
//   - Add a StateManager.snapshot()/rollback() and test it
//   - Test with 1000 random transactions (fuzz-like testing)
// ============================================================
