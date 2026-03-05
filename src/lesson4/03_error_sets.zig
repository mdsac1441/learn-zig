const std = @import("std");
// ============================================================
// EXERCISE 3: Custom Error Sets — Composable Error Types
// ============================================================
// Zig error sets can be MERGED. This means each layer of your
// blockchain can define its own errors, and they compose cleanly.
//
// YOUR BLOCKCHAIN USE CASE:
//   - Network layer has ConnectionError
//   - Consensus layer has ValidationError
//   - Storage layer has StorageError
//   - A block sync function can return ANY of these!
// ============================================================
// ---------------------------------------------------------
// STEP 1: Define domain-specific error sets
// ---------------------------------------------------------
const NetworkError = error{
    ConnectionRefused,
    Timeout,
    PeerBanned,
    InvalidProtocol,
};
const ValidationError = error{
    InvalidBlockHash,
    DifficultyNotMet,
    InvalidMerkleRoot,
    TimestampTooFar,
    OrphanBlock,
};
const StorageError = error{
    DiskFull,
    CorruptedData,
    KeyNotFound,
    WriteConflict,
};
// ---------------------------------------------------------
// STEP 2: Merge error sets with ||
// ---------------------------------------------------------
/// SyncError = all possible errors during block sync
const SyncError = NetworkError || ValidationError || StorageError;
// You can also merge with std errors:
const FullSyncError = SyncError || error{OutOfMemory};
// ---------------------------------------------------------
// STEP 3: Functions with different error domains
// ---------------------------------------------------------
fn downloadBlock(peer_id: u8, fail: bool) NetworkError![]const u8 {
    if (fail) {
        return switch (peer_id % 3) {
            0 => error.ConnectionRefused,
            1 => error.Timeout,
            else => error.PeerBanned,
        };
    }
    std.debug.print("    [net]  Downloaded block from peer #{d}\n", .{peer_id});
    return "raw_block_data";
}
fn validateBlock(data: []const u8, fail: bool) ValidationError!void {
    if (fail) {
        if (data.len > 0) {
            return error.InvalidBlockHash;
        }
        return error.DifficultyNotMet;
    }
    std.debug.print("    [val]  Block validated\n", .{});
}
fn storeBlock(data: []const u8, fail: bool) StorageError!void {
    _ = data;
    if (fail) {
        return error.DiskFull;
    }
    std.debug.print("    [db]   Block stored to disk\n", .{});
}
/// Sync a block — can return ANY error from the 3 layers
fn syncBlock(
    peer_id: u8,
    fail_network: bool,
    fail_validation: bool,
    fail_storage: bool,
) SyncError!void {
    // Each `try` propagates the layer's errors into SyncError
    const data = try downloadBlock(peer_id, fail_network);
    try validateBlock(data, fail_validation);
    try storeBlock(data, fail_storage);
}
pub fn main() !void {
    std.debug.print("\n=== Lesson 4.3: Custom Error Sets ===\n\n", .{});
    // ---------------------------------------------------------
    // STEP 4: Exhaustive switch on errors
    // ---------------------------------------------------------
    const scenarios = [_]struct {
        name: []const u8,
        peer: u8,
        fail_net: bool,
        fail_val: bool,
        fail_store: bool,
    }{
        .{ .name = "All succeeds", .peer = 1, .fail_net = false, .fail_val = false, .fail_store = false },
        .{ .name = "Network fail", .peer = 0, .fail_net = true, .fail_val = false, .fail_store = false },
        .{ .name = "Validation fail", .peer = 2, .fail_net = false, .fail_val = true, .fail_store = false },
        .{ .name = "Storage fail", .peer = 3, .fail_net = false, .fail_val = false, .fail_store = true },
    };
    for (scenarios) |s| {
        std.debug.print("  📡 Scenario: {s}\n", .{s.name});
        syncBlock(s.peer, s.fail_net, s.fail_val, s.fail_store) catch |err| {
            // Exhaustive switch — compiler forces you to handle ALL errors!
            switch (err) {
                // Network errors
                error.ConnectionRefused => std.debug.print("    🔌 Connection refused — try another peer\n", .{}),
                error.Timeout => std.debug.print("    ⏰ Timeout — peer too slow\n", .{}),
                error.PeerBanned => std.debug.print("    🚫 Peer banned — skip\n", .{}),
                error.InvalidProtocol => std.debug.print("    📛 Bad protocol version\n", .{}),
                // Validation errors
                error.InvalidBlockHash => std.debug.print("    #️⃣  Bad block hash — reject\n", .{}),
                error.DifficultyNotMet => std.debug.print("    ⛏️  Difficulty not met\n", .{}),
                error.InvalidMerkleRoot => std.debug.print("    🌳 Merkle mismatch — reject\n", .{}),
                error.TimestampTooFar => std.debug.print("    🕐 Timestamp out of range\n", .{}),
                error.OrphanBlock => std.debug.print("    👻 Orphan block — queue for later\n", .{}),
                // Storage errors
                error.DiskFull => std.debug.print("    💾 Disk full — prune old blocks!\n", .{}),
                error.CorruptedData => std.debug.print("    💥 Data corruption — rebuild index\n", .{}),
                error.KeyNotFound => std.debug.print("    🔑 Key missing in DB\n", .{}),
                error.WriteConflict => std.debug.print("    ⚡ Write conflict — retry\n", .{}),
            }
            std.debug.print("\n", .{});
            return;
        };
        std.debug.print("    ✅ Block synced successfully!\n\n", .{});
    }
    // ---------------------------------------------------------
    // STEP 5: Error categorization with inline functions
    // ---------------------------------------------------------
    std.debug.print("  --- Error Categorization ---\n\n", .{});
    const test_errors = [_]SyncError{
        error.ConnectionRefused,
        error.InvalidBlockHash,
        error.DiskFull,
        error.Timeout,
        error.OrphanBlock,
    };
    for (test_errors) |err| {
        const category = categorizeError(err);
        const severity = errorSeverity(err);
        std.debug.print("    {s:<25} → category={s:<12} severity={s}\n", .{
            @errorName(err), category, severity,
        });
    }
    // ---------------------------------------------------------
    // STEP 6: anyerror — the catch-all (use sparingly!)
    // ---------------------------------------------------------
    std.debug.print("\n  --- anyerror ---\n\n", .{});
    std.debug.print("    `anyerror` matches ANY error set\n", .{});
    std.debug.print("    Use it only in generic/logging code\n", .{});
    std.debug.print("    Prefer specific error sets for type safety!\n", .{});
    logError(error.InvalidBlockHash);
    logError(error.DiskFull);
    std.debug.print("\n✅ Custom error sets mastered!\n\n", .{});
}
fn categorizeError(err: SyncError) []const u8 {
    return switch (err) {
        error.ConnectionRefused, error.Timeout, error.PeerBanned, error.InvalidProtocol => "NETWORK",
        error.InvalidBlockHash, error.DifficultyNotMet, error.InvalidMerkleRoot, error.TimestampTooFar, error.OrphanBlock => "CONSENSUS",
        error.DiskFull, error.CorruptedData, error.KeyNotFound, error.WriteConflict => "STORAGE",
    };
}
fn errorSeverity(err: SyncError) []const u8 {
    return switch (err) {
        error.Timeout, error.KeyNotFound => "LOW",
        error.ConnectionRefused, error.PeerBanned, error.OrphanBlock, error.TimestampTooFar, error.WriteConflict => "MEDIUM",
        error.InvalidProtocol, error.InvalidBlockHash, error.DifficultyNotMet, error.InvalidMerkleRoot, error.DiskFull, error.CorruptedData => "HIGH",
    };
}
/// Generic error logger using anyerror
fn logError(err: anyerror) void {
    std.debug.print("    [LOG] error={s}\n", .{@errorName(err)});
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. Define error sets per domain: NetworkError, ValidationError
// 2. Merge with `||`: SyncError = NetworkError || ValidationError
// 3. `try` propagates any sub-error into the merged set
// 4. `switch (err)` is EXHAUSTIVE — compiler checks all cases
// 5. `anyerror` = wildcard, use only for logging/generic code
// 6. This pattern = type-safe error handling across layers
//
// 🔬 EXPERIMENT:
//   - Add a new StorageError variant — watch the compiler
//     FORCE you to handle it in the switch
//   - Try removing one case from the switch — see compile error
//   - Create a ConsensusError that merges ValidationError + custom
// ============================================================
