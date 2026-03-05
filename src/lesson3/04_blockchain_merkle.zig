const std = @import("std");
// ============================================================
// EXERCISE 4: Blockchain Merkle Tree — Pointers In Practice
// ============================================================
// A Merkle Tree is a binary hash tree used in EVERY blockchain.
// Each leaf = hash of a transaction. Parent = hash(left + right).
// The root hash is stored in the BlockHeader.
//
// This exercise uses:
//   - *MerkleNode pointers for tree navigation
//   - []const u8 slices for hash data
//   - Allocator for dynamic tree construction (from Lesson 2!)
//
// This is the REAL algorithm Bitcoin & Ethereum use.
// ============================================================
const MerkleNode = struct {
    hash: [32]u8,
    left: ?*const MerkleNode,
    right: ?*const MerkleNode,
    depth: u32,
    label: []const u8,
    fn isLeaf(self: *const MerkleNode) bool {
        return self.left == null and self.right == null;
    }
    fn display(self: *const MerkleNode, indent: usize) void {
        // Print indentation
        for (0..indent) |_| std.debug.print("  ", .{});
        // Print hash (first 8 bytes)
        std.debug.print("[D{d}] {s} = ", .{ self.depth, self.label });
        for (self.hash[0..4]) |byte| std.debug.print("{x:0>2}", .{byte});
        std.debug.print("...", .{});
        if (self.isLeaf()) {
            std.debug.print(" (leaf)\n", .{});
        } else {
            std.debug.print("\n", .{});
            if (self.left) |left| left.display(indent + 1);
            if (self.right) |right| right.display(indent + 1);
        }
    }
};
/// Hash two child hashes together to produce parent hash
fn hashPair(left: *const [32]u8, right: *const [32]u8) [32]u8 {
    var combined: [64]u8 = undefined;
    @memcpy(combined[0..32], left);
    @memcpy(combined[32..64], right);
    var result: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&combined, &result, .{});
    return result;
}
/// Hash raw transaction data to create a leaf hash
fn hashTransaction(tx_data: []const u8) [32]u8 {
    var result: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(tx_data, &result, .{});
    return result;
}
/// Build a Merkle tree from transaction data slices
fn buildMerkleTree(
    allocator: std.mem.Allocator,
    tx_data: []const []const u8,
) !*const MerkleNode {
    if (tx_data.len == 0) return error.EmptyTransactions;
    // ---------------------------------------------------------
    // Step 1: Create leaf nodes from transaction hashes
    // ---------------------------------------------------------
    var current_level = try allocator.alloc(*const MerkleNode, tx_data.len);
    for (tx_data, 0..) |data, i| {
        const node = try allocator.create(MerkleNode);
        // Create label
        const label_buf = try allocator.alloc(u8, 8);
        _ = std.fmt.bufPrint(label_buf, "TX{d:<5}", .{i}) catch "TX?????";
        node.* = .{
            .hash = hashTransaction(data),
            .left = null,
            .right = null,
            .depth = 0,
            .label = label_buf,
        };
        current_level[i] = node;
    }
    // ---------------------------------------------------------
    // Step 2: Build tree bottom-up, pairing nodes
    // ---------------------------------------------------------
    var depth: u32 = 1;
    while (current_level.len > 1) {
        // If odd number, duplicate the last element (standard Merkle behavior)
        const effective_len = current_level.len;
        const pair_count = (effective_len + 1) / 2;
        var next_level = try allocator.alloc(*const MerkleNode, pair_count);
        for (0..pair_count) |i| {
            const left_idx = i * 2;
            const right_idx = if (left_idx + 1 < effective_len) left_idx + 1 else left_idx;
            const left = current_level[left_idx];
            const right = current_level[right_idx];
            const parent = try allocator.create(MerkleNode);
            const label_buf = try allocator.alloc(u8, 8);
            _ = std.fmt.bufPrint(label_buf, "N{d}_{d:<3}", .{ depth, i }) catch "N??????";
            parent.* = .{
                .hash = hashPair(&left.hash, &right.hash),
                .left = left,
                .right = right,
                .depth = depth,
                .label = label_buf,
            };
            next_level[i] = parent;
        }
        current_level = next_level;
        depth += 1;
    }
    return current_level[0];
}
/// Verify that a transaction is included in the Merkle tree
/// (simplified — real impl uses a Merkle proof/path)
fn verifyInclusion(root: *const MerkleNode, tx_hash: *const [32]u8) bool {
    if (root.isLeaf()) {
        return std.mem.eql(u8, &root.hash, tx_hash);
    }
    var found = false;
    if (root.left) |left| {
        if (verifyInclusion(left, tx_hash)) found = true;
    }
    if (root.right) |right| {
        if (verifyInclusion(right, tx_hash)) found = true;
    }
    return found;
}
pub fn main() !void {
    std.debug.print("\n=== Lesson 3.4: Blockchain Merkle Tree ===\n\n", .{});
    // Use arena — whole tree freed at once (Lesson 2 pattern!)
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    // ---------------------------------------------------------
    // Simulate block transactions
    // ---------------------------------------------------------
    const transactions = [_][]const u8{
        "Alice sends 100 to Bob",
        "Charlie sends 50 to Dave",
        "Eve sends 200 to Frank",
        "Grace sends 75 to Heidi",
        "Ivan sends 300 to Judy",
        "Karl sends 10 to Larry",
    };
    std.debug.print("  📦 Block contains {d} transactions:\n", .{transactions.len});
    for (transactions, 0..) |tx, i| {
        const hash = hashTransaction(tx);
        std.debug.print("    TX{d}: \"{s}\"\n", .{ i, tx });
        std.debug.print("         hash: ", .{});
        for (hash[0..8]) |byte| std.debug.print("{x:0>2}", .{byte});
        std.debug.print("...\n", .{});
    }
    // ---------------------------------------------------------
    // Build the Merkle tree
    // ---------------------------------------------------------
    std.debug.print("\n  🌳 Building Merkle Tree...\n\n", .{});
    const root = try buildMerkleTree(allocator, &transactions);
    std.debug.print("  Tree structure:\n", .{});
    root.display(2);
    std.debug.print("\n  🏔️  Merkle Root: ", .{});
    for (root.hash) |byte| std.debug.print("{x:0>2}", .{byte});
    std.debug.print("\n", .{});
    std.debug.print("  This goes into the BlockHeader!\n", .{});
    // ---------------------------------------------------------
    // Verify transaction inclusion
    // ---------------------------------------------------------
    std.debug.print("\n  🔍 Inclusion Verification:\n", .{});
    // Verify a real transaction
    const real_hash = hashTransaction(transactions[2]);
    const real_found = verifyInclusion(root, &real_hash);
    std.debug.print("    TX2 (\"Eve sends 200...\"): {s}\n", .{
        if (real_found) "✅ FOUND in tree" else "❌ NOT found",
    });
    // Verify a fake transaction
    const fake_hash = hashTransaction("FAKE: Mallory steals 9999");
    const fake_found = verifyInclusion(root, &fake_hash);
    std.debug.print("    Fake TX:                   {s}\n", .{
        if (fake_found) "✅ FOUND (BAD!)" else "❌ NOT found (correct!)",
    });
    // ---------------------------------------------------------
    // Demonstrate: changing one TX changes the root
    // ---------------------------------------------------------
    std.debug.print("\n  🔐 Tamper Detection:\n", .{});
    var tampered = transactions;
    tampered[0] = "Alice sends 999999 to Bob"; // tampered!
    const tampered_root = try buildMerkleTree(allocator, &tampered);
    const roots_match = std.mem.eql(u8, &root.hash, &tampered_root.hash);
    std.debug.print("    Original root:  ", .{});
    for (root.hash[0..8]) |byte| std.debug.print("{x:0>2}", .{byte});
    std.debug.print("...\n", .{});
    std.debug.print("    Tampered root:  ", .{});
    for (tampered_root.hash[0..8]) |byte| std.debug.print("{x:0>2}", .{byte});
    std.debug.print("...\n", .{});
    std.debug.print("    Roots match: {} {s}\n", .{
        roots_match,
        if (roots_match) "⚠️ PROBLEM!" else "✅ Tamper detected!",
    });
    std.debug.print("\n✅ Merkle tree complete!\n", .{});
    std.debug.print("   Concepts used: *MerkleNode, []const u8, ?*const T, ArenaAllocator\n\n", .{});
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. `*const MerkleNode` = pointer to a tree node (read-only)
// 2. `?*const MerkleNode` = OPTIONAL pointer (null = no child)
// 3. `[]const []const u8` = slice of slices (array of strings)
// 4. Tree nodes point to children — classic pointer-based trees
// 5. Arena allocator = perfect for tree lifetime management
// 6. std.mem.eql() verifies hash equality (tamper detection!)
//
// 🔬 EXPERIMENT:
//   - Add 7 transactions (odd number) — see duplicate last leaf
//   - Implement a Merkle PROOF: return the path from leaf to root
//   - Store the Merkle root in a BlockHeader (from Lesson 1)
//   - Try making the tree mutable — add *MerkleNode (not const)
// ============================================================
