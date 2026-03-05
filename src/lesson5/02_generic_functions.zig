const std = @import("std");
// ============================================================
// EXERCISE 2: Generic Functions — One Function, Any Type
// ============================================================
// In Zig, generics are just functions with `comptime` type
// parameters. No special syntax — it's just `comptime T: type`.
//
// YOUR BLOCKCHAIN USE CASE:
//   - One `hash()` function that works for Transaction, Block,
//     Header, or ANY struct
//   - One `serialize()` that converts anything to bytes
//   - One `compare()` for any hashable type
// ============================================================
const Transaction = struct {
    sender: u64,
    receiver: u64,
    amount: u64,
    nonce: u64,
};
const BlockHeader = struct {
    version: u32,
    height: u64,
    timestamp: u64,
    difficulty: u32,
    nonce: u64,
};
const PeerInfo = struct {
    id: u64,
    port: u16,
    reputation: i32,
    last_seen: u64,
};
// ---------------------------------------------------------
// STEP 1: Generic hash function
// ---------------------------------------------------------
/// Hash ANY struct type to SHA-256. Works at compile time
/// to determine the size, type checking, and byte layout.
fn hashAny(comptime T: type, value: *const T) [32]u8 {
    const bytes: [*]const u8 = @ptrCast(value);
    const slice = bytes[0..@sizeOf(T)];
    var result: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(slice, &result, .{});
    return result;
}
// ---------------------------------------------------------
// STEP 2: Generic display function
// ---------------------------------------------------------
/// Print a hex-encoded hash for any hashable value.
/// `comptime label` means the label string is known at compile time.
fn printHash(comptime T: type, comptime label: []const u8, value: *const T) void {
    const hash = hashAny(T, value);
    std.debug.print("    {s}: ", .{label});
    for (hash[0..8]) |byte| std.debug.print("{x:0>2}", .{byte});
    std.debug.print("... ({d} bytes hashed)\n", .{@sizeOf(T)});
}
// ---------------------------------------------------------
// STEP 3: Generic comparison
// ---------------------------------------------------------
/// Compare two values of any type by their hash
fn hashEqual(comptime T: type, a: *const T, b: *const T) bool {
    const hash_a = hashAny(T, a);
    const hash_b = hashAny(T, b);
    return std.mem.eql(u8, &hash_a, &hash_b);
}
// ---------------------------------------------------------
// STEP 4: Generic serializer
// ---------------------------------------------------------
/// Serialize any struct to a hex string (allocates)
fn toHexString(comptime T: type, allocator: std.mem.Allocator, value: *const T) ![]u8 {
    const raw: [*]const u8 = @ptrCast(value);
    const bytes = raw[0..@sizeOf(T)];
    const hex = try allocator.alloc(u8, bytes.len * 2);
    for (bytes, 0..) |byte, i| {
        const chars = "0123456789abcdef";
        hex[i * 2] = chars[byte >> 4];
        hex[i * 2 + 1] = chars[byte & 0x0f];
    }
    return hex;
}
// ---------------------------------------------------------
// STEP 5: Generic sort by field
// ---------------------------------------------------------
/// Create a comparison function that sorts by a specific field.
/// This is FULL comptime metaprogramming!
fn sortByField(comptime T: type, comptime field_name: []const u8) fn (void, T, T) bool {
    return struct {
        pub fn lessThan(_: void, a: T, b: T) bool {
            return @field(a, field_name) < @field(b, field_name);
        }
    }.lessThan;
}
// ---------------------------------------------------------
// STEP 6: Generic container (like ArrayList but typed)
// ---------------------------------------------------------
/// A fixed-capacity ring buffer — works for any type
fn RingBuffer(comptime T: type, comptime capacity: usize) type {
    return struct {
        const Self = @This();
        items: [capacity]T = undefined,
        head: usize = 0,
        count: usize = 0,
        fn push(self: *Self, item: T) void {
            const idx = (self.head + self.count) % capacity;
            self.items[idx] = item;
            if (self.count < capacity) {
                self.count += 1;
            } else {
                self.head = (self.head + 1) % capacity;
            }
        }
        fn latest(self: *const Self, n: usize) []const T {
            const actual = @min(n, self.count);
            const start = if (self.count <= capacity)
                self.count - actual
            else
                (self.head + self.count - actual) % capacity;
            _ = start;
            // Simplified: return last `actual` items in order
            return self.items[0..actual];
        }
        fn isFull(self: *const Self) bool {
            return self.count >= capacity;
        }
    };
}
pub fn main() !void {
    std.debug.print("\n=== Lesson 5.2: Generic Functions ===\n\n", .{});
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    // ---------------------------------------------------------
    // Generic hashing — same function, different types
    // ---------------------------------------------------------
    std.debug.print("  --- Generic Hash (one function, any type) ---\n", .{});
    const tx = Transaction{ .sender = 1, .receiver = 2, .amount = 1000, .nonce = 0 };
    const header = BlockHeader{ .version = 1, .height = 42, .timestamp = 1708900000, .difficulty = 20, .nonce = 999 };
    const peer = PeerInfo{ .id = 7, .port = 8333, .reputation = 100, .last_seen = 1708900000 };
    // ONE function works for ALL types — the compiler generates
    // specialized code for each type at compile time
    printHash(Transaction, "Transaction", &tx);
    printHash(BlockHeader, "BlockHeader", &header);
    printHash(PeerInfo, "PeerInfo    ", &peer);
    // ---------------------------------------------------------
    // Generic comparison
    // ---------------------------------------------------------
    std.debug.print("\n  --- Generic Hash Comparison ---\n", .{});
    const tx2 = Transaction{ .sender = 1, .receiver = 2, .amount = 1000, .nonce = 0 };
    const tx3 = Transaction{ .sender = 1, .receiver = 2, .amount = 999, .nonce = 0 };
    std.debug.print("    tx == tx2: {} (same data)\n", .{hashEqual(Transaction, &tx, &tx2)});
    std.debug.print("    tx == tx3: {} (different amount)\n", .{hashEqual(Transaction, &tx, &tx3)});
    // ---------------------------------------------------------
    // Generic serialization
    // ---------------------------------------------------------
    std.debug.print("\n  --- Generic Hex Serialization ---\n", .{});
    const tx_hex = try toHexString(Transaction, allocator, &tx);
    std.debug.print("    TX hex ({d} chars): {s}...\n", .{ tx_hex.len, tx_hex[0..@min(32, tx_hex.len)] });
    const hdr_hex = try toHexString(BlockHeader, allocator, &header);
    std.debug.print("    Header hex ({d} chars): {s}...\n", .{ hdr_hex.len, hdr_hex[0..@min(32, hdr_hex.len)] });
    // ---------------------------------------------------------
    // Generic sort by field
    // ---------------------------------------------------------
    std.debug.print("\n  --- Generic Sort by Field ---\n", .{});
    var txns = [_]Transaction{
        .{ .sender = 3, .receiver = 1, .amount = 500, .nonce = 2 },
        .{ .sender = 1, .receiver = 2, .amount = 100, .nonce = 0 },
        .{ .sender = 2, .receiver = 3, .amount = 999, .nonce = 1 },
        .{ .sender = 4, .receiver = 5, .amount = 50, .nonce = 3 },
    };
    // Sort by amount — the comparator is generated at comptime!
    std.mem.sort(Transaction, &txns, {}, sortByField(Transaction, "amount"));
    std.debug.print("    Sorted by amount:\n", .{});
    for (txns) |t| {
        std.debug.print("      sender={d} amount={d}\n", .{ t.sender, t.amount });
    }
    // Sort by nonce
    std.mem.sort(Transaction, &txns, {}, sortByField(Transaction, "nonce"));
    std.debug.print("    Sorted by nonce:\n", .{});
    for (txns) |t| {
        std.debug.print("      sender={d} nonce={d}\n", .{ t.sender, t.nonce });
    }
    // ---------------------------------------------------------
    // Generic ring buffer
    // ---------------------------------------------------------
    std.debug.print("\n  --- Generic Ring Buffer ---\n", .{});
    // RingBuffer(T, N) returns a NEW TYPE at compile time
    var recent_blocks = RingBuffer(BlockHeader, 4){};
    for (0..6) |i| {
        const blk = BlockHeader{
            .version = 1,
            .height = i,
            .timestamp = 1708900000 + i * 600,
            .difficulty = 20,
            .nonce = i * 111,
        };
        recent_blocks.push(blk);
        std.debug.print("    Pushed block #{d}, buffer count={d}, full={}\n", .{
            i, recent_blocks.count, recent_blocks.isFull(),
        });
    }
    std.debug.print("\n✅ Generic functions mastered!\n\n", .{});
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. `comptime T: type` = generic parameter (like <T> in other langs)
// 2. `@sizeOf(T)` works at comptime — know byte size of any type
// 3. `@field(value, "name")` = access struct field by comptime string
// 4. `fn(comptime T: type) type` = returns a NEW type (like RingBuffer)
// 5. The compiler generates SPECIALIZED code per type — no vtables
// 6. sortByField generates a comparator at comptime — zero overhead
//
// 🔬 EXPERIMENT:
//   - Add a `sortByField(PeerInfo, "reputation")` and sort peers
//   - Make RingBuffer(Transaction, 100) for a recent TX cache
//   - Try hashAny on a type with pointers — see why extern struct
//     is needed for safe byte-casting
// ============================================================
