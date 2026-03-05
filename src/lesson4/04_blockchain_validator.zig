const std = @import("std");
// ============================================================
// EXERCISE 4: Block Validator — Full Error Handling Pipeline
// ============================================================
// This is a REAL blockchain component that validates an entire
// block before accepting it into the chain. It combines:
//
//   - Custom error sets (from Exercise 3)
//   - errdefer (from Exercise 2)
//   - Error propagation with try (from Exercise 1)
//   - Allocators (from Lesson 2)
//   - Slices (from Lesson 3)
//
// Every error path is handled. No panics. No crashes.
// This is how production blockchain nodes work.
// ============================================================
// ===================== Error Definitions ====================
const TxValidationError = error{
    InvalidSignature,
    InsufficientBalance,
    NonceMismatch,
    ZeroAmount,
    ExcessiveAmount,
    SelfTransfer,
};
const BlockValidationError = error{
    EmptyBlock,
    InvalidPrevHash,
    InvalidMerkleRoot,
    TimestampInFuture,
    TimestampTooOld,
    DifficultyNotMet,
    BlockTooLarge,
};
const ValidatorError = TxValidationError || BlockValidationError || error{OutOfMemory};
// ======================== Data Types ========================
const Transaction = struct {
    sender: u64,
    receiver: u64,
    amount: u64,
    nonce: u64,
    signature_valid: bool,
};
const BlockHeader = struct {
    height: u64,
    prev_hash: [32]u8,
    merkle_root: [32]u8,
    timestamp: u64,
    difficulty: u32,
    nonce: u64,
    tx_count: u32,
};
const Block = struct {
    header: BlockHeader,
    transactions: []const Transaction,
};
// ======================== State ============================
const AccountState = struct {
    balance: u64,
    nonce: u64,
};
const ValidatorState = struct {
    accounts: [16]AccountState, // simplified: 16 accounts max
    chain_height: u64,
    last_block_hash: [32]u8,
    last_timestamp: u64,
    current_difficulty: u32,
    fn init() ValidatorState {
        var state: ValidatorState = undefined;
        // Initialize some test accounts with balances
        for (&state.accounts, 0..) |*acc, i| {
            acc.* = .{
                .balance = (i + 1) * 10000, // each account has tokens
                .nonce = 0,
            };
        }
        state.chain_height = 0;
        @memset(&state.last_block_hash, 0);
        state.last_timestamp = 1708900000;
        state.current_difficulty = 4;
        return state;
    }
    fn getAccount(self: *const ValidatorState, id: u64) ?*const AccountState {
        if (id >= self.accounts.len) return null;
        return &self.accounts[id];
    }
};
// =================== Validation Logic ======================
const ValidationReport = struct {
    valid_txns: u32,
    invalid_txns: u32,
    errors: std.ArrayList(ReportEntry),
    const ReportEntry = struct {
        tx_index: usize,
        error_name: []const u8,
    };
    fn init() ValidationReport {
        return .{
            .valid_txns = 0,
            .invalid_txns = 0,
            .errors = std.ArrayList(ReportEntry){},
        };
    }
    fn deinit(self: *ValidationReport, allocator: std.mem.Allocator) void {
        self.errors.deinit(allocator);
    }
    fn addError(self: *ValidationReport, allocator: std.mem.Allocator, tx_idx: usize, err_name: []const u8) !void {
        try self.errors.append(allocator, .{
            .tx_index = tx_idx,
            .error_name = err_name,
        });
        self.invalid_txns += 1;
    }
    fn display(self: *const ValidationReport) void {
        std.debug.print("\n    ╔══════════════════════════════════╗\n", .{});
        std.debug.print("    ║     VALIDATION REPORT            ║\n", .{});
        std.debug.print("    ╠══════════════════════════════════╣\n", .{});
        std.debug.print("    ║  Valid TXs:   {d:<20}║\n", .{self.valid_txns});
        std.debug.print("    ║  Invalid TXs: {d:<20}║\n", .{self.invalid_txns});
        std.debug.print("    ╠══════════════════════════════════╣\n", .{});
        if (self.errors.items.len > 0) {
            for (self.errors.items) |entry| {
                std.debug.print("    ║  TX#{d:<3}: {s:<23}║\n", .{ entry.tx_index, entry.error_name });
            }
        } else {
            std.debug.print("    ║  No errors                      ║\n", .{});
        }
        std.debug.print("    ╚══════════════════════════════════╝\n\n", .{});
    }
};
/// Validate a single transaction against current state
fn validateTransaction(tx: *const Transaction, state: *const ValidatorState) TxValidationError!void {
    // Check signature
    if (!tx.signature_valid) return error.InvalidSignature;
    // Check zero amount
    if (tx.amount == 0) return error.ZeroAmount;
    // Check max amount
    if (tx.amount > 1_000_000) return error.ExcessiveAmount;
    // Check self-transfer
    if (tx.sender == tx.receiver) return error.SelfTransfer;
    // Check sender exists and has balance
    const account = state.getAccount(tx.sender) orelse return error.InsufficientBalance;
    if (account.balance < tx.amount) return error.InsufficientBalance;
    // Check nonce
    if (tx.nonce != account.nonce) return error.NonceMismatch;
}
/// Validate the block header
fn validateHeader(header: *const BlockHeader, state: *const ValidatorState) BlockValidationError!void {
    // Check block has transactions
    if (header.tx_count == 0) return error.EmptyBlock;
    // Check previous hash links to our chain
    if (!std.mem.eql(u8, &header.prev_hash, &state.last_block_hash)) {
        return error.InvalidPrevHash;
    }
    // Check timestamp is not too far in the future (> 2 hours)
    const current_time: u64 = 1708910000; // simulated "now"
    if (header.timestamp > current_time + 7200) return error.TimestampInFuture;
    // Check timestamp is after last block
    if (header.timestamp <= state.last_timestamp) return error.TimestampTooOld;
    // Check block size
    if (header.tx_count > 1000) return error.BlockTooLarge;
    // Simplified difficulty check
    if (header.difficulty < state.current_difficulty) return error.DifficultyNotMet;
}
/// Full block validation pipeline
fn validateBlock(
    allocator: std.mem.Allocator,
    block: *const Block,
    state: *const ValidatorState,
) ValidatorError!ValidationReport {
    // Create report (uses allocator for dynamic error list)
    var report = ValidationReport.init();
    // errdefer: if WE fail, clean up the report
    errdefer report.deinit(allocator);
    // ---------------------------------------------------------
    // Phase 1: Validate block header
    // ---------------------------------------------------------
    std.debug.print("    Phase 1: Header validation...\n", .{});
    try validateHeader(&block.header, state);
    std.debug.print("    ✅ Header valid\n", .{});
    // ---------------------------------------------------------
    // Phase 2: Validate each transaction (soft failures)
    // ---------------------------------------------------------
    std.debug.print("    Phase 2: Transaction validation...\n", .{});
    for (block.transactions, 0..) |*tx, i| {
        validateTransaction(tx, state) catch |err| {
            // Individual TX failures don't reject the whole block
            // (in some chains). We record them in the report.
            try report.addError(allocator, i, @errorName(err));
            continue;
        };
        report.valid_txns += 1;
    }
    // ---------------------------------------------------------
    // Phase 3: Check minimum valid transactions
    // ---------------------------------------------------------
    std.debug.print("    Phase 3: Minimum TX threshold...\n", .{});
    if (report.valid_txns == 0) {
        std.debug.print("    ❌ Block has zero valid transactions!\n", .{});
        // Don't return error here — let the caller decide based on report
    }
    std.debug.print("    ✅ Validation pipeline complete\n", .{});
    return report;
}
pub fn main() !void {
    std.debug.print("\n=== Lesson 4.4: Block Validator — Error Handling Pipeline ===\n\n", .{});
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var state = ValidatorState.init();
    // ==========================================================
    // TEST 1: Valid block with mixed transactions
    // ==========================================================
    {
        std.debug.print("  ┌─ Test 1: Mixed valid/invalid transactions ──────┐\n", .{});
        const txns = [_]Transaction{
            .{ .sender = 0, .receiver = 1, .amount = 500, .nonce = 0, .signature_valid = true },
            .{ .sender = 1, .receiver = 2, .amount = 100, .nonce = 0, .signature_valid = true },
            .{ .sender = 2, .receiver = 3, .amount = 0, .nonce = 0, .signature_valid = true }, // ZeroAmount
            .{ .sender = 3, .receiver = 4, .amount = 200, .nonce = 0, .signature_valid = false }, // BadSig
            .{ .sender = 5, .receiver = 5, .amount = 50, .nonce = 0, .signature_valid = true }, // SelfTransfer
            .{ .sender = 6, .receiver = 7, .amount = 800, .nonce = 0, .signature_valid = true },
        };
        const block = Block{
            .header = .{
                .height = 1,
                .prev_hash = state.last_block_hash,
                .merkle_root = [_]u8{0xAA} ** 32,
                .timestamp = 1708905000,
                .difficulty = 4,
                .nonce = 12345,
                .tx_count = txns.len,
            },
            .transactions = &txns,
        };
        var report = try validateBlock(allocator, &block, &state);
        defer report.deinit(allocator);
        report.display();
    }
    // ==========================================================
    // TEST 2: Invalid block header (bad prev_hash)
    // ==========================================================
    {
        std.debug.print("  ┌─ Test 2: Invalid previous hash ─────────────────┐\n", .{});
        const txns = [_]Transaction{
            .{ .sender = 0, .receiver = 1, .amount = 100, .nonce = 0, .signature_valid = true },
        };
        const block = Block{
            .header = .{
                .height = 2,
                .prev_hash = [_]u8{0xFF} ** 32, // wrong hash!
                .merkle_root = [_]u8{0xBB} ** 32,
                .timestamp = 1708906000,
                .difficulty = 4,
                .nonce = 99999,
                .tx_count = txns.len,
            },
            .transactions = &txns,
        };
        const result = validateBlock(allocator, &block, &state);
        if (result) |*report| {
            _ = report;
            std.debug.print("    Unexpected success!\n", .{});
        } else |err| {
            std.debug.print("    ❌ Block REJECTED: {s}\n", .{@errorName(err)});
            std.debug.print("    → Header validation caught the error before\n", .{});
            std.debug.print("      wasting time validating transactions!\n\n", .{});
        }
    }
    // ==========================================================
    // TEST 3: Empty block
    // ==========================================================
    {
        std.debug.print("  ┌─ Test 3: Empty block ───────────────────────────┐\n", .{});
        const block = Block{
            .header = .{
                .height = 3,
                .prev_hash = state.last_block_hash,
                .merkle_root = [_]u8{0} ** 32,
                .timestamp = 1708907000,
                .difficulty = 4,
                .nonce = 0,
                .tx_count = 0, // empty!
            },
            .transactions = &[_]Transaction{},
        };
        const result = validateBlock(allocator, &block, &state);
        if (result) |*report| {
            _ = report;
            std.debug.print("    Unexpected success!\n", .{});
        } else |err| {
            std.debug.print("    ❌ Block REJECTED: {s}\n\n", .{@errorName(err)});
        }
    }
    // ==========================================================
    // Summary
    // ==========================================================
    std.debug.print("  ╔════════════════════════════════════════════════╗\n", .{});
    std.debug.print("  ║  LESSON 4 COMPLETE — Error Handling Summary   ║\n", .{});
    std.debug.print("  ╠════════════════════════════════════════════════╣\n", .{});
    std.debug.print("  ║  ✅ Error unions:  ErrorSet!ReturnType        ║\n", .{});
    std.debug.print("  ║  ✅ try:           Propagate errors up        ║\n", .{});
    std.debug.print("  ║  ✅ catch:         Handle errors locally      ║\n", .{});
    std.debug.print("  ║  ✅ errdefer:      Cleanup on failure only    ║\n", .{});
    std.debug.print("  ║  ✅ Error sets:    Composable with ||         ║\n", .{});
    std.debug.print("  ║  ✅ switch(err):   Exhaustive error handling  ║\n", .{});
    std.debug.print("  ╚════════════════════════════════════════════════╝\n\n", .{});
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. ARCHITECTURE: Header validation FIRST, then transactions
//    → Fail fast on cheap checks before expensive ones
//
// 2. SOFT vs HARD errors:
//    - Hard: invalid header → reject entire block
//    - Soft: invalid TX → log it, keep processing others
//
// 3. errdefer on report → no leaks even on early return
//
// 4. Error sets compose: TxError || BlockError || OOM
//    → One function can return errors from all layers
//
// 5. @errorName(err) → string for logging without allocations
//
// 🔬 EXPERIMENT:
//   - Add a "double-spend detection" check across transactions
//   - Implement block acceptance: update state after validation
//   - Add a ValidationError.GasLimitExceeded for your hybrid chain
//   - Make the validator return a detailed receipt per transaction
// ============================================================
