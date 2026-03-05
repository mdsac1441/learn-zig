# Lesson 4 — Error Handling
## Why This Matters for Your Blockchain
A blockchain node must handle errors **gracefully and deterministically**:
- Invalid transaction → reject it, don't crash
- Network timeout → retry, don't panic
- Corrupted block → report and skip, keep syncing
Zig replaces try/catch/throw (JS) and Result/unwrap (Rust) with **error unions** —
the error is baked into the return type itself. No exceptions, no hidden control flow.
---
## Zig vs JavaScript Error Handling
| JavaScript | Zig | Why Zig is Better for Chains |
|------------|-----|------------------------------|
| `try { } catch (e) { }` | `fn() !T` + `try` / `catch` | Errors are in the TYPE — can't forget to handle |
| `throw new Error("msg")` | `return error.InvalidTx` | No heap allocation for errors |
| Errors can be anything | Errors are an enum set | Exhaustive switch — compiler forces you to handle all |
| Stack traces on throw | No hidden stack unwinding | Deterministic — critical for consensus |
---
## Core Concepts
### 1. Error Sets — Named Error Types
```zig
const TxError = error{ InvalidSignature, InsufficientBalance, DuplicateNonce };
```
### 2. Error Unions — Return Type = Value OR Error
```zig
fn validateTx(tx: Transaction) TxError!bool { ... }
//                               ^^^^^^^^^^^
//                               Returns TxError OR bool
```
### 3. `try` — Propagate Errors Up
```zig
const result = try validateTx(tx); // returns error to caller if fails
```
### 4. `catch` — Handle Errors Locally
```zig
const result = validateTx(tx) catch |err| {
    log.warn("TX failed: {}", .{err});
    return;
};
```
### 5. `errdefer` — Cleanup Only On Error
```zig
const buf = try allocator.alloc(u8, 1024);
errdefer allocator.free(buf); // only frees if function returns error
```
---
## Exercises
### Exercise 1 — `01_error_basics.zig`
Error sets, error unions, `try`, `catch`, and the `!` operator
### Exercise 2 — `02_errdefer.zig`
`errdefer` for cleanup on failure — building safe resource acquisition
### Exercise 3 — `03_error_sets.zig`
Custom error sets, merging error sets, exhaustive switch on errors
### Exercise 4 — `04_blockchain_validator.zig`
Full **Block Validator** — validates transactions, checks balances, handles every failure mode
---
## Run each file:
```bash
zig run 01_error_basics.zig
zig run 02_errdefer.zig
zig run 03_error_sets.zig
zig run 04_blockchain_validator.zig
```