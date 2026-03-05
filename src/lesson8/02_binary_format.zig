const std = @import("std");
// ============================================================
// EXERCISE 2: Binary Format — Read/Write Structs as Bytes
// ============================================================
// Blockchain data is stored as BINARY, not text. This exercise
// writes and reads structs directly to/from files — the same
// pattern used by Bitcoin's blk*.dat files.
//
// YOUR BLOCKCHAIN USE CASE:
//   Write blocks to disk as raw bytes — no JSON, no encoding
//   overhead. Fast to write, fast to read, deterministic size.
// ============================================================
const MAGIC: u32 = 0x5343524D; // "SCRM"
const FILE_VERSION: u8 = 1;
/// File header — written once at the start of a block file
const FileHeader = extern struct {
    magic: u32 = MAGIC,
    version: u8 = FILE_VERSION,
    _reserved: [3]u8 = .{ 0, 0, 0 },
    block_count: u64 = 0,
    created_timestamp: u64,
};
/// Block record — stored sequentially in the file
const BlockRecord = extern struct {
    height: u64,
    timestamp: u64,
    prev_hash: [32]u8,
    merkle_root: [32]u8,
    difficulty: u32,
    nonce_val: u32,
    tx_count: u32,
    _pad: u32 = 0,
    fn hash(self: *const BlockRecord) [32]u8 {
        const ptr: [*]const u8 = @ptrCast(self);
        var result: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(ptr[0..@sizeOf(BlockRecord)], &result, .{});
        return result;
    }
    fn display(self: *const BlockRecord) void {
        std.debug.print("    Block #{d}: ts={d} diff={d} nonce={d} txs={d} hash=", .{
            self.height, self.timestamp, self.difficulty, self.nonce_val, self.tx_count,
        });
        const h = self.hash();
        for (h[0..4]) |byte| std.debug.print("{x:0>2}", .{byte});
        std.debug.print("...\n", .{});
    }
};
/// Transaction record
const TxRecord = extern struct {
    sender: u64,
    receiver: u64,
    amount: u64,
    fee: u64,
    nonce_val: u64,
};
const BLOCK_FILE = "blocks.bin";
pub fn main() !void {
    std.debug.print("\n=== Lesson 8.2: Binary Format ===\n\n", .{});
    // ---------------------------------------------------------
    // STEP 1: Write binary file with header + blocks
    // ---------------------------------------------------------
    std.debug.print("  --- Write Binary Block File ---\n", .{});
    {
        const file = try std.fs.cwd().createFile(BLOCK_FILE, .{});
        defer file.close();
        const writer = file.writer();
        // Write file header
        var file_header = FileHeader{
            .created_timestamp = 1708900000,
        };
        file_header.block_count = 5; // we'll write 5 blocks
        try writer.writeStruct(file_header);
        std.debug.print("    Wrote file header: {d} bytes\n", .{@sizeOf(FileHeader)});
        // Write 5 blocks
        for (0..5) |i| {
            var block = BlockRecord{
                .height = i,
                .timestamp = 1708900000 + i * 600,
                .prev_hash = .{0} ** 32,
                .merkle_root = .{0} ** 32,
                .difficulty = 20,
                .nonce_val = @intCast(i * 12345),
                .tx_count = @intCast(i + 1),
            };
            // Set prev_hash to previous block's hash (chain linking)
            if (i > 0) {
                var prev_block = BlockRecord{
                    .height = i - 1,
                    .timestamp = 1708900000 + (i - 1) * 600,
                    .prev_hash = .{0} ** 32,
                    .merkle_root = .{0} ** 32,
                    .difficulty = 20,
                    .nonce_val = @intCast((i - 1) * 12345),
                    .tx_count = @intCast(i),
                };
                if (i >= 2) {
                    @memset(&prev_block.prev_hash, @intCast(i - 1));
                }
                block.prev_hash = prev_block.hash();
            }
            try writer.writeStruct(block);
            // Write transactions for this block
            for (0..block.tx_count) |j| {
                const tx = TxRecord{
                    .sender = j + 1,
                    .receiver = j + 10,
                    .amount = (j + 1) * 1000,
                    .fee = (j + 1) * 10,
                    .nonce_val = j,
                };
                try writer.writeStruct(tx);
            }
        }
        const total_size = try file.getPos();
        std.debug.print("    Total file size: {d} bytes\n", .{total_size});
        std.debug.print("    FileHeader: {d} bytes\n", .{@sizeOf(FileHeader)});
        std.debug.print("    BlockRecord: {d} bytes each\n", .{@sizeOf(BlockRecord)});
        std.debug.print("    TxRecord: {d} bytes each\n", .{@sizeOf(TxRecord)});
    }
    // ---------------------------------------------------------
    // STEP 2: Read and verify the binary file
    // ---------------------------------------------------------
    std.debug.print("\n  --- Read Binary Block File ---\n", .{});
    {
        const file = try std.fs.cwd().openFile(BLOCK_FILE, .{});
        defer file.close();
        const reader = file.reader();
        // Read file header
        const file_header = try reader.readStruct(FileHeader);
        // Verify magic
        if (file_header.magic != MAGIC) {
            std.debug.print("    ❌ Invalid file magic!\n", .{});
            return;
        }
        std.debug.print("    ✅ Magic verified: 0x{x:0>8}\n", .{file_header.magic});
        std.debug.print("    Version: {d}\n", .{file_header.version});
        std.debug.print("    Blocks: {d}\n", .{file_header.block_count});
        std.debug.print("    Created: {d}\n", .{file_header.created_timestamp});
        // Read each block
        std.debug.print("\n    --- Blocks ---\n", .{});
        for (0..file_header.block_count) |_| {
            const block = try reader.readStruct(BlockRecord);
            block.display();
            // Skip past the transactions for this block
            for (0..block.tx_count) |_| {
                _ = try reader.readStruct(TxRecord);
            }
        }
    }
    // ---------------------------------------------------------
    // STEP 3: Random access — read block by height
    // ---------------------------------------------------------
    std.debug.print("\n  --- Random Access (Read Block #3) ---\n", .{});
    {
        const file = try std.fs.cwd().openFile(BLOCK_FILE, .{});
        defer file.close();
        const reader = file.reader();
        // Skip file header
        try file.seekTo(@sizeOf(FileHeader));
        // To do true random access, we'd need an index file.
        // For now, scan sequentially to block #3:
        var target_height: u64 = 3;
        _ = &target_height;
        for (0..5) |_| {
            const block = try reader.readStruct(BlockRecord);
            if (block.height == 3) {
                std.debug.print("    Found block #3!\n", .{});
                block.display();
                // Read its transactions
                std.debug.print("    Transactions:\n", .{});
                for (0..block.tx_count) |j| {
                    const tx = try reader.readStruct(TxRecord);
                    std.debug.print("      TX{d}: {d} → {d}, {d} tokens\n", .{
                        j, tx.sender, tx.receiver, tx.amount,
                    });
                }
                break;
            } else {
                // Skip transactions for this block
                for (0..block.tx_count) |_| {
                    _ = try reader.readStruct(TxRecord);
                }
            }
        }
    }
    // ---------------------------------------------------------
    // STEP 4: Verify data integrity
    // ---------------------------------------------------------
    std.debug.print("\n  --- Data Integrity Check ---\n", .{});
    {
        const file = try std.fs.cwd().openFile(BLOCK_FILE, .{});
        defer file.close();
        const stat = try file.stat();
        std.debug.print("    File size on disk: {d} bytes\n", .{stat.size});
        // Verify we can hash the entire file
        const reader = file.reader();
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        var buf: [4096]u8 = undefined;
        while (true) {
            const n = try reader.read(&buf);
            if (n == 0) break;
            hasher.update(buf[0..n]);
        }
        var file_hash: [32]u8 = undefined;
        hasher.final(&file_hash);
        std.debug.print("    File SHA-256: ", .{});
        for (file_hash[0..8]) |byte| std.debug.print("{x:0>2}", .{byte});
        std.debug.print("...\n", .{});
        std.debug.print("    (Use this to verify block data hasn't been tampered)\n", .{});
    }
    // Cleanup
    std.fs.cwd().deleteFile(BLOCK_FILE) catch {};
    std.fs.cwd().deleteFile("genesis.dat") catch {};
    std.debug.print("\n    Cleaned up temporary files.\n", .{});
    std.debug.print("\n✅ Binary format mastered!\n\n", .{});
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. writer.writeStruct(s) = write struct as raw bytes to file
// 2. reader.readStruct(T) = read bytes and interpret as struct T
// 3. extern struct guarantees C-compatible byte layout on disk
// 4. File magic bytes (0x5343524D) identify your chain's files
// 5. Variable-length blocks need an INDEX for random access
// 6. Hash entire file = integrity verification (tamper detect)
//
// 🔬 EXPERIMENT:
//   - Open blocks.bin in a hex editor — see the raw bytes
//   - Try reading with wrong struct type — see garbled data
//   - Add a CRC32 checksum per block for corruption detection
//   - Change a byte in the file and detect it via file hash
// ============================================================
