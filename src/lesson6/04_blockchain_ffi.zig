const std = @import("std");
const c = @cImport({
    @cInclude("string.h");
    @cInclude("time.h");
});
// ============================================================
// EXERCISE 4: Hybrid Zig/C Blockchain Hasher
// ============================================================
// Build a REAL blockchain component that:
//   1. Uses extern struct for C-compatible wire format
//   2. Bridges Zig slices ↔ C pointers
//   3. Uses Zig crypto for hashing
//   4. Exports functions callable FROM C
//   5. Uses C's time() for timestamps
//
// This is the pattern you'll use in your actual blockchain node.
// ============================================================
// ===================== Wire Protocol Types ==================
/// Network protocol magic bytes (identifies our chain)
const PROTOCOL_MAGIC: u32 = 0x5343524D; // "SCRM"
/// Block header — C-compatible for wire protocol and C lib interop
const WireBlockHeader = extern struct {
    magic: u32 = PROTOCOL_MAGIC,
    version: u32,
    height: u64,
    timestamp: u64,
    prev_hash: [32]u8,
    merkle_root: [32]u8,
    difficulty: u32,
    nonce_val: u32,
    /// Cast struct to raw bytes (for C functions and wire)
    fn toBytes(self: *const WireBlockHeader) []const u8 {
        const ptr: [*]const u8 = @ptrCast(self);
        return ptr[0..@sizeOf(WireBlockHeader)];
    }
    /// Cast raw bytes back to struct (from C or wire)
    fn fromBytes(bytes: []const u8) !*const WireBlockHeader {
        if (bytes.len < @sizeOf(WireBlockHeader)) return error.BufferTooSmall;
        return @ptrCast(@alignCast(bytes.ptr));
    }
};
const WireTransaction = extern struct {
    tx_type: u8,
    _pad: [7]u8 = .{0} ** 7,
    sender: u64,
    receiver: u64,
    amount: u64,
    fee: u64,
    nonce_val: u64,
    signature: [64]u8,
};
// ===================== Hasher Engine ========================
const BlockHasher = struct {
    /// Hash a block header using SHA-256 (Zig crypto)
    fn hashHeader(header: *const WireBlockHeader) [32]u8 {
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(header.toBytes(), &hash, .{});
        return hash;
    }
    /// Double SHA-256 (Bitcoin-style)
    fn doubleHashHeader(header: *const WireBlockHeader) [32]u8 {
        const first = hashHeader(header);
        var second: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(&first, &second, .{});
        return second;
    }
    /// Hash a transaction
    fn hashTransaction(tx: *const WireTransaction) [32]u8 {
        const ptr: [*]const u8 = @ptrCast(tx);
        const bytes = ptr[0..@sizeOf(WireTransaction)];
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(bytes, &hash, .{});
        return hash;
    }
    /// Build Merkle root from transaction hashes
    fn computeMerkleRoot(tx_hashes: []const [32]u8) [32]u8 {
        if (tx_hashes.len == 0) return .{0} ** 32;
        if (tx_hashes.len == 1) return tx_hashes[0];
        // Simple pairwise hashing (non-allocating for small sets)
        var current: [64][32]u8 = undefined;
        const count = @min(tx_hashes.len, 64);
        @memcpy(current[0..count], tx_hashes[0..count]);
        var level_size = count;
        while (level_size > 1) {
            const pairs = (level_size + 1) / 2;
            for (0..pairs) |i| {
                const left = current[i * 2];
                const right = if (i * 2 + 1 < level_size) current[i * 2 + 1] else current[i * 2];
                var combined: [64]u8 = undefined;
                @memcpy(combined[0..32], &left);
                @memcpy(combined[32..64], &right);
                std.crypto.hash.sha2.Sha256.hash(&combined, &current[i], .{});
            }
            level_size = pairs;
        }
        return current[0];
    }
    /// Check if hash meets difficulty (number of leading zero bits)
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
};
// ===================== Exported C API =======================
/// EXPORT: Functions callable from C code.
/// This is how you'd expose your Zig hashers to C programs.
/// Build with: zig build-lib -dynamic blockchain_ffi.zig
/// C-callable: hash a block header
export fn sacrium_hash_header(
    header_bytes: [*]const u8,
    header_len: usize,
    output: [*]u8,
) c_int {
    if (header_len < @sizeOf(WireBlockHeader)) return -1;
    const header: *const WireBlockHeader = @ptrCast(@alignCast(header_bytes));
    const hash = BlockHasher.hashHeader(header);
    @memcpy(output[0..32], &hash);
    return 0; // success
}
/// C-callable: check difficulty
export fn sacrium_check_difficulty(
    hash: [*]const u8,
    difficulty: u32,
) c_int {
    const hash_arr: *const [32]u8 = @ptrCast(hash);
    return if (BlockHasher.meetsDifficulty(hash_arr.*, difficulty)) 1 else 0;
}
/// C-callable: get current timestamp
export fn sacrium_timestamp() u64 {
    const ts: c.time_t = c.time(null);
    return @intCast(ts);
}
// ===================== Mining Simulation =====================
fn mineBlock(header: *WireBlockHeader, max_attempts: u32) !void {
    const start_time = std.time.milliTimestamp();
    var attempt: u32 = 0;
    while (attempt < max_attempts) : (attempt += 1) {
        header.nonce_val = attempt;
        const hash = BlockHasher.doubleHashHeader(header);
        if (BlockHasher.meetsDifficulty(hash, header.difficulty)) {
            const elapsed = std.time.milliTimestamp() - start_time;
            std.debug.print("    ⛏️  BLOCK MINED!\n", .{});
            std.debug.print("    Nonce:    {d}\n", .{attempt});
            std.debug.print("    Attempts: {d}\n", .{attempt + 1});
            std.debug.print("    Time:     {d}ms\n", .{elapsed});
            std.debug.print("    Hash:     ", .{});
            for (hash) |byte| std.debug.print("{x:0>2}", .{byte});
            std.debug.print("\n", .{});
            return;
        }
    }
    return error.MaxAttemptsReached;
}
pub fn main() !void {
    std.debug.print("\n=== Lesson 6.4: Hybrid Zig/C Blockchain Hasher ===\n\n", .{});
    // ---------------------------------------------------------
    // Wire format validation
    // ---------------------------------------------------------
    std.debug.print("  --- Wire Format ---\n", .{});
    std.debug.print("    WireBlockHeader: {d} bytes\n", .{@sizeOf(WireBlockHeader)});
    std.debug.print("    WireTransaction: {d} bytes\n", .{@sizeOf(WireTransaction)});
    std.debug.print("    Magic bytes:     0x{x:0>8} (\"SCRM\")\n", .{PROTOCOL_MAGIC});
    // ---------------------------------------------------------
    // Create genesis block using C timestamp
    // ---------------------------------------------------------
    std.debug.print("\n  --- Genesis Block (C timestamp) ---\n", .{});
    const timestamp: u64 = @intCast(c.time(null));
    var genesis = WireBlockHeader{
        .version = 1,
        .height = 0,
        .timestamp = timestamp,
        .prev_hash = .{0} ** 32, // genesis has no parent
        .merkle_root = .{0} ** 32,
        .difficulty = 8, // easy for demo
        .nonce_val = 0,
    };
    std.debug.print("    Height:    {d}\n", .{genesis.height});
    std.debug.print("    Timestamp: {d} (from C's time())\n", .{genesis.timestamp});
    // ---------------------------------------------------------
    // Hash some transactions
    // ---------------------------------------------------------
    std.debug.print("\n  --- Transaction Hashing ---\n", .{});
    var txns: [4]WireTransaction = undefined;
    var tx_hashes: [4][32]u8 = undefined;
    for (&txns, 0..) |*tx, i| {
        tx.* = WireTransaction{
            .tx_type = 0,
            .sender = i + 1,
            .receiver = i + 10,
            .amount = (i + 1) * 1000,
            .fee = (i + 1) * 10,
            .nonce_val = i,
            .signature = .{0} ** 64,
        };
        tx_hashes[i] = BlockHasher.hashTransaction(tx);
        std.debug.print("    TX{d}: {d} → {d}, {d} tokens, hash=", .{
            i, tx.sender, tx.receiver, tx.amount,
        });
        for (tx_hashes[i][0..4]) |byte| std.debug.print("{x:0>2}", .{byte});
        std.debug.print("...\n", .{});
    }
    // ---------------------------------------------------------
    // Compute Merkle root
    // ---------------------------------------------------------
    std.debug.print("\n  --- Merkle Root ---\n", .{});
    genesis.merkle_root = BlockHasher.computeMerkleRoot(&tx_hashes);
    std.debug.print("    Merkle root: ", .{});
    for (genesis.merkle_root[0..8]) |byte| std.debug.print("{x:0>2}", .{byte});
    std.debug.print("...\n", .{});
    // ---------------------------------------------------------
    // Mine the genesis block
    // ---------------------------------------------------------
    std.debug.print("\n  --- Mining Genesis Block (difficulty={d}) ---\n", .{genesis.difficulty});
    mineBlock(&genesis, 100_000) catch {
        std.debug.print("    Mining failed within 100k attempts\n", .{});
    };
    // ---------------------------------------------------------
    // Wire serialization round-trip
    // ---------------------------------------------------------
    std.debug.print("\n  --- Wire Serialization Round-Trip ---\n", .{});
    // Serialize (struct → bytes)
    const wire_bytes = genesis.toBytes();
    std.debug.print("    Serialized: {d} bytes\n", .{wire_bytes.len});
    // Copy to a separate buffer (simulating network receive)
    var recv_buf: [256]u8 = undefined;
    _ = c.memcpy(&recv_buf, wire_bytes.ptr, wire_bytes.len);
    // Deserialize (bytes → struct)
    const received = try WireBlockHeader.fromBytes(&recv_buf);
    std.debug.print("    Deserialized: magic=0x{x:0>8} version={d} height={d}\n", .{
        received.magic, received.version, received.height,
    });
    // Verify magic
    if (received.magic == PROTOCOL_MAGIC) {
        std.debug.print("    ✅ Protocol magic verified — this is our chain!\n", .{});
    } else {
        std.debug.print("    ❌ Unknown protocol!\n", .{});
    }
    // Verify hash
    const original_hash = BlockHasher.doubleHashHeader(&genesis);
    const received_hash = BlockHasher.doubleHashHeader(received);
    const hashes_match = std.mem.eql(u8, &original_hash, &received_hash);
    std.debug.print("    Hash round-trip: {s}\n", .{if (hashes_match) "✅ MATCH" else "❌ MISMATCH"});
    // ---------------------------------------------------------
    // C-exported API demonstration
    // ---------------------------------------------------------
    std.debug.print("\n  --- Exported C API Demo ---\n", .{});
    var api_output: [32]u8 = undefined;
    const api_result = sacrium_hash_header(
        genesis.toBytes().ptr,
        genesis.toBytes().len,
        &api_output,
    );
    std.debug.print("    sacrium_hash_header() returned: {d}\n", .{api_result});
    std.debug.print("    Hash via C API: ", .{});
    for (api_output[0..8]) |byte| std.debug.print("{x:0>2}", .{byte});
    std.debug.print("...\n", .{});
    const ts = sacrium_timestamp();
    std.debug.print("    sacrium_timestamp(): {d}\n", .{ts});
    // ---------------------------------------------------------
    // Summary
    // ---------------------------------------------------------
    std.debug.print("\n  ╔════════════════════════════════════════════════╗\n", .{});
    std.debug.print("  ║  LESSON 6 COMPLETE — FFI Summary              ║\n", .{});
    std.debug.print("  ╠════════════════════════════════════════════════╣\n", .{});
    std.debug.print("  ║  ✅ @cImport/@cInclude for C headers          ║\n", .{});
    std.debug.print("  ║  ✅ extern struct for wire-compatible layout   ║\n", .{});
    std.debug.print("  ║  ✅ packed struct for compact formats          ║\n", .{});
    std.debug.print("  ║  ✅ Zig slice ↔ C pointer bridging            ║\n", .{});
    std.debug.print("  ║  ✅ export fn for C-callable functions         ║\n", .{});
    std.debug.print("  ║  ✅ Zig crypto + C time in one binary          ║\n", .{});
    std.debug.print("  ╚════════════════════════════════════════════════╝\n\n", .{});
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. extern struct = deterministic wire format for C and network
// 2. export fn = make Zig functions callable from C programs
// 3. .toBytes() / .fromBytes() = safe struct ↔ bytes conversion
// 4. C's time() works alongside Zig's std.crypto seamlessly
// 5. Protocol magic bytes verify chain identity on the wire
// 6. This pattern → build your node core in Zig, expose C API
//
// 🔬 EXPERIMENT:
//   - Build as a shared library: zig build-lib -dynamic
//   - Call sacrium_hash_header from a C program
//   - Add sacrium_verify_block that validates a full block
//   - Link libsodium and use its ed25519 for real signatures:
//     zig run file.zig -lsodium
//   - Replace SHA-256 with BLAKE3 and compare mining speed
// ============================================================
