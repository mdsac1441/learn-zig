const std = @import("std");
const testing = std.testing;
// ============================================================
// EXERCISE 1: Test Basics — Built-in test Blocks
// ============================================================
// Zig tests live INSIDE the source file — no separate test
// files needed. Run with `zig test 01_test_basics.zig`.
//
// YOUR BLOCKCHAIN USE CASE:
//   Every function gets tested right where it's defined.
//   Hash functions, serialization, difficulty checks — all
//   tested inline with zero setup.
// ============================================================
// ===================== Blockchain Code ======================
const Transaction = struct {
    sender: u64,
    receiver: u64,
    amount: u64,
    fee: u64,
    nonce: u64,
    fn hash(self: *const Transaction) [32]u8 {
        const ptr: [*]const u8 = @ptrCast(self);
        const bytes = ptr[0..@sizeOf(Transaction)];
        var result: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(bytes, &result, .{});
        return result;
    }
    fn totalCost(self: *const Transaction) u64 {
        return self.amount + self.fee;
    }
    fn isValid(self: *const Transaction) bool {
        if (self.amount == 0) return false;
        if (self.sender == self.receiver) return false;
        if (self.fee == 0) return false;
        return true;
    }
};
fn calculateBlockReward(height: u64) u64 {
    // Halving every 210,000 blocks (like Bitcoin)
    const halvings = height / 210_000;
    if (halvings >= 64) return 0;
    const initial_reward: u64 = 50_000_000; // 50 tokens (in satoshi-like units)
    return initial_reward >> @intCast(halvings);
}
fn meetsDifficulty(hash: [32]u8, difficulty: u32) bool {
    var zeros: u32 = 0;
    for (hash) |byte| {
        if (byte == 0) {
            zeros += 8;
        } else {
            zeros += @clz(byte);
            break;
        }
    }
    return zeros >= difficulty;
}
// ===================== TESTS ================================
// ---------------------------------------------------------
// STEP 1: Basic assertions with `expect`
// ---------------------------------------------------------
test "transaction total cost is amount + fee" {
    const tx = Transaction{
        .sender = 1,
        .receiver = 2,
        .amount = 1000,
        .fee = 50,
        .nonce = 0,
    };
    // `try expect(condition)` — test fails if condition is false
    try testing.expect(tx.totalCost() == 1050);
}
test "transaction total cost does not overflow for reasonable values" {
    const tx = Transaction{
        .sender = 1,
        .receiver = 2,
        .amount = 1_000_000,
        .fee = 500,
        .nonce = 0,
    };
    try testing.expect(tx.totalCost() < std.math.maxInt(u64));
}
// ---------------------------------------------------------
// STEP 2: expectEqual — compare exact values
// ---------------------------------------------------------
test "block reward starts at 50 million" {
    // expectEqual(expected, actual)
    try testing.expectEqual(@as(u64, 50_000_000), calculateBlockReward(0));
}
test "block reward halves at height 210000" {
    try testing.expectEqual(@as(u64, 25_000_000), calculateBlockReward(210_000));
}
test "block reward halves again at height 420000" {
    try testing.expectEqual(@as(u64, 12_500_000), calculateBlockReward(420_000));
}
test "block reward is zero after 64 halvings" {
    try testing.expectEqual(@as(u64, 0), calculateBlockReward(210_000 * 64));
}
// ---------------------------------------------------------
// STEP 3: expectEqualSlices — compare byte sequences
// ---------------------------------------------------------
test "same transaction produces same hash (deterministic)" {
    const tx1 = Transaction{ .sender = 1, .receiver = 2, .amount = 100, .fee = 10, .nonce = 0 };
    const tx2 = Transaction{ .sender = 1, .receiver = 2, .amount = 100, .fee = 10, .nonce = 0 };
    const hash1 = tx1.hash();
    const hash2 = tx2.hash();
    // Byte-by-byte comparison of hashes
    try testing.expectEqualSlices(u8, &hash1, &hash2);
}
test "different transactions produce different hashes" {
    const tx1 = Transaction{ .sender = 1, .receiver = 2, .amount = 100, .fee = 10, .nonce = 0 };
    const tx2 = Transaction{ .sender = 1, .receiver = 2, .amount = 101, .fee = 10, .nonce = 0 };
    const hash1 = tx1.hash();
    const hash2 = tx2.hash();
    // Hashes should NOT match
    try testing.expect(!std.mem.eql(u8, &hash1, &hash2));
}
// ---------------------------------------------------------
// STEP 4: Testing boolean functions
// ---------------------------------------------------------
test "valid transaction passes validation" {
    const tx = Transaction{ .sender = 1, .receiver = 2, .amount = 100, .fee = 10, .nonce = 0 };
    try testing.expect(tx.isValid());
}
test "zero amount transaction is invalid" {
    const tx = Transaction{ .sender = 1, .receiver = 2, .amount = 0, .fee = 10, .nonce = 0 };
    try testing.expect(!tx.isValid());
}
test "self-transfer transaction is invalid" {
    const tx = Transaction{ .sender = 1, .receiver = 1, .amount = 100, .fee = 10, .nonce = 0 };
    try testing.expect(!tx.isValid());
}
test "zero fee transaction is invalid" {
    const tx = Transaction{ .sender = 1, .receiver = 2, .amount = 100, .fee = 0, .nonce = 0 };
    try testing.expect(!tx.isValid());
}
// ---------------------------------------------------------
// STEP 5: Testing difficulty checker
// ---------------------------------------------------------
test "all-zero hash meets any difficulty" {
    const zero_hash = [_]u8{0} ** 32;
    try testing.expect(meetsDifficulty(zero_hash, 256));
}
test "all-FF hash meets zero difficulty" {
    const ff_hash = [_]u8{0xFF} ** 32;
    try testing.expect(meetsDifficulty(ff_hash, 0));
}
test "all-FF hash does not meet difficulty 1" {
    const ff_hash = [_]u8{0xFF} ** 32;
    try testing.expect(!meetsDifficulty(ff_hash, 1));
}
test "hash with one leading zero byte meets difficulty 8" {
    var hash = [_]u8{0xFF} ** 32;
    hash[0] = 0x00;
    try testing.expect(meetsDifficulty(hash, 8));
    try testing.expect(!meetsDifficulty(hash, 9));
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. `test "name" { }` = inline test block, run with `zig test`
// 2. `try testing.expect(bool)` = assert a condition
// 3. `try testing.expectEqual(expected, actual)` = exact match
// 4. `try testing.expectEqualSlices(T, a, b)` = compare arrays
// 5. Tests live IN the source file — no separate test files!
// 6. All tests run in parallel by default
//
// 🔬 EXPERIMENT:
//   - Make a test fail on purpose — see the error output
//   - Add `test "nonce changes hash"` to verify mining logic
//   - Run with `zig test --summary all` for verbose output
// ============================================================
