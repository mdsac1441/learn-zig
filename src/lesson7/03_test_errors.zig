const std = @import("std");
const testing = std.testing;
// ============================================================
// EXERCISE 3: Testing Errors — expectError, Error Paths
// ============================================================
// In blockchain code, ERROR PATHS are as important as happy
// paths. A node that accepts invalid transactions = broken chain.
// Testing errors ensures your validation is bulletproof.
//
// YOUR BLOCKCHAIN USE CASE:
//   Verify that EVERY invalid transaction is REJECTED with the
//   CORRECT error. Not just "it failed" — but "it failed with
//   exactly the right error for this specific invalidity."
// ============================================================
// ===================== Blockchain Code ======================
const TxError = error{
    InvalidSignature,
    InsufficientBalance,
    NonceMismatch,
    ZeroAmount,
    SelfTransfer,
    ExcessiveAmount,
};
const StateError = error{
    AccountNotFound,
    AccountFrozen,
};
const ValidationError = TxError || StateError;
const Account = struct {
    id: u64,
    balance: u64,
    nonce: u64,
    frozen: bool,
};
const Transaction = struct {
    sender: u64,
    receiver: u64,
    amount: u64,
    fee: u64,
    nonce: u64,
    sig_valid: bool,
};
const SimpleState = struct {
    accounts: [8]Account,
    count: usize,
    fn init() SimpleState {
        var state: SimpleState = undefined;
        state.count = 0;
        return state;
    }
    fn addAccount(self: *SimpleState, id: u64, balance: u64) void {
        self.accounts[self.count] = .{
            .id = id,
            .balance = balance,
            .nonce = 0,
            .frozen = false,
        };
        self.count += 1;
    }
    fn getAccount(self: *const SimpleState, id: u64) StateError!*const Account {
        for (self.accounts[0..self.count]) |*acc| {
            if (acc.id == id) {
                if (acc.frozen) return error.AccountFrozen;
                return acc;
            }
        }
        return error.AccountNotFound;
    }
    fn validateTx(self: *const SimpleState, tx: *const Transaction) ValidationError!void {
        // Signature check
        if (!tx.sig_valid) return error.InvalidSignature;
        // Amount checks
        if (tx.amount == 0) return error.ZeroAmount;
        if (tx.amount > 1_000_000) return error.ExcessiveAmount;
        // Self-transfer check
        if (tx.sender == tx.receiver) return error.SelfTransfer;
        // Account checks
        const sender = try self.getAccount(tx.sender);
        if (sender.balance < tx.amount + tx.fee) return error.InsufficientBalance;
        if (tx.nonce != sender.nonce) return error.NonceMismatch;
    }
};
// ===================== TESTS ================================
// ---------------------------------------------------------
// STEP 1: expectError — verify SPECIFIC error is returned
// ---------------------------------------------------------
test "reject transaction with invalid signature" {
    var state = SimpleState.init();
    state.addAccount(1, 10000);
    state.addAccount(2, 5000);
    const tx = Transaction{
        .sender = 1,
        .receiver = 2,
        .amount = 100,
        .fee = 10,
        .nonce = 0,
        .sig_valid = false, // BAD!
    };
    // expectError checks that the function returns THIS SPECIFIC error
    try testing.expectError(error.InvalidSignature, state.validateTx(&tx));
}
test "reject zero amount transaction" {
    var state = SimpleState.init();
    state.addAccount(1, 10000);
    state.addAccount(2, 5000);
    const tx = Transaction{
        .sender = 1,
        .receiver = 2,
        .amount = 0, // BAD!
        .fee = 10,
        .nonce = 0,
        .sig_valid = true,
    };
    try testing.expectError(error.ZeroAmount, state.validateTx(&tx));
}
test "reject excessive amount transaction" {
    var state = SimpleState.init();
    state.addAccount(1, 10000);
    state.addAccount(2, 5000);
    const tx = Transaction{
        .sender = 1,
        .receiver = 2,
        .amount = 5_000_000, // BAD!
        .fee = 10,
        .nonce = 0,
        .sig_valid = true,
    };
    try testing.expectError(error.ExcessiveAmount, state.validateTx(&tx));
}
test "reject self-transfer" {
    var state = SimpleState.init();
    state.addAccount(1, 10000);
    const tx = Transaction{
        .sender = 1,
        .receiver = 1,
        .amount = 100, // BAD!
        .fee = 10,
        .nonce = 0,
        .sig_valid = true,
    };
    try testing.expectError(error.SelfTransfer, state.validateTx(&tx));
}
// ---------------------------------------------------------
// STEP 2: Test insufficient balance
// ---------------------------------------------------------
test "reject when balance is too low" {
    var state = SimpleState.init();
    state.addAccount(1, 100); // only 100 tokens
    state.addAccount(2, 5000);
    const tx = Transaction{
        .sender = 1,
        .receiver = 2,
        .amount = 90,
        .fee = 20,
        .nonce = 0,
        .sig_valid = true,
        // total cost = 90 + 20 = 110 > 100 balance
    };
    try testing.expectError(error.InsufficientBalance, state.validateTx(&tx));
}
test "accept when balance exactly covers cost" {
    var state = SimpleState.init();
    state.addAccount(1, 110); // exactly covers amount + fee
    state.addAccount(2, 5000);
    const tx = Transaction{
        .sender = 1,
        .receiver = 2,
        .amount = 90,
        .fee = 20,
        .nonce = 0,
        .sig_valid = true,
    };
    // This should NOT return an error
    try state.validateTx(&tx); // `try` = fails test if error returned
}
// ---------------------------------------------------------
// STEP 3: Test nonce matching
// ---------------------------------------------------------
test "reject when nonce doesn't match" {
    var state = SimpleState.init();
    state.addAccount(1, 10000);
    state.addAccount(2, 5000);
    const tx = Transaction{
        .sender = 1,
        .receiver = 2,
        .amount = 100,
        .fee = 10,
        .nonce = 5,
        .sig_valid = true, // nonce should be 0!
    };
    try testing.expectError(error.NonceMismatch, state.validateTx(&tx));
}
// ---------------------------------------------------------
// STEP 4: Test state errors
// ---------------------------------------------------------
test "reject when sender account doesn't exist" {
    var state = SimpleState.init();
    state.addAccount(2, 5000); // only receiver exists
    const tx = Transaction{
        .sender = 99,
        .receiver = 2,
        .amount = 100, // sender 99 doesn't exist
        .fee = 10,
        .nonce = 0,
        .sig_valid = true,
    };
    try testing.expectError(error.AccountNotFound, state.validateTx(&tx));
}
test "reject when sender account is frozen" {
    var state = SimpleState.init();
    state.addAccount(1, 10000);
    state.addAccount(2, 5000);
    state.accounts[0].frozen = true; // freeze account 1
    const tx = Transaction{
        .sender = 1,
        .receiver = 2,
        .amount = 100,
        .fee = 10,
        .nonce = 0,
        .sig_valid = true,
    };
    try testing.expectError(error.AccountFrozen, state.validateTx(&tx));
}
// ---------------------------------------------------------
// STEP 5: Test the happy path (valid transaction)
// ---------------------------------------------------------
test "accept valid transaction" {
    var state = SimpleState.init();
    state.addAccount(1, 10000);
    state.addAccount(2, 5000);
    const tx = Transaction{
        .sender = 1,
        .receiver = 2,
        .amount = 500,
        .fee = 25,
        .nonce = 0,
        .sig_valid = true,
    };
    // Should succeed — no error
    try state.validateTx(&tx);
}
// ---------------------------------------------------------
// STEP 6: Error priority — which check runs first?
// ---------------------------------------------------------
test "signature check happens before balance check" {
    var state = SimpleState.init();
    state.addAccount(1, 0); // zero balance AND bad sig
    const tx = Transaction{
        .sender = 1,
        .receiver = 2,
        .amount = 100,
        .fee = 10,
        .nonce = 0,
        .sig_valid = false, // checked first!
    };
    // Should get InvalidSignature, NOT InsufficientBalance
    try testing.expectError(error.InvalidSignature, state.validateTx(&tx));
}
test "amount check happens before balance check" {
    var state = SimpleState.init();
    state.addAccount(1, 0); // zero balance AND zero amount
    const tx = Transaction{
        .sender = 1,
        .receiver = 2,
        .amount = 0, // checked before balance
        .fee = 10,
        .nonce = 0,
        .sig_valid = true,
    };
    // Should get ZeroAmount, NOT InsufficientBalance
    try testing.expectError(error.ZeroAmount, state.validateTx(&tx));
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. testing.expectError(err, result) = assert SPECIFIC error
// 2. Test EVERY error path — invalid sig, balance, nonce, etc.
// 3. Test error PRIORITY — which check fires first matters
// 4. Test boundary cases — exact balance, zero values
// 5. `try fn()` in a test = pass if no error, fail if error
// 6. Error testing prevents silent acceptance of bad data
//
// 🔬 EXPERIMENT:
//   - Swap the order of checks in validateTx — watch priority
//     tests FAIL (they catch the bug!)
//   - Add an error for ExpiredTransaction (timestamp too old)
//   - Test what happens with amount = maxInt(u64) (overflow?)
//   - Add fee-too-low error and test the boundary
// ============================================================
