const std = @import("std");
const c = @cImport({
    @cInclude("string.h");
    @cInclude("stdlib.h");
    @cInclude("time.h");
    @cInclude("stdio.h");
});
// ============================================================
// EXERCISE 1: libc Basics — Using C Standard Library from Zig
// ============================================================
// Zig can call ANY C function, starting with libc itself.
// This exercise shows how Zig types map to C types and
// how to safely bridge between them.
//
// YOUR BLOCKCHAIN USE CASE:
//   - Use C's time functions for block timestamps
//   - Use memcpy/memset for fast buffer operations
//   - Call printf for C-compatible logging
//   - Foundation for calling crypto libs in Exercise 3
// ============================================================
// Run with: zig run 01_libc_basics.zig -lc
pub fn main() !void {
    std.debug.print("\n=== Lesson 6.1: libc Basics from Zig ===\n\n", .{});
    // ---------------------------------------------------------
    // STEP 1: C's memset / memcpy
    // ---------------------------------------------------------
    std.debug.print("  --- C memset / memcpy ---\n", .{});
    var block_hash: [32]u8 = undefined;
    var prev_hash: [32]u8 = undefined;
    // Call C's memset to zero-initialize (like genesis block hash)
    _ = c.memset(&block_hash, 0, 32);
    // Call C's memset to fill with a pattern
    _ = c.memset(&prev_hash, 0xAB, 32);
    std.debug.print("    block_hash (zeroed): ", .{});
    for (block_hash[0..8]) |byte| std.debug.print("{x:0>2}", .{byte});
    std.debug.print("...\n", .{});
    std.debug.print("    prev_hash (0xAB):    ", .{});
    for (prev_hash[0..8]) |byte| std.debug.print("{x:0>2}", .{byte});
    std.debug.print("...\n", .{});
    // Copy prev_hash into block_hash using C's memcpy
    _ = c.memcpy(&block_hash, &prev_hash, 32);
    std.debug.print("    After memcpy:        ", .{});
    for (block_hash[0..8]) |byte| std.debug.print("{x:0>2}", .{byte});
    std.debug.print("...\n", .{});
    // ---------------------------------------------------------
    // STEP 2: C's memcmp (memory comparison)
    // ---------------------------------------------------------
    std.debug.print("\n  --- C memcmp ---\n", .{});
    const cmp_result = c.memcmp(&block_hash, &prev_hash, 32);
    std.debug.print("    memcmp(block, prev) = {d}", .{cmp_result});
    if (cmp_result == 0) {
        std.debug.print(" (hashes MATCH ✅)\n", .{});
    } else {
        std.debug.print(" (hashes DIFFER ❌)\n", .{});
    }
    // Compare with all-zeros
    var zeros: [32]u8 = undefined;
    _ = c.memset(&zeros, 0, 32);
    const cmp_zero = c.memcmp(&block_hash, &zeros, 32);
    std.debug.print("    memcmp(block, zeros) = {d} (non-zero = different)\n", .{cmp_zero});
    // ---------------------------------------------------------
    // STEP 3: C's time functions (block timestamps)
    // ---------------------------------------------------------
    std.debug.print("\n  --- C time() — Block Timestamps ---\n", .{});
    const timestamp: c.time_t = c.time(null);
    std.debug.print("    Current Unix timestamp: {d}\n", .{timestamp});
    // Convert to human-readable using localtime
    const tm_ptr = c.localtime(&timestamp);
    if (tm_ptr) |tm| {
        std.debug.print("    Year:  {d}\n", .{tm.*.tm_year + 1900});
        std.debug.print("    Month: {d}\n", .{tm.*.tm_mon + 1});
        std.debug.print("    Day:   {d}\n", .{tm.*.tm_mday});
        std.debug.print("    Hour:  {d}\n", .{tm.*.tm_hour});
        std.debug.print("    Min:   {d}\n", .{tm.*.tm_min});
    }
    // ---------------------------------------------------------
    // STEP 4: C's printf (C-compatible output)
    // ---------------------------------------------------------
    std.debug.print("\n  --- C printf ---\n", .{});
    // C printf with format strings — useful for C library debug output
    _ = c.printf("    [C printf] Block height: %d, timestamp: %ld\n", @as(c_int, 42), timestamp);
    _ = c.printf("    [C printf] Hash prefix: 0x%02x%02x%02x%02x\n", @as(c_int, block_hash[0]), @as(c_int, block_hash[1]), @as(c_int, block_hash[2]), @as(c_int, block_hash[3]));
    // ---------------------------------------------------------
    // STEP 5: C's strlen with Zig strings
    // ---------------------------------------------------------
    std.debug.print("\n  --- C strlen + Zig strings ---\n", .{});
    // Zig string literals are null-terminated, so they work with C
    const node_name: [*:0]const u8 = "sacrium-node-01";
    const name_len = c.strlen(node_name);
    std.debug.print("    node name: \"{s}\"\n", .{node_name[0..name_len]});
    std.debug.print("    C strlen: {d}\n", .{name_len});
    // ---------------------------------------------------------
    // STEP 6: C malloc/free (but prefer Zig allocators!)
    // ---------------------------------------------------------
    std.debug.print("\n  --- C malloc/free (avoid in production!) ---\n", .{});
    const size: usize = 64;
    const c_ptr: ?*anyopaque = c.malloc(size);
    if (c_ptr) |ptr| {
        // Cast C void* to typed Zig pointer
        const buf: [*]u8 = @ptrCast(@alignCast(ptr));
        _ = c.memset(ptr, 0xFF, size);
        std.debug.print("    C malloc'd {d} bytes at {*}\n", .{ size, buf });
        std.debug.print("    First bytes: {x:0>2} {x:0>2} {x:0>2} {x:0>2}\n", .{
            buf[0], buf[1], buf[2], buf[3],
        });
        c.free(ptr);
        std.debug.print("    Freed ✅ (but prefer Zig's page_allocator!)\n", .{});
    }
    // ---------------------------------------------------------
    // STEP 7: Comparing Zig vs C approaches
    // ---------------------------------------------------------
    std.debug.print("\n  --- Zig vs C Comparison ---\n\n", .{});
    std.debug.print("    ┌──────────────┬──────────────────────┬──────────────────────┐\n", .{});
    std.debug.print("    │ Operation    │ C Way                │ Zig Way              │\n", .{});
    std.debug.print("    ├──────────────┼──────────────────────┼──────────────────────┤\n", .{});
    std.debug.print("    │ Zero memory  │ memset(buf, 0, n)    │ @memset(&buf, 0)     │\n", .{});
    std.debug.print("    │ Copy memory  │ memcpy(dst, src, n)  │ @memcpy(dst, src)    │\n", .{});
    std.debug.print("    │ Compare      │ memcmp(a, b, n)      │ std.mem.eql(u8,a,b)  │\n", .{});
    std.debug.print("    │ Allocate     │ malloc(n)            │ allocator.alloc(T,n) │\n", .{});
    std.debug.print("    │ Timestamp    │ time(NULL)           │ std.time.timestamp() │\n", .{});
    std.debug.print("    │ String len   │ strlen(s)            │ s.len                │\n", .{});
    std.debug.print("    └──────────────┴──────────────────────┴──────────────────────┘\n", .{});
    std.debug.print("\n    Use C when: linking C libraries that expect C types\n", .{});
    std.debug.print("    Use Zig when: writing new code (safer, cleaner)\n", .{});
    std.debug.print("\n✅ libc basics complete!\n\n", .{});
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. @cImport(@cInclude("header.h")) imports C functions
// 2. C functions are called with c.function_name()
// 3. Zig types auto-convert to C types in most cases
// 4. [*:0]const u8 = Zig string that C functions accept
// 5. C's void* → Zig: @ptrCast(@alignCast(ptr))
// 6. Prefer Zig builtins (@memset, @memcpy) over C versions
//    UNLESS you're interfacing with C libraries
//
// 🔬 EXPERIMENT:
//   - Use c.snprintf to format a block header as a C string
//   - Call c.qsort to sort an array of transactions
//   - Use c.getenv to read a BLOCKCHAIN_DATA_DIR env var
// ============================================================
