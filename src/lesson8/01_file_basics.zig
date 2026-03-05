const std = @import("std");
// ============================================================
// EXERCISE 1: File Basics — Open, Write, Read, Seek
// ============================================================
// Zig's std.fs gives you low-level file operations with
// explicit error handling. No hidden buffering, no exceptions.
//
// YOUR BLOCKCHAIN USE CASE:
//   Writing genesis block data, reading config files,
//   appending log entries — the foundation for all storage.
// ============================================================
pub fn main() !void {
    std.debug.print("\n=== Lesson 8.1: File Basics ===\n\n", .{});
    const allocator = std.heap.page_allocator;
    // ---------------------------------------------------------
    // STEP 1: Create and write to a file
    // ---------------------------------------------------------
    std.debug.print("  --- Create & Write ---\n", .{});
    {
        // Open file for writing (create if not exists, truncate if exists)
        const file = try std.fs.cwd().createFile("genesis.dat", .{});
        defer file.close();
        // Write raw bytes
        const genesis_msg = "SACRIUM GENESIS BLOCK v1.0\n";
        const bytes_written = try file.write(genesis_msg);
        std.debug.print("    Wrote {d} bytes to genesis.dat\n", .{bytes_written});
        // Write more data
        const timestamp_str = "Timestamp: 1708900000\n";
        _ = try file.write(timestamp_str);
        const difficulty_str = "Difficulty: 24\n";
        _ = try file.write(difficulty_str);
        // Get final file size
        const pos = try file.getPos();
        std.debug.print("    File size: {d} bytes\n", .{pos});
    }
    // ---------------------------------------------------------
    // STEP 2: Read entire file
    // ---------------------------------------------------------
    std.debug.print("\n  --- Read Entire File ---\n", .{});
    {
        const file = try std.fs.cwd().openFile("genesis.dat", .{});
        defer file.close();
        // Read entire file into memory (max 1MB)
        const contents = try file.readToEndAlloc(allocator, 1024 * 1024);
        defer allocator.free(contents);
        std.debug.print("    Read {d} bytes:\n", .{contents.len});
        std.debug.print("    ────────────────\n{s}    ────────────────\n", .{contents});
    }
    // ---------------------------------------------------------
    // STEP 3: Read line by line
    // ---------------------------------------------------------
    std.debug.print("\n  --- Read Line by Line ---\n", .{});
    {
        const file = try std.fs.cwd().openFile("genesis.dat", .{});
        defer file.close();
        var buf_reader = std.io.bufferedReader(file.reader());
        var line_buf: [256]u8 = undefined;
        var line_num: u32 = 0;
        while (buf_reader.reader().readUntilDelimiterOrEof(&line_buf, '\n')) |maybe_line| {
            if (maybe_line) |line| {
                line_num += 1;
                std.debug.print("    Line {d}: \"{s}\"\n", .{ line_num, line });
            } else break;
        } else |err| {
            std.debug.print("    Read error: {s}\n", .{@errorName(err)});
        }
    }
    // ---------------------------------------------------------
    // STEP 4: Seek — random access
    // ---------------------------------------------------------
    std.debug.print("\n  --- Seek (Random Access) ---\n", .{});
    {
        const file = try std.fs.cwd().openFile("genesis.dat", .{});
        defer file.close();
        // Read from the beginning
        var header: [7]u8 = undefined;
        _ = try file.read(&header);
        std.debug.print("    First 7 bytes: \"{s}\"\n", .{header});
        // Seek to position 8
        try file.seekTo(8);
        var mid: [7]u8 = undefined;
        _ = try file.read(&mid);
        std.debug.print("    Bytes 8-14:    \"{s}\"\n", .{mid});
        // Seek from end
        try file.seekFromEnd(-4);
        var tail: [3]u8 = undefined;
        _ = try file.read(&tail);
        std.debug.print("    Last 3 bytes:  \"{s}\"\n", .{tail});
        // Get current position
        const pos = try file.getPos();
        std.debug.print("    Current pos:   {d}\n", .{pos});
    }
    // ---------------------------------------------------------
    // STEP 5: Append to file
    // ---------------------------------------------------------
    std.debug.print("\n  --- Append ---\n", .{});
    {
        // Open for appending (doesn't truncate)
        const file = try std.fs.cwd().openFile("genesis.dat", .{ .mode = .write_only });
        defer file.close();
        // Seek to end
        try file.seekFromEnd(0);
        _ = try file.write("Nonce: 0\n");
        std.debug.print("    Appended 'Nonce: 0' to genesis.dat\n", .{});
    }
    // ---------------------------------------------------------
    // STEP 6: File metadata
    // ---------------------------------------------------------
    std.debug.print("\n  --- File Metadata ---\n", .{});
    {
        const stat = try std.fs.cwd().statFile("genesis.dat");
        std.debug.print("    Size:     {d} bytes\n", .{stat.size});
        std.debug.print("    Kind:     {s}\n", .{@tagName(stat.kind)});
    }
    // ---------------------------------------------------------
    // STEP 7: Directory operations
    // ---------------------------------------------------------
    std.debug.print("\n  --- Directory Operations ---\n", .{});
    {
        // Create a directory for blockchain data
        std.fs.cwd().makeDir("chain_data") catch |err| switch (err) {
            error.PathAlreadyExists => std.debug.print("    chain_data/ already exists\n", .{}),
            else => return err,
        };
        // Create a file inside the directory
        const idx_file = try std.fs.cwd().createFile("chain_data/index.dat", .{});
        defer idx_file.close();
        _ = try idx_file.write("BLOCK_INDEX_V1\n");
        std.debug.print("    Created chain_data/index.dat\n", .{});
    }
    // ---------------------------------------------------------
    // STEP 8: Delete / cleanup
    // ---------------------------------------------------------
    std.debug.print("\n  --- Cleanup ---\n", .{});
    {
        // Delete individual files
        try std.fs.cwd().deleteFile("chain_data/index.dat");
        std.debug.print("    Deleted chain_data/index.dat\n", .{});
        // Delete directory (must be empty)
        try std.fs.cwd().deleteDir("chain_data");
        std.debug.print("    Deleted chain_data/\n", .{});
        // Keep genesis.dat for next exercises
        std.debug.print("    Kept genesis.dat for next exercises\n", .{});
    }
    std.debug.print("\n✅ File basics complete!\n\n", .{});
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. std.fs.cwd() = current working directory handle
// 2. createFile = create/truncate, openFile = open existing
// 3. defer file.close() = ALWAYS close files
// 4. file.seekTo(pos) = random access (critical for block index)
// 5. file.readToEndAlloc() = read entire file (needs allocator)
// 6. bufferedReader for line-by-line reading
//
// 🔬 EXPERIMENT:
//   - Write 1000 lines and use seekTo to read line #500
//   - Create a nested directory structure for block storage
//   - Try opening a non-existent file — handle the error
// ============================================================
