const std = @import("std");
// ============================================================
// EXERCISE 4: Blockchain Block Store — Full Storage Engine
// ============================================================
// A REAL block storage engine that:
//   1. Appends blocks to a data file (blocks.dat)
//   2. Maintains an index file (blocks.idx) for O(1) lookup
//   3. Supports read-by-height in constant time
//   4. Verifies chain integrity on load
//
// This is the pattern used by Bitcoin Core (blk*.dat + blkindex)
// and Ethereum (ancient flat files).
// ============================================================
const MAGIC: u32 = 0x5343524D;
const BlockHeader = extern struct {
    magic: u32 = MAGIC,
    height: u64,
    timestamp: u64,
    prev_hash: [32]u8,
    merkle_root: [32]u8,
    difficulty: u32,
    nonce_val: u32,
    tx_count: u32,
    _pad: u32 = 0,
    fn hash(self: *const BlockHeader) [32]u8 {
        const ptr: [*]const u8 = @ptrCast(self);
        var result: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(ptr[0..@sizeOf(BlockHeader)], &result, .{});
        return result;
    }
};
const TxRecord = extern struct {
    sender: u64,
    receiver: u64,
    amount: u64,
    fee: u64,
};
/// Index entry — maps block height to file offset
const IndexEntry = extern struct {
    height: u64,
    file_offset: u64,
    block_hash: [32]u8,
};
// ===================== Block Store ==========================
const BlockStore = struct {
    data_path: []const u8,
    index_path: []const u8,
    block_count: u64,
    last_hash: [32]u8,
    fn init(data_path: []const u8, index_path: []const u8) BlockStore {
        return .{
            .data_path = data_path,
            .index_path = index_path,
            .block_count = 0,
            .last_hash = .{0} ** 32,
        };
    }
    /// Append a block to the store
    fn appendBlock(self: *BlockStore, header: *BlockHeader, txns: []const TxRecord) !void {
        // Open data file for appending
        const data_file = try std.fs.cwd().createFile(self.data_path, .{
            .truncate = false,
        });
        defer data_file.close();
        // Seek to end for appending
        const file_offset = try data_file.getEndPos();
        try data_file.seekTo(file_offset);
        var buf_writer = std.io.bufferedWriter(data_file.writer());
        const writer = buf_writer.writer();
        // Link to previous block
        header.prev_hash = self.last_hash;
        header.height = self.block_count;
        header.magic = MAGIC;
        // Write block header
        try writer.writeStruct(header.*);
        // Write transactions
        for (txns) |tx| {
            try writer.writeStruct(tx);
        }
        try buf_writer.flush();
        // Update index
        const block_hash = header.hash();
        try self.appendIndex(self.block_count, file_offset, block_hash);
        // Update state
        self.last_hash = block_hash;
        self.block_count += 1;
    }
    /// Append an entry to the index file
    fn appendIndex(self: *BlockStore, height: u64, offset: u64, hash: [32]u8) !void {
        const idx_file = try std.fs.cwd().createFile(self.index_path, .{
            .truncate = false,
        });
        defer idx_file.close();
        try idx_file.seekFromEnd(0);
        const entry = IndexEntry{
            .height = height,
            .file_offset = offset,
            .block_hash = hash,
        };
        const writer = idx_file.writer();
        try writer.writeStruct(entry);
    }
    /// Read a block by height using the index (O(1) seek!)
    fn readBlock(self: *BlockStore, height: u64) !struct { header: BlockHeader, txns_offset: u64 } {
        // Read index to get file offset
        const idx_file = try std.fs.cwd().openFile(self.index_path, .{});
        defer idx_file.close();
        // Seek directly to the index entry for this height
        const idx_offset = height * @sizeOf(IndexEntry);
        try idx_file.seekTo(idx_offset);
        const idx_entry = try idx_file.reader().readStruct(IndexEntry);
        if (idx_entry.height != height) {
            return error.IndexCorrupted;
        }
        // Read block from data file at the offset
        const data_file = try std.fs.cwd().openFile(self.data_path, .{});
        defer data_file.close();
        try data_file.seekTo(idx_entry.file_offset);
        const header = try data_file.reader().readStruct(BlockHeader);
        if (header.magic != MAGIC) {
            return error.InvalidMagic;
        }
        return .{
            .header = header,
            .txns_offset = idx_entry.file_offset + @sizeOf(BlockHeader),
        };
    }
    /// Read transactions for a block
    fn readTransactions(self: *BlockStore, offset: u64, count: u32, allocator: std.mem.Allocator) ![]TxRecord {
        const data_file = try std.fs.cwd().openFile(self.data_path, .{});
        defer data_file.close();
        try data_file.seekTo(offset);
        const reader = data_file.reader();
        const txns = try allocator.alloc(TxRecord, count);
        errdefer allocator.free(txns);
        for (txns) |*tx| {
            tx.* = try reader.readStruct(TxRecord);
        }
        return txns;
    }
    /// Verify the entire chain integrity
    fn verifyChain(self: *BlockStore) !bool {
        const data_file = try std.fs.cwd().openFile(self.data_path, .{});
        defer data_file.close();
        var buf_reader = std.io.bufferedReader(data_file.reader());
        const reader = buf_reader.reader();
        var expected_prev_hash: [32]u8 = .{0} ** 32;
        var blocks_verified: u64 = 0;
        for (0..self.block_count) |i| {
            const header = reader.readStruct(BlockHeader) catch break;
            // Verify magic
            if (header.magic != MAGIC) {
                std.debug.print("    ❌ Block #{d}: invalid magic\n", .{i});
                return false;
            }
            // Verify chain link
            if (!std.mem.eql(u8, &header.prev_hash, &expected_prev_hash)) {
                std.debug.print("    ❌ Block #{d}: broken chain link!\n", .{i});
                return false;
            }
            // Skip transactions
            for (0..header.tx_count) |_| {
                _ = reader.readStruct(TxRecord) catch break;
            }
            expected_prev_hash = header.hash();
            blocks_verified += 1;
        }
        std.debug.print("    Verified {d}/{d} blocks\n", .{ blocks_verified, self.block_count });
        return blocks_verified == self.block_count;
    }
    /// Get storage statistics
    fn getStats(self: *BlockStore) !struct { data_size: u64, index_size: u64, blocks: u64 } {
        const data_stat = try std.fs.cwd().statFile(self.data_path);
        const idx_stat = try std.fs.cwd().statFile(self.index_path);
        return .{
            .data_size = data_stat.size,
            .index_size = idx_stat.size,
            .blocks = self.block_count,
        };
    }
};
pub fn main() !void {
    std.debug.print("\n=== Lesson 8.4: Blockchain Block Store ===\n\n", .{});
    const allocator = std.heap.page_allocator;
    // Clean up any previous run
    std.fs.cwd().deleteFile("sacrium_blocks.dat") catch {};
    std.fs.cwd().deleteFile("sacrium_blocks.idx") catch {};
    var store = BlockStore.init("sacrium_blocks.dat", "sacrium_blocks.idx");
    // ==========================================================
    // Write blocks to the store
    // ==========================================================
    std.debug.print("  ⛏️  Writing blocks to disk...\n\n", .{});
    const block_data = [_]struct { difficulty: u32, nonce: u32, tx_count: u32 }{
        .{ .difficulty = 8, .nonce = 0, .tx_count = 1 }, // Genesis
        .{ .difficulty = 8, .nonce = 42, .tx_count = 3 },
        .{ .difficulty = 12, .nonce = 999, .tx_count = 5 },
        .{ .difficulty = 12, .nonce = 1337, .tx_count = 2 },
        .{ .difficulty = 16, .nonce = 88888, .tx_count = 7 },
        .{ .difficulty = 16, .nonce = 54321, .tx_count = 4 },
        .{ .difficulty = 20, .nonce = 100000, .tx_count = 10 },
        .{ .difficulty = 20, .nonce = 200000, .tx_count = 6 },
    };
    for (block_data) |bd| {
        var header = BlockHeader{
            .height = 0, // set by store
            .timestamp = 1708900000 + store.block_count * 600,
            .prev_hash = .{0} ** 32, // set by store
            .merkle_root = .{@as(u8, @intCast(store.block_count))} ** 32,
            .difficulty = bd.difficulty,
            .nonce_val = bd.nonce,
            .tx_count = bd.tx_count,
        };
        // Create transactions
        var txns_buf: [10]TxRecord = undefined;
        for (0..bd.tx_count) |j| {
            txns_buf[j] = TxRecord{
                .sender = j + 1,
                .receiver = j + 100,
                .amount = (j + 1) * 1000,
                .fee = (j + 1) * 10,
            };
        }
        try store.appendBlock(&header, txns_buf[0..bd.tx_count]);
        std.debug.print("    Block #{d}: {d} txns, difficulty={d}\n", .{
            store.block_count - 1, bd.tx_count, bd.difficulty,
        });
    }
    // ==========================================================
    // Storage stats
    // ==========================================================
    std.debug.print("\n  📊 Storage Stats:\n", .{});
    {
        const stats = try store.getStats();
        std.debug.print("    Data file:  {d} bytes\n", .{stats.data_size});
        std.debug.print("    Index file: {d} bytes\n", .{stats.index_size});
        std.debug.print("    Blocks:     {d}\n", .{stats.blocks});
        std.debug.print("    Avg block:  {d} bytes\n", .{stats.data_size / stats.blocks});
    }
    // ==========================================================
    // Random access read — O(1) by height!
    // ==========================================================
    std.debug.print("\n  🔍 Random Access Read:\n\n", .{});
    const test_heights = [_]u64{ 0, 3, 7 };
    for (test_heights) |height| {
        const result = try store.readBlock(height);
        std.debug.print("    Block #{d}:\n", .{height});
        std.debug.print("      Timestamp:  {d}\n", .{result.header.timestamp});
        std.debug.print("      Difficulty: {d}\n", .{result.header.difficulty});
        std.debug.print("      Nonce:      {d}\n", .{result.header.nonce_val});
        std.debug.print("      TX count:   {d}\n", .{result.header.tx_count});
        const block_hash = result.header.hash();
        std.debug.print("      Hash:       ", .{});
        for (block_hash[0..6]) |byte| std.debug.print("{x:0>2}", .{byte});
        std.debug.print("...\n", .{});
        // Read transactions
        const txns = try store.readTransactions(result.txns_offset, result.header.tx_count, allocator);
        defer allocator.free(txns);
        for (txns, 0..) |tx, i| {
            std.debug.print("        TX{d}: {d}→{d} amount={d}\n", .{ i, tx.sender, tx.receiver, tx.amount });
        }
        std.debug.print("\n", .{});
    }
    // ==========================================================
    // Verify chain integrity
    // ==========================================================
    std.debug.print("  🔗 Chain Integrity Verification:\n", .{});
    {
        const valid = try store.verifyChain();
        if (valid) {
            std.debug.print("    ✅ Chain is VALID — all blocks linked correctly!\n", .{});
        } else {
            std.debug.print("    ❌ Chain is BROKEN!\n", .{});
        }
    }
    // ==========================================================
    // Summary
    // ==========================================================
    std.debug.print("\n  ╔════════════════════════════════════════════════╗\n", .{});
    std.debug.print("  ║  LESSON 8 COMPLETE — File I/O Summary         ║\n", .{});
    std.debug.print("  ╠════════════════════════════════════════════════╣\n", .{});
    std.debug.print("  ║  ✅ File create, read, write, seek, append    ║\n", .{});
    std.debug.print("  ║  ✅ Binary struct serialization (writeStruct) ║\n", .{});
    std.debug.print("  ║  ✅ Buffered I/O for throughput               ║\n", .{});
    std.debug.print("  ║  ✅ Index file for O(1) block lookup          ║\n", .{});
    std.debug.print("  ║  ✅ Chain integrity verification              ║\n", .{});
    std.debug.print("  ╚════════════════════════════════════════════════╝\n\n", .{});
    // Cleanup
    std.fs.cwd().deleteFile("sacrium_blocks.dat") catch {};
    std.fs.cwd().deleteFile("sacrium_blocks.idx") catch {};
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. Separate DATA file (.dat) and INDEX file (.idx)
// 2. Index maps height → file offset for O(1) random access
// 3. Append-only data file = simple, crash-resilient
// 4. BufferedWriter for high-throughput during chain sync
// 5. Chain verification: walk blocks and verify prev_hash links
// 6. This is Bitcoin Core's storage architecture (simplified!)
//
// 🔬 EXPERIMENT:
//   - Write 10,000 blocks and measure: sequential vs random read
//   - Add a block cache (HashMap(height, BlockHeader))
//   - Implement block pruning (delete old blocks, keep index)
//   - Add a Write-Ahead Log (WAL) for crash recovery
//   - Corrupt one byte in blocks.dat — watch verifyChain fail
// ============================================================
