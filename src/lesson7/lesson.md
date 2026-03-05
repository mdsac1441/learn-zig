# Lesson 7 — Testing in Zig
## Why This Matters for Your Blockchain
A blockchain is a **consensus machine** — every node must produce identical results.
Bugs in transaction validation, hash computation, or state transitions can cause:
- **Chain splits** (nodes disagree on the valid chain)
- **Double spends** (stolen funds)
- **Consensus failures** (network halts)
Zig has **built-in testing** — no framework needed, no dependencies.
Tests live alongside your code, use a special leak-detecting allocator,
and run with `zig test`.
---
## Zig Testing vs Other Languages
| Feature | JavaScript (Jest) | Rust (#[test]) | **Zig (test)** |
|---------|------------------|----------------|----------------|
| Setup | npm install jest | Built-in | **Built-in** |
| Syntax | `describe/it` | `#[test] fn` | `test "name" {}` |
| Assertions | `expect().toBe()` | `assert_eq!` | `try expect(x)` |
| Memory leak detection | ❌ No | ❌ No | **✅ std.testing.allocator** |
| Runs in | Node.js | Separate binary | **Same binary** |
---
## Core Concepts
### 1. `test` Blocks — Inline Tests
```zig
test "transaction hash is deterministic" {
    const tx1 = Transaction.init(1, 2, 100);
    const tx2 = Transaction.init(1, 2, 100);
    try std.testing.expectEqualSlices(u8, &tx1.hash, &tx2.hash);
}
```
### 2. `std.testing.allocator` — Leak Detection
```zig
test "no memory leaks in block builder" {
    const allocator = std.testing.allocator; // detects leaks!
    var list = std.ArrayList(u8){};
    defer list.deinit(allocator); // if you forget this → TEST FAILS
}
```
### 3. `std.testing.expect*` — Rich Assertions
```zig
try std.testing.expect(balance > 0);
try std.testing.expectEqual(expected, actual);
try std.testing.expectError(error.InsufficientBalance, result);
```
---
## Run tests:
```bash
zig test 01_test_basics.zig
zig test 02_test_allocator.zig
zig test 03_test_errors.zig
zig test 04_blockchain_tests.zig
```
> **Note:** Use `zig test` not `zig run` — tests have no `main` function!