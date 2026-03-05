# Lesson 3 — Pointers & Slices
## Why This Matters for Your Blockchain
Every time you pass a `Transaction` to a function, hash a `BlockHeader`, or send
data over the network, you're working with **pointers and slices**. In Zig, these
are explicit — there's no hidden reference counting or garbage collection.
Understanding this is critical for:
- **FFI with C crypto libraries** (Lesson 6) — C APIs expect raw pointers
- **Network serialization** — converting structs to byte slices for wire format
- **Memory-safe chain traversal** — walking linked blocks without dangling refs
---
## Zig's Pointer Zoo
| Type | Meaning | Example |
|------|---------|---------|
| `*T` | Single-item pointer | Pointer to one `Block` |
| `*const T` | Single-item, read-only | Immutable ref to a `Transaction` |
| `[*]T` | Many-item pointer (C-style) | Raw buffer from C `malloc` |
| `[]T` | Slice (pointer + length) | Safe view into a `Transaction` array |
| `[]const u8` | Const byte slice | Zig's "string" type |
| `[*:0]const u8` | Sentinel-terminated (C string) | Null-terminated for C interop |
### The Golden Rule
> **Prefer `[]T` (slices) over `[*]T` (many-item pointers).**
> Slices carry their length — they're bounds-checked and safe.
> Use `[*]T` only when interfacing with C.
---
## Exercises
### Exercise 1 — `01_pointer_basics.zig`
**Pointer fundamentals:** `*T`, `*const T`, dereferencing, pointer arithmetic (why Zig prevents it)
### Exercise 2 — `02_slices.zig`
**Slices in action:** Creating slices from arrays, slice bounds, passing slices to functions, `[]const u8` as strings
### Exercise 3 — `03_sentinel_terminated.zig`
**C interop prep:** Sentinel-terminated arrays, `[*:0]u8`, converting between Zig slices and C strings
### Exercise 4 — `04_blockchain_merkle.zig`
**Merkle Tree:** Build a Merkle tree for a block's transactions using pointer-based tree nodes and byte slices
---
## Run each file:
```bash
zig run 01_pointer_basics.zig
zig run 02_slices.zig
zig run 03_sentinel_terminated.zig
zig run 04_blockchain_merkle.zig
```