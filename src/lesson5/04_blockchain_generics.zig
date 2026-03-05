const std = @import("std");
// ============================================================
// EXERCISE 4: Generic Blockchain Ledger — comptime In Practice
// ============================================================
// Build a GENERIC LEDGER that works for any token type.
// Your hybrid chain might support:
//   - FungibleToken (like ETH/SOL)
//   - NFToken (unique assets)
//   - StakeToken (validator stakes)
//
// ONE ledger implementation handles them ALL — powered by comptime.
// ============================================================
// ===================== Token Types ==========================
const FungibleToken = struct {
    symbol: [8]u8,
    amount: u64,
    decimals: u8,
    fn display(self: *const FungibleToken) void {
        // Find actual length of symbol
        var len: usize = 0;
        for (self.symbol) |c| {
            if (c == 0) break;
            len += 1;
        }
        std.debug.print("{d} {s}", .{ self.amount, self.symbol[0..len] });
    }
};
const NFToken = struct {
    collection_id: u64,
    token_id: u64,
    rarity: u8, // 1=common, 2=rare, 3=epic, 4=legendary
    fn display(self: *const NFToken) void {
        const rarity_name = switch (self.rarity) {
            1 => "Common",
            2 => "Rare",
            3 => "Epic",
            4 => "Legendary",
            else => "Unknown",
        };
        std.debug.print("NFT#{d} (collection {d}, {s})", .{ self.token_id, self.collection_id, rarity_name });
    }
};
const StakeToken = struct {
    validator_id: u64,
    staked_amount: u64,
    epoch_staked: u64,
    slashable: bool,
    fn display(self: *const StakeToken) void {
        std.debug.print("{d} staked to validator #{d} (epoch {d}{s})", .{
            self.staked_amount,
            self.validator_id,
            self.epoch_staked,
            if (self.slashable) ", SLASHABLE" else "",
        });
    }
};
// ===================== Generic Ledger =======================
/// TypedLedger(T) — a generic ledger for any token type.
/// The compiler generates a SEPARATE, OPTIMIZED implementation
/// for each token type you use. Zero runtime overhead.
fn TypedLedger(comptime T: type) type {
    // Compile-time validation: T must have a display method
    if (!@hasDecl(T, "display")) {
        @compileError(@typeName(T) ++ " must have a display() method");
    }
    return struct {
        const Self = @This();
        const MAX_ENTRIES = 256;
        const Entry = struct {
            owner: u64,
            token: T,
            active: bool,
        };
        entries: [MAX_ENTRIES]Entry = undefined,
        count: usize = 0,
        total_operations: u64 = 0,
        /// Record a new token assignment
        fn mint(self: *Self, owner: u64, token: T) !void {
            if (self.count >= MAX_ENTRIES) return error.LedgerFull;
            self.entries[self.count] = .{
                .owner = owner,
                .token = token,
                .active = true,
            };
            self.count += 1;
            self.total_operations += 1;
        }
        /// Transfer a token from one owner to another (by index)
        fn transfer(self: *Self, index: usize, new_owner: u64) !void {
            if (index >= self.count) return error.InvalidIndex;
            if (!self.entries[index].active) return error.InactiveEntry;
            self.entries[index].owner = new_owner;
            self.total_operations += 1;
        }
        /// Burn (deactivate) a token
        fn burn(self: *Self, index: usize) !void {
            if (index >= self.count) return error.InvalidIndex;
            if (!self.entries[index].active) return error.InactiveEntry;
            self.entries[index].active = false;
            self.total_operations += 1;
        }
        /// Get all tokens owned by a specific account
        fn getBalance(self: *const Self, owner: u64) usize {
            var count: usize = 0;
            for (self.entries[0..self.count]) |entry| {
                if (entry.owner == owner and entry.active) count += 1;
            }
            return count;
        }
        /// Display the ledger
        fn display(self: *const Self, comptime name: []const u8) void {
            std.debug.print("\n    ┌─ {s} Ledger ({s}) ──────────────\n", .{ name, @typeName(T) });
            std.debug.print("    │  Entries: {d}, Operations: {d}\n", .{ self.count, self.total_operations });
            std.debug.print("    ├───────────────────────────────────\n", .{});
            for (self.entries[0..self.count], 0..) |entry, i| {
                const status = if (entry.active) "✅" else "🔥";
                std.debug.print("    │  [{d:>2}] {s} owner={d:<4} → ", .{ i, status, entry.owner });
                entry.token.display();
                std.debug.print("\n", .{});
            }
            std.debug.print("    └───────────────────────────────────\n", .{});
        }
        /// Hash the entire ledger state
        fn stateHash(self: *const Self) [32]u8 {
            var hasher = std.crypto.hash.sha2.Sha256.init(.{});
            for (self.entries[0..self.count]) |entry| {
                if (entry.active) {
                    const bytes: [*]const u8 = @ptrCast(&entry);
                    hasher.update(bytes[0..@sizeOf(Entry)]);
                }
            }
            var result: [32]u8 = undefined;
            hasher.final(&result);
            return result;
        }
    };
}
// ===================== Comptime Reporting ===================
/// Generate a type report at compile time
fn typeReport(comptime T: type) []const u8 {
    return std.fmt.comptimePrint(
        "{s}: {d} bytes, {d} fields",
        .{
            @typeName(T),
            @sizeOf(T),
            @typeInfo(T).@"struct".fields.len,
        },
    );
}
pub fn main() !void {
    std.debug.print("\n=== Lesson 5.4: Generic Blockchain Ledger ===\n\n", .{});
    // ---------------------------------------------------------
    // Comptime type report
    // ---------------------------------------------------------
    std.debug.print("  --- Type Report (computed at compile time) ---\n", .{});
    std.debug.print("    {s}\n", .{comptime typeReport(FungibleToken)});
    std.debug.print("    {s}\n", .{comptime typeReport(NFToken)});
    std.debug.print("    {s}\n", .{comptime typeReport(StakeToken)});
    // ---------------------------------------------------------
    // Fungible Token Ledger
    // ---------------------------------------------------------
    std.debug.print("\n  === Fungible Token Ledger ===\n", .{});
    var token_ledger = TypedLedger(FungibleToken){};
    // Helper to create symbol
    const make_symbol = struct {
        fn f(s: []const u8) [8]u8 {
            var sym: [8]u8 = .{0} ** 8;
            @memcpy(sym[0..s.len], s);
            return sym;
        }
    }.f;
    try token_ledger.mint(1, .{ .symbol = make_symbol("SCR"), .amount = 10000, .decimals = 18 });
    try token_ledger.mint(2, .{ .symbol = make_symbol("SCR"), .amount = 5000, .decimals = 18 });
    try token_ledger.mint(1, .{ .symbol = make_symbol("USDS"), .amount = 250, .decimals = 6 });
    try token_ledger.mint(3, .{ .symbol = make_symbol("SCR"), .amount = 7500, .decimals = 18 });
    // Transfer from account 2 to account 1
    try token_ledger.transfer(1, 1);
    token_ledger.display("Fungible");
    std.debug.print("\n    Account 1 balance: {d} tokens\n", .{token_ledger.getBalance(1)});
    std.debug.print("    Account 2 balance: {d} tokens\n", .{token_ledger.getBalance(2)});
    // ---------------------------------------------------------
    // NFT Ledger
    // ---------------------------------------------------------
    std.debug.print("\n  === NFT Ledger ===\n", .{});
    var nft_ledger = TypedLedger(NFToken){};
    try nft_ledger.mint(1, .{ .collection_id = 1, .token_id = 1, .rarity = 4 }); // Legendary!
    try nft_ledger.mint(2, .{ .collection_id = 1, .token_id = 2, .rarity = 1 });
    try nft_ledger.mint(1, .{ .collection_id = 2, .token_id = 1, .rarity = 3 });
    try nft_ledger.mint(3, .{ .collection_id = 1, .token_id = 3, .rarity = 2 });
    // Burn the common one
    try nft_ledger.burn(1);
    nft_ledger.display("NFT");
    // ---------------------------------------------------------
    // Stake Ledger
    // ---------------------------------------------------------
    std.debug.print("\n  === Stake Ledger ===\n", .{});
    var stake_ledger = TypedLedger(StakeToken){};
    try stake_ledger.mint(10, .{ .validator_id = 1, .staked_amount = 100000, .epoch_staked = 42, .slashable = true });
    try stake_ledger.mint(11, .{ .validator_id = 1, .staked_amount = 50000, .epoch_staked = 43, .slashable = true });
    try stake_ledger.mint(12, .{ .validator_id = 2, .staked_amount = 75000, .epoch_staked = 44, .slashable = false });
    stake_ledger.display("Staking");
    // ---------------------------------------------------------
    // State hashing — each ledger can hash its state
    // ---------------------------------------------------------
    std.debug.print("\n  === State Hashes ===\n", .{});
    const token_hash = token_ledger.stateHash();
    const nft_hash = nft_ledger.stateHash();
    const stake_hash = stake_ledger.stateHash();
    std.debug.print("    Token state:  ", .{});
    for (token_hash[0..8]) |b| std.debug.print("{x:0>2}", .{b});
    std.debug.print("...\n", .{});
    std.debug.print("    NFT state:    ", .{});
    for (nft_hash[0..8]) |b| std.debug.print("{x:0>2}", .{b});
    std.debug.print("...\n", .{});
    std.debug.print("    Stake state:  ", .{});
    for (stake_hash[0..8]) |b| std.debug.print("{x:0>2}", .{b});
    std.debug.print("...\n", .{});
    // ---------------------------------------------------------
    // Summary box
    // ---------------------------------------------------------
    std.debug.print("\n  ╔════════════════════════════════════════════════╗\n", .{});
    std.debug.print("  ║  LESSON 5 COMPLETE — Comptime Summary         ║\n", .{});
    std.debug.print("  ╠════════════════════════════════════════════════╣\n", .{});
    std.debug.print("  ║  ✅ comptime blocks & constants                ║\n", .{});
    std.debug.print("  ║  ✅ Generic functions (comptime T: type)       ║\n", .{});
    std.debug.print("  ║  ✅ Type reflection (@typeInfo, @field)        ║\n", .{});
    std.debug.print("  ║  ✅ Compile-time validation (@compileError)    ║\n", .{});
    std.debug.print("  ║  ✅ Generic containers (TypedLedger)           ║\n", .{});
    std.debug.print("  ╚════════════════════════════════════════════════╝\n\n", .{});
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. `fn Container(comptime T: type) type` = generic container
// 2. @hasDecl(T, "name") = check if type has a method (interface!)
// 3. ONE TypedLedger handles FungibleToken, NFToken, StakeToken
// 4. The compiler generates SEPARATE optimized code for each
// 5. stateHash() shows how comptime generics compose with crypto
// 6. This is the REAL architecture of multi-asset blockchains
//
// 🔬 EXPERIMENT:
//   - Define a GovernanceToken type with voting_power field
//   - Make TypedLedger enforce that T has a specific field
//     using @hasField(T, "amount")
//   - Add a merge function that combines two ledgers of the
//     same type (state merging for consensus)
//   - Build a cross-ledger transfer that moves between
//     token_ledger and stake_ledger (token → stake conversion)
// ============================================================
