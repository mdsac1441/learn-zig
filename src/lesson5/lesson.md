# Lesson 5 — Comptime (Compile-Time Computation)
## Why This Matters for Your Blockchain
Zig's `comptime` is its most unique feature — code that runs **at compile time**, not runtime.
For your blockchain this means:
- **Generic data structures** — one `HashMap` works for any key/value type
- **Compile-time validation** — catch invalid configs BEFORE deploying
- **Zero-cost abstractions** — the compiler generates specialized code per type
- **Protocol versioning** — validate wire formats at compile time
---
## comptime vs Rust Generics vs C++ Templates
| Feature | C++ Templates | Rust Generics | Zig comptime |
|---------|--------------|---------------|-------------|
| Mechanism | Text substitution | Monomorphization | Compile-time evaluation |
| Error messages | Awful | Good (traits) | Excellent (it's just Zig) |
| Code execution | Limited (constexpr) | Limited (const fn) | **Full language** |
| Type reflection | No | Limited | **Yes, full `@typeInfo`** |
---
## Core Concepts
### 1. `comptime` Parameters — Generic Functions
```zig
fn hash(comptime T: type, data: T) [32]u8 { ... }
```
### 2. `comptime` Blocks — Run Code at Compile Time
```zig
const lookup = comptime blk: { break :blk buildTable(); };
```
### 3. `@typeInfo` — Reflect on Types
```zig
const fields = @typeInfo(Transaction).@"struct".fields;
```
### 4. Compile-Time Validation
```zig
comptime { if (@sizeOf(BlockHeader) != 128) @compileError("wrong size!"); }
```
---
## Exercises
| # | File | Topic |
|---|------|-------|
| 01 | `01_comptime_basics.zig` | comptime vars, comptime blocks, compile-time math |
| 02 | `02_generic_functions.zig` | Generic hash, serialize, compare — one function for any type |
| 03 | `03_type_reflection.zig` | `@typeInfo`, iterating struct fields, automatic serialization |
| 04 | `04_blockchain_generics.zig` | Generic `TypedLedger(T)` — blockchain state for any token type |
```bash
zig run 01_comptime_basics.zig
zig run 02_generic_functions.zig
zig run 03_type_reflection.zig
zig run 04_blockchain_generics.zig
```

#	Topic	Blockchain Pattern
01	comptime vars, blocks, inline for	Lookup tables, struct size assertions, opcode validator
02	Generic functions (comptime T: type)	One hashAny(T) for any struct, sortByField, RingBuffer(T, N)
03	@typeInfo, field iteration, @field	Auto debug-print any struct, wire format validation, zero-init
04	Generic TypedLedger(T) 🏦	Multi-asset ledger — FungibleToken, NFToken, StakeToken — one impl handles all
This is Zig's superpower. Exercise 4 builds a real multi-asset blockchain ledger where ONE generic implementation handles fungible tokens, NFTs, and staking — with the compiler generating optimized, specialized code for each. This is the actual architecture of chains like Solana.