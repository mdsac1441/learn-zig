const std = @import("std");

// Packed structs guarantee the exact memory layout.
// No hidden padding, just raw bytes.
pub const Transaction = extern struct {
    nonce: u64, // 8 bytes (unsigned 64-bit integer)
    amount: u64, // 8 bytes
    // In a real chain, we'd use a fixed-size byte array for pubkeys/addresses
    // For now, let's pretend an address is just a 32-byte array.
    receiver: [32]u8,
    sender: [32]u8,
};

pub fn main() !void {
    // 1. Create a transaction
    var my_tx = Transaction{
        .nonce = 1,
        .amount = 100,
        .receiver = [_]u8{0} ** 32, // Fill the 32-byte array with zeros
        .sender = [_]u8{0} ** 32,
    };

    // 2. View the struct as raw bytes (Serialization!)
    // We cast the pointer to the struct into a slice of raw bytes.
    // This is instant and takes 0 extra memory.
    const raw_bytes = std.mem.asBytes(&my_tx);

    std.debug.print("Transaction is exactly {} bytes long.\n", .{raw_bytes.len});

    // 3. Hash the raw bytes using SHA-256 (Zig has this built-in!)
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(raw_bytes, &hash, .{});

    // 4. Print the hash as a hex string
    std.debug.print("Transaction Hash: {x}\n", .{hash});

    // 5. Simulate a Block (an array of transactions)
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    // Create an Arena on top of the GPA
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit(); // Frees ALL arena memory at once!
    const alloc = arena.allocator();
    // Simulate receiving a block with 1000 transactions
    const block_txs = try alloc.alloc(Transaction, 10_000);
    // Fill transactions
    for (block_txs, 0..) |*tx, i| {
        tx.* = Transaction{
            .nonce = @intCast(i),
            .amount = 50,
            .receiver = [_]u8{0} ** 32,
            .sender = [_]u8{0} ** 32,
        };
    }
    std.debug.print("Block has {} transactions\n", .{block_txs.len});
    std.debug.print("Transaction 500 nonce: {}\n", .{block_txs[500].nonce});
    // Create a vector of 4 i32 elements
    const a: @Vector(4, i32) = .{ 1, 2, 3, 4 };
    const b: @Vector(4, i32) = .{ 5, 6, 7, 8 };

    // Perform parallel addition
    const c = a + b; // Result: { 6, 8, 10, 12 }
    std.debug.print("{any}\n", .{c});
    std.debug.print("{any}\n", .{std.simd.rotateElementsLeft(a, 1)});
    std.debug.print("{any}\n", .{std.simd.rotateElementsRight(a, 1)});
}
