const std = @import("std");
// ============================================================
// EXERCISE 3: Buffered I/O — High-Throughput Block Storage
// ============================================================
// Raw file.write() does a syscall PER CALL — expensive!
// BufferedWriter batches writes into a buffer, flushing to disk
// only when the buffer is full. Same for reading.
//
// YOUR BLOCKCHAIN USE CASE:
//   When syncing the chain (downloading thousands of blocks),
//   buffered I/O can be 10-100x faster than raw writes.
// ============================================================
const BlockEntry = extern struct {
    height: u64,
    timestamp: u64,
    hash: [32]u8,
    tx_count: u32,
    size_bytes: u32,
};
pub fn main() !void {
    std.debug.print("\n=== Lesson 8.3: Buffered I/O ===\n\n", .{});
    const BLOCK_COUNT: usize = 1000;
    // ---------------------------------------------------------
    // STEP 1: Write with BufferedWriter
    // ---------------------------------------------------------
    std.debug.print("  --- Buffered Write ({d} blocks) ---\n", .{BLOCK_COUNT});
    {
        const file = try std.fs.cwd().createFile("buffered_blocks.bin", .{});
        defer file.close();
        // Wrap the file writer in a buffered writer (8KB buffer)
        var buf_writer = std.io.bufferedWriter(file.writer());
        const writer = buf_writer.writer();
        const start = std.time.milliTimestamp();
        for (0..BLOCK_COUNT) |i| {
            // Create a dummy block hash
            var hash: [32]u8 = undefined;
            const height_bytes: [*]const u8 = @ptrCast(&i);
            std.crypto.hash.sha2.Sha256.hash(height_bytes[0..@sizeOf(usize)], &hash, .{});
            const entry = BlockEntry{
                .height = i,
                .timestamp = 1708900000 + i * 600,
                .hash = hash,
                .tx_count = @intCast((i % 50) + 1),
                .size_bytes = @intCast((@sizeOf(BlockEntry)) * ((i % 50) + 1)),
            };
            try writer.writeStruct(entry);
        }
        // CRITICAL: flush the remaining buffered data to disk!
        try buf_writer.flush();
        const elapsed = std.time.milliTimestamp() - start;
        const file_size = try file.getPos();
        std.debug.print("    Wrote {d} blocks ({d} bytes) in {d}ms\n", .{
            BLOCK_COUNT, file_size, elapsed,
        });
        std.debug.print("    Throughput: ~{d} blocks/ms\n", .{
            if (elapsed > 0) BLOCK_COUNT / @as(usize, @intCast(elapsed)) else BLOCK_COUNT,
        });
    }
    // ---------------------------------------------------------
    // STEP 2: Read with BufferedReader
    // ---------------------------------------------------------
    std.debug.print("\n  --- Buffered Read ---\n", .{});
    {
        const file = try std.fs.cwd().openFile("buffered_blocks.bin", .{});
        defer file.close();
        var buf_reader = std.io.bufferedReader(file.reader());
        const reader = buf_reader.reader();
        const start = std.time.milliTimestamp();
        var count: usize = 0;
        var total_txs: u64 = 0;
        var max_height: u64 = 0;
        while (true) {
            const entry = reader.readStruct(BlockEntry) catch break;
            count += 1;
            total_txs += entry.tx_count;
            if (entry.height > max_height) max_height = entry.height;
        }
        const elapsed = std.time.milliTimestamp() - start;
        std.debug.print("    Read {d} blocks in {d}ms\n", .{ count, elapsed });
        std.debug.print("    Max height: {d}\n", .{max_height});
        std.debug.print("    Total transactions: {d}\n", .{total_txs});
    }
    // ---------------------------------------------------------
    // STEP 3: Fixed buffer writer (no heap, no file)
    // ---------------------------------------------------------
    std.debug.print("\n  --- FixedBufferStream (In-Memory File) ---\n", .{});
    {
        // Write to a fixed buffer as if it were a file
        // Perfect for serialization before network send
        var buffer: [4096]u8 = undefined;
        var stream = std.io.fixedBufferStream(&buffer);
        const writer = stream.writer();
        // Write 3 block entries to the in-memory buffer
        for (0..3) |i| {
            const entry = BlockEntry{
                .height = i,
                .timestamp = 1708900000 + i * 600,
                .hash = .{@as(u8, @intCast(i))} ** 32,
                .tx_count = @intCast(i + 1),
                .size_bytes = @sizeOf(BlockEntry),
            };
            try writer.writeStruct(entry);
        }
        const bytes_written = stream.pos;
        std.debug.print("    Wrote {d} entries to memory buffer ({d} bytes)\n", .{ 3, bytes_written });
        // Read back from the buffer
        stream.pos = 0; // reset to start
        const reader = stream.reader();
        std.debug.print("    Reading back:\n", .{});
        for (0..3) |_| {
            const entry = try reader.readStruct(BlockEntry);
            std.debug.print("      Block #{d}: {d} txs\n", .{ entry.height, entry.tx_count });
        }
        std.debug.print("    (Zero heap allocs, zero file I/O!)\n", .{});
    }
    // ---------------------------------------------------------
    // STEP 4: Counting writer (measure size without writing)
    // ---------------------------------------------------------
    std.debug.print("\n  --- Counting Writer ---\n", .{});
    {
        var counting = std.io.countingWriter(std.io.null_writer);
        const writer = counting.writer();
        // "Write" 100 blocks — nothing goes to disk
        for (0..100) |i| {
            const entry = BlockEntry{
                .height = i,
                .timestamp = 1708900000,
                .hash = .{0} ** 32,
                .tx_count = 10,
                .size_bytes = 0,
            };
            try writer.writeStruct(entry);
        }
        std.debug.print("    100 blocks would take {d} bytes on disk\n", .{counting.bytes_written});
        std.debug.print("    ({d} bytes per block)\n", .{counting.bytes_written / 100});
        std.debug.print("    (Nothing was actually written!)\n", .{});
    }
    // Cleanup
    std.fs.cwd().deleteFile("buffered_blocks.bin") catch {};
    std.debug.print("\n✅ Buffered I/O mastered!\n\n", .{});
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. std.io.bufferedWriter() wraps any writer for batched I/O
// 2. ALWAYS call .flush() after writing — data may be buffered!
// 3. BufferedReader reduces syscalls for sequential reads
// 4. FixedBufferStream = in-memory "file" for serialization
// 5. CountingWriter = measure output size without writing
// 6. Composable: buffered(counting(file)) = buffered+measured
//
// 🔬 EXPERIMENT:
//   - Write 10,000 blocks with raw writer vs buffered — time both
//   - Use FixedBufferStream to serialize a block for network send
//   - Chain: bufferedWriter(countingWriter(file)) to measure while
//     buffering writes
// ============================================================
