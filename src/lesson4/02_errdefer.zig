const std = @import("std");
// ============================================================
// EXERCISE 2: errdefer — Cleanup Only On Failure
// ============================================================
// `defer` runs ALWAYS when scope exits.
// `errdefer` runs ONLY when the function returns an error.
//
// YOUR BLOCKCHAIN USE CASE:
//   When building a block, you allocate memory for txns,
//   compute the Merkle root, then sign. If signing fails,
//   you need to free the txns you allocated. But if everything
//   succeeds, you DON'T free — the caller owns them now.
// ============================================================
const BlockBuildError = error{
    NoTransactions,
    MerkleComputeFailed,
    SigningFailed,
    OutOfMemory,
};
const Block = struct {
    transactions: []Transaction,
    merkle_root: [32]u8,
    signature: [64]u8,
    height: u64,
    fn display(self: *const Block) void {
        std.debug.print("    Block #{d}: {d} txns, merkle=", .{ self.height, self.transactions.len });
        for (self.merkle_root[0..4]) |b| std.debug.print("{x:0>2}", .{b});
        std.debug.print("..., sig=", .{});
        for (self.signature[0..4]) |b| std.debug.print("{x:0>2}", .{b});
        std.debug.print("...\n", .{});
    }
};
const Transaction = struct {
    id: u64,
    amount: u64,
};
/// Simulates fetching transactions from the mempool
fn fetchTransactions(allocator: std.mem.Allocator, count: usize) ![]Transaction {
    if (count == 0) return error.NoTransactions;
    const txns = try allocator.alloc(Transaction, count);
    // errdefer NOT needed here — if alloc fails, nothing to free
    for (txns, 0..) |*tx, i| {
        tx.* = .{ .id = i, .amount = (i + 1) * 100 };
    }
    std.debug.print("    [fetch] Allocated {d} transactions\n", .{count});
    return txns;
}
/// Simulates computing the Merkle root (can fail)
fn computeMerkleRoot(txns: []const Transaction, fail: bool) ![32]u8 {
    if (fail) {
        std.debug.print("    [merkle] ❌ Computation failed!\n", .{});
        return error.MerkleComputeFailed;
    }
    var root: [32]u8 = undefined;
    // Simple hash of all transaction IDs
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    for (txns) |tx| {
        const bytes: [*]const u8 = @ptrCast(&tx.id);
        hasher.update(bytes[0..@sizeOf(u64)]);
    }
    hasher.final(&root);
    std.debug.print("    [merkle] ✅ Root computed\n", .{});
    return root;
}
/// Simulates signing the block (can fail)
fn signBlock(merkle_root: *const [32]u8, fail: bool) ![64]u8 {
    if (fail) {
        std.debug.print("    [sign] ❌ Signing failed!\n", .{});
        return error.SigningFailed;
    }
    var sig: [64]u8 = undefined;
    @memcpy(sig[0..32], merkle_root);
    @memcpy(sig[32..64], merkle_root);
    std.debug.print("    [sign] ✅ Block signed\n", .{});
    return sig;
}
// ---------------------------------------------------------
// THE KEY FUNCTION: Uses errdefer for safe cleanup
// ---------------------------------------------------------
/// Build a complete block — allocates, computes, signs.
/// On ANY failure, errdefer cleans up partial work.
fn buildBlock(
    allocator: std.mem.Allocator,
    height: u64,
    tx_count: usize,
    fail_merkle: bool,
    fail_sign: bool,
) !Block {
    // STEP A: Fetch transactions (allocates memory)
    const txns = try fetchTransactions(allocator, tx_count);
    // ⭐ errdefer: free txns ONLY if this function returns error
    // If we succeed, the caller owns txns (via the Block struct)
    errdefer {
        std.debug.print("    [errdefer] 🧹 Freeing {d} transactions (error path)\n", .{txns.len});
        allocator.free(txns);
    }
    // STEP B: Compute Merkle root (might fail)
    const merkle = try computeMerkleRoot(txns, fail_merkle);
    // If computeMerkleRoot fails → errdefer frees txns ✅
    // STEP C: Sign block (might fail)
    const sig = try signBlock(&merkle, fail_sign);
    // If signBlock fails → errdefer frees txns ✅
    // STEP D: Success! Return block — errdefer does NOT run
    std.debug.print("    [build] ✅ Block #{d} built successfully\n", .{height});
    return Block{
        .transactions = txns,
        .merkle_root = merkle,
        .signature = sig,
        .height = height,
    };
}
pub fn main() !void {
    std.debug.print("\n=== Lesson 4.2: errdefer — Cleanup On Failure ===\n\n", .{});
    const allocator = std.heap.page_allocator;
    // ---------------------------------------------------------
    // Scenario 1: Everything succeeds
    // ---------------------------------------------------------
    {
        std.debug.print("  📦 Scenario 1: Build succeeds\n", .{});
        const block = try buildBlock(allocator, 1, 5, false, false);
        defer allocator.free(block.transactions); // caller owns it now
        block.display();
        std.debug.print("    → errdefer did NOT run (success path)\n\n", .{});
    }
    // ---------------------------------------------------------
    // Scenario 2: Merkle computation fails
    // ---------------------------------------------------------
    {
        std.debug.print("  📦 Scenario 2: Merkle fails\n", .{});
        const result = buildBlock(allocator, 2, 5, true, false);
        if (result) |block| {
            _ = block;
            std.debug.print("    Unexpected success!\n", .{});
        } else |err| {
            std.debug.print("    → Error: {s}\n", .{@errorName(err)});
            std.debug.print("    → errdefer DID run — transactions freed! 🧹\n\n", .{});
        }
    }
    // ---------------------------------------------------------
    // Scenario 3: Signing fails
    // ---------------------------------------------------------
    {
        std.debug.print("  📦 Scenario 3: Signing fails\n", .{});
        const result = buildBlock(allocator, 3, 5, false, true);
        if (result) |block| {
            _ = block;
            std.debug.print("    Unexpected success!\n", .{});
        } else |err| {
            std.debug.print("    → Error: {s}\n", .{@errorName(err)});
            std.debug.print("    → errdefer DID run — transactions freed! 🧹\n\n", .{});
        }
    }
    // ---------------------------------------------------------
    // Scenario 4: No transactions
    // ---------------------------------------------------------
    {
        std.debug.print("  📦 Scenario 4: Zero transactions\n", .{});
        const result = buildBlock(allocator, 4, 0, false, false);
        if (result) |block| {
            _ = block;
            std.debug.print("    Unexpected success!\n", .{});
        } else |err| {
            std.debug.print("    → Error: {s}\n", .{@errorName(err)});
            std.debug.print("    → errdefer NOT reached (failed before alloc)\n\n", .{});
        }
    }
    // ---------------------------------------------------------
    // defer vs errdefer comparison
    // ---------------------------------------------------------
    std.debug.print("  --- defer vs errdefer ---\n\n", .{});
    std.debug.print("    defer    → runs ALWAYS on scope exit\n", .{});
    std.debug.print("    errdefer → runs ONLY on error return\n\n", .{});
    std.debug.print("    Pattern:\n", .{});
    std.debug.print("      const resource = try acquire();\n", .{});
    std.debug.print("      errdefer release(resource);  // only on error\n", .{});
    std.debug.print("      // ... more work that might fail ...\n", .{});
    std.debug.print("      return success_with(resource); // caller owns it\n", .{});
    std.debug.print("\n✅ errdefer mastered!\n\n", .{});
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. `errdefer` = runs only when the function returns an error
// 2. `defer` = runs always (success or error)
// 3. Use errdefer for "partial construction" cleanup
// 4. Pattern: allocate → errdefer free → do more work → return
// 5. If you succeed, the CALLER is responsible for cleanup
// 6. errdefer blocks execute in REVERSE order (like defer)
//
// 🔬 EXPERIMENT:
//   - Add a second errdefer (e.g., for a signature buffer)
//     and see the reverse execution order on error
//   - Remove the errdefer and watch the memory leak
//   - Chain 3 fallible operations with 3 errdefers
// ============================================================
