const std = @import("std");
// ============================================================
// EXERCISE 1: Comptime Basics — Compile-Time Computation
// ============================================================
// `comptime` means "evaluate this at compile time". The result
// is baked into the binary — zero runtime cost.
//
// YOUR BLOCKCHAIN USE CASE:
//   - Pre-compute lookup tables for cryptographic operations
//   - Validate protocol constants at compile time
//   - Generate optimized code paths per block version
// ============================================================
// ---------------------------------------------------------
// STEP 1: comptime variables
// ---------------------------------------------------------
// These are evaluated at COMPILE TIME — they're constants
// baked into the binary, not computed when the program runs.
const MAX_BLOCK_SIZE: u32 = 1024 * 1024; // 1 MB
const MAX_TX_PER_BLOCK: u32 = 2048;
const GENESIS_TIMESTAMP: u64 = 1708900000;
// Comptime function — the compiler runs this during build
fn comptime_fibonacci(comptime n: u32) u64 {
    // This loop runs at COMPILE TIME
    var a: u64 = 0;
    var b: u64 = 1;
    for (0..n) |_| {
        const temp = b;
        b = a + b;
        a = temp;
    }
    return a;
}
// ---------------------------------------------------------
// STEP 2: comptime lookup tables
// ---------------------------------------------------------
/// Pre-compute difficulty adjustment table at compile time
/// Maps difficulty level (0-15) to required hash prefix zeros
fn computeDifficultyTable() [16]u8 {
    var table: [16]u8 = undefined;
    for (0..16) |i| {
        // Each difficulty level requires i+1 leading zero bits
        table[i] = @intCast(i + 1);
    }
    return table;
}
// This entire table is computed at compile time!
const difficulty_table = computeDifficultyTable();
// ---------------------------------------------------------
// STEP 3: comptime validation (compile-time assertions)
// ---------------------------------------------------------
const BlockHeader = extern struct {
    version: u32,
    prev_hash: [32]u8,
    merkle_root: [32]u8,
    timestamp: u64,
    difficulty: u32,
    nonce: u64,
    // Compile-time size check — if the struct layout changes,
    // this FAILS THE BUILD, not at runtime!
    comptime {
        const size = @sizeOf(BlockHeader);
        if (size > 256) {
            @compileError("BlockHeader too large for wire format!");
        }
    }
};
const Transaction = extern struct {
    sender: [32]u8,
    receiver: [32]u8,
    amount: u64,
    fee: u64,
    nonce: u64,
    signature: [64]u8,
    comptime {
        // Ensure Transaction fits in a single network packet
        if (@sizeOf(Transaction) > 512) {
            @compileError("Transaction too large for single packet!");
        }
    }
};
// ---------------------------------------------------------
// STEP 4: comptime string formatting
// ---------------------------------------------------------
/// Creates a version string at compile time
fn comptimeVersionString(comptime major: u32, comptime minor: u32, comptime patch: u32) []const u8 {
    return std.fmt.comptimePrint("sacrium-v{d}.{d}.{d}", .{ major, minor, patch });
}
const VERSION = comptimeVersionString(1, 0, 0);
const PROTOCOL_NAME = comptimeVersionString(0, 9, 1);
// ---------------------------------------------------------
// STEP 5: comptime block — complex compile-time logic
// ---------------------------------------------------------
/// Creates a bitmask lookup for valid opcodes (like an EVM)
const valid_opcodes = blk: {
    var mask: [256]bool = .{false} ** 256;
    // Define valid opcodes for our blockchain VM
    const opcodes = [_]u8{
        0x00, // STOP
        0x01, // ADD
        0x02, // MUL
        0x03, // SUB
        0x10, // LT
        0x11, // GT
        0x14, // EQ
        0x20, // SHA3
        0x30, // ADDRESS
        0x31, // BALANCE
        0x54, // SLOAD
        0x55, // SSTORE
        0xF1, // CALL
        0xF3, // RETURN
        0xFD, // REVERT
        0xFF, // SELFDESTRUCT
    };
    for (opcodes) |op| {
        mask[op] = true;
    }
    break :blk mask;
};
pub fn main() !void {
    std.debug.print("\n=== Lesson 5.1: Comptime Basics ===\n\n", .{});
    // ---------------------------------------------------------
    // Show comptime constants
    // ---------------------------------------------------------
    std.debug.print("  --- Comptime Constants ---\n", .{});
    std.debug.print("    MAX_BLOCK_SIZE:   {d} bytes ({d} MB)\n", .{ MAX_BLOCK_SIZE, MAX_BLOCK_SIZE / (1024 * 1024) });
    std.debug.print("    MAX_TX_PER_BLOCK: {d}\n", .{MAX_TX_PER_BLOCK});
    std.debug.print("    GENESIS_TIME:     {d}\n", .{GENESIS_TIMESTAMP});
    // ---------------------------------------------------------
    // Comptime fibonacci
    // ---------------------------------------------------------
    std.debug.print("\n  --- Comptime Fibonacci ---\n", .{});
    // These values are computed at compile time — the binary
    // just contains the results!
    std.debug.print("    fib(10) = {d}\n", .{comptime comptime_fibonacci(10)});
    std.debug.print("    fib(20) = {d}\n", .{comptime comptime_fibonacci(20)});
    std.debug.print("    fib(50) = {d}\n", .{comptime comptime_fibonacci(50)});
    std.debug.print("    (All computed at compile time — zero runtime cost!)\n", .{});
    // ---------------------------------------------------------
    // Difficulty lookup table
    // ---------------------------------------------------------
    std.debug.print("\n  --- Difficulty Lookup Table (comptime) ---\n", .{});
    for (difficulty_table, 0..) |required_zeros, level| {
        std.debug.print("    Difficulty {d:>2} → need {d:>2} leading zero bits\n", .{ level, required_zeros });
    }
    // ---------------------------------------------------------
    // Struct size validation
    // ---------------------------------------------------------
    std.debug.print("\n  --- Struct Sizes (validated at comptime) ---\n", .{});
    std.debug.print("    BlockHeader:  {d} bytes ✅ (< 256 enforced)\n", .{@sizeOf(BlockHeader)});
    std.debug.print("    Transaction:  {d} bytes ✅ (< 512 enforced)\n", .{@sizeOf(Transaction)});
    std.debug.print("    If you add a field that makes it too big → BUILD FAILS\n", .{});
    // ---------------------------------------------------------
    // Version strings
    // ---------------------------------------------------------
    std.debug.print("\n  --- Comptime Strings ---\n", .{});
    std.debug.print("    VERSION:  {s}\n", .{VERSION});
    std.debug.print("    PROTOCOL: {s}\n", .{PROTOCOL_NAME});
    // ---------------------------------------------------------
    // Opcode validation (using comptime lookup)
    // ---------------------------------------------------------
    std.debug.print("\n  --- Opcode Validation (comptime table) ---\n", .{});
    const test_opcodes = [_]u8{ 0x01, 0x02, 0x20, 0x42, 0xF1, 0xAA, 0xFF };
    for (test_opcodes) |op| {
        const status = if (valid_opcodes[op]) "✅ VALID" else "❌ UNKNOWN";
        std.debug.print("    opcode 0x{x:0>2}: {s}\n", .{ op, status });
    }
    std.debug.print("    (Lookup table generated at compile time!)\n", .{});
    // ---------------------------------------------------------
    // inline for — unrolled at comptime
    // ---------------------------------------------------------
    std.debug.print("\n  --- inline for (comptime unrolling) ---\n", .{});
    const hash_algos = [_][]const u8{ "SHA-256", "BLAKE3", "Keccak-256", "RIPEMD-160" };
    inline for (hash_algos, 0..) |algo, i| {
        std.debug.print("    [{d}] {s}\n", .{ i, algo });
    }
    std.debug.print("    (Loop unrolled at compile time — no branch!)\n", .{});
    std.debug.print("\n✅ Comptime basics complete!\n\n", .{});
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. `comptime` vars/blocks run during compilation → zero cost
// 2. `comptime {}` inside structs = compile-time assertions
// 3. `@compileError()` = fail the BUILD if something is wrong
// 4. Lookup tables computed at comptime = fast runtime checks
// 5. `inline for` unrolls loops at compile time
// 6. `std.fmt.comptimePrint` = format strings at compile time
//
// 🔬 EXPERIMENT:
//   - Add a field to BlockHeader that pushes it over 256 bytes
//     and watch the compile error
//   - Add more opcodes to the valid set and re-run
//   - Try comptime_fibonacci(100) — see compile-time overflow!
// ============================================================
