const std = @import("std");
// ============================================================
// EXERCISE 1: Error Basics — Error Unions, try, catch
// ============================================================
// In Zig, errors are VALUES in the return type, not exceptions.
// A function that can fail returns `ErrorSet!ReturnType`.
//
// YOUR BLOCKCHAIN USE CASE:
//   Transaction validation can fail for many reasons.
//   Each reason is a named error — no string parsing needed.
// ============================================================
// ---------------------------------------------------------
// STEP 1: Define an error set
// ---------------------------------------------------------
// Error sets are like enums — each error has a name.
// The compiler knows ALL possible errors at compile time.
const TransactionError = error{
    InvalidSignature,
    InsufficientBalance,
    DuplicateNonce,
    AmountTooLarge,
    ZeroAmount,
    SenderEqualsReceiver,
};
const Transaction = struct {
    sender: u64,
    receiver: u64,
    amount: u64,
    nonce: u64,
    signature_valid: bool, // simplified
    fn display(self: *const Transaction) void {
        std.debug.print("    TX: sender={d} → receiver={d} amount={d} nonce={d} sig={}\n", .{
            self.sender, self.receiver, self.amount, self.nonce, self.signature_valid,
        });
    }
};
// ---------------------------------------------------------
// STEP 2: Functions that return errors
// ---------------------------------------------------------
/// Returns `TransactionError` on failure, or `void` on success
fn validateTransaction(tx: *const Transaction) TransactionError!void {
    // Check signature
    if (!tx.signature_valid) {
        return error.InvalidSignature;
    }
    // Check zero amount
    if (tx.amount == 0) {
        return error.ZeroAmount;
    }
    // Check max amount (e.g., 1 million token limit)
    if (tx.amount > 1_000_000) {
        return error.AmountTooLarge;
    }
    // Check self-transfer
    if (tx.sender == tx.receiver) {
        return error.SenderEqualsReceiver;
    }
    // If we get here, no error — function returns void implicitly
}
/// Returns the validated amount OR an error
fn getValidatedAmount(tx: *const Transaction) TransactionError!u64 {
    // `try` = if validateTransaction returns error, we return it too
    try validateTransaction(tx);
    return tx.amount;
}
pub fn main() !void {
    std.debug.print("\n=== Lesson 4.1: Error Basics ===\n\n", .{});
    // ---------------------------------------------------------
    // STEP 3: Using `try` — propagate errors
    // ---------------------------------------------------------
    std.debug.print("  --- `try` — Error Propagation ---\n\n", .{});
    const good_tx = Transaction{
        .sender = 1,
        .receiver = 2,
        .amount = 500,
        .nonce = 0,
        .signature_valid = true,
    };
    // `try` unwraps the result or returns the error to OUR caller
    // Since main returns !void, the error propagates to the runtime
    const amount = try getValidatedAmount(&good_tx);
    std.debug.print("  ✅ Valid TX, amount: {d}\n\n", .{amount});
    // ---------------------------------------------------------
    // STEP 4: Using `catch` — handle errors locally
    // ---------------------------------------------------------
    std.debug.print("  --- `catch` — Local Error Handling ---\n\n", .{});
    const test_txns = [_]Transaction{
        .{ .sender = 1, .receiver = 2, .amount = 500, .nonce = 0, .signature_valid = true },
        .{ .sender = 3, .receiver = 4, .amount = 0, .nonce = 1, .signature_valid = true },
        .{ .sender = 5, .receiver = 6, .amount = 100, .nonce = 2, .signature_valid = false },
        .{ .sender = 7, .receiver = 7, .amount = 200, .nonce = 3, .signature_valid = true },
        .{ .sender = 8, .receiver = 9, .amount = 5_000_000, .nonce = 4, .signature_valid = true },
    };
    for (&test_txns, 0..) |*tx, i| {
        std.debug.print("  TX #{d}: ", .{i});
        tx.display();
        // `catch` captures the error for local handling
        const result = getValidatedAmount(tx) catch |err| {
            std.debug.print("         ❌ REJECTED: {s}\n\n", .{@errorName(err)});
            continue;
        };
        std.debug.print("         ✅ ACCEPTED: amount={d}\n\n", .{result});
    }
    // ---------------------------------------------------------
    // STEP 5: `catch` with a default value
    // ---------------------------------------------------------
    std.debug.print("  --- `catch` with Default ---\n\n", .{});
    const bad_tx = Transaction{
        .sender = 1,
        .receiver = 2,
        .amount = 100,
        .nonce = 0,
        .signature_valid = false,
    };
    // If validation fails, use 0 as default (common in fee calculations)
    const safe_amount = getValidatedAmount(&bad_tx) catch 0;
    std.debug.print("  Safe amount (0 on error): {d}\n\n", .{safe_amount});
    // ---------------------------------------------------------
    // STEP 6: `if` with error union (like optional unwrapping)
    // ---------------------------------------------------------
    std.debug.print("  --- if/else with Error Unions ---\n\n", .{});
    if (getValidatedAmount(&good_tx)) |valid_amount| {
        std.debug.print("  if branch: got {d}\n", .{valid_amount});
    } else |err| {
        std.debug.print("  else branch: error {s}\n", .{@errorName(err)});
    }
    if (getValidatedAmount(&bad_tx)) |valid_amount| {
        std.debug.print("  if branch: got {d}\n", .{valid_amount});
    } else |err| {
        std.debug.print("  else branch: error {s}\n", .{@errorName(err)});
    }
    // ---------------------------------------------------------
    // STEP 7: Unreachable — "I guarantee this won't fail"
    // ---------------------------------------------------------
    std.debug.print("\n  --- `catch unreachable` ---\n\n", .{});
    // ONLY use when you're 100% certain it can't fail
    // If it DOES fail → safety panic in Debug, UB in Release
    const guaranteed = getValidatedAmount(&good_tx) catch unreachable;
    std.debug.print("  Guaranteed amount: {d}\n", .{guaranteed});
    std.debug.print("  ⚠️  Using `catch unreachable` on bad data = panic!\n", .{});
    std.debug.print("\n✅ Error basics complete!\n\n", .{});
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. `error{ A, B, C }` = named error set (like an enum)
// 2. `ErrorSet!T` = error union (returns T or error)
// 3. `try x` = unwrap or propagate error to caller
// 4. `x catch |err| { }` = handle error locally
// 5. `x catch default_value` = use default on error
// 6. `@errorName(err)` = get error name as string
// 7. `catch unreachable` = assert "this CANNOT fail"
//
// 🔬 EXPERIMENT:
//   - Add a new error `ExpiredTransaction` and handle it
//   - Use `catch unreachable` on a bad TX — see the panic
//   - Make validateTransaction return a u8 error code instead
//     and see how much worse the code becomes (Zig errors > ints)
// ============================================================
