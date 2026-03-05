# Lesson 2 — Memory Management & Allocators
## Why This Matters for Your Blockchain
In your blockchain, **every transaction, block, and peer connection** needs memory.
Unlike JS/Go/Rust, Zig gives you **explicit control** over *where* and *how* memory is allocated.
This is critical for:
- **Deterministic resource usage** — nodes must behave identically
- **Zero hidden allocations** — no GC pauses during consensus
- **Embedded/WASM targets** — constrained environments for light clients
---
## Core Concept: Allocator Interface
Zig doesn't have `malloc` baked in. Instead, every function that needs memory **takes an `Allocator` parameter**:
```zig
fn parseTransaction(allocator: std.mem.Allocator, raw: []const u8) !Transaction {
    // allocator is explicit — no hidden magic
}
```
This means **you control the memory strategy** at the call site, not inside the function.
---
## The 3 Allocators You'll Use
| Allocator | Use Case | Blockchain Example |
|-----------|----------|-------------------|
| `page_allocator` | General purpose, OS-backed | Long-lived node state |
| `FixedBufferAllocator` | Stack buffer, zero syscalls | Hashing a single block |
| `ArenaAllocator` | Bulk alloc, single free | Processing a batch of txns |
---
## Exercises (run each file with `zig run <filename>`)
### Exercise 1 — `01_page_allocator.zig`
**Goal:** Allocate a dynamic list of transactions using the page allocator.
- Learn `alloc`, `free`, `ArrayList`, and defer-based cleanup
- See what happens when you forget to free (try commenting out `defer`)
### Exercise 2 — `02_fixed_buffer.zig`
**Goal:** Use a stack-allocated buffer to serialize a block header — zero heap allocations.
- Learn `FixedBufferAllocator`
- Understand why this is perfect for hot paths (hashing, signature verification)
### Exercise 3 — `03_arena_allocator.zig`
**Goal:** Process a batch of transactions, allocate freely, then free everything at once.
- Learn `ArenaAllocator` wrapping another allocator
- Understand `arena.deinit()` vs freeing individual items
### Exercise 4 — `04_blockchain_mempool.zig`
**Goal:** Build a **Transaction Mempool** — a real blockchain component.
- Combines all 3 allocators
- Arena for batch processing, ArrayList for the pool, FixedBuffer for temp work
---
## Key Patterns to Remember
```
1. Always accept `Allocator` as a parameter — never hardcode one
2. Use `defer` for cleanup — it runs when scope exits
3. Arena = "allocate a lot, free all at once" (perfect for request/response cycles)
4. FixedBuffer = "I know my max size, no heap needed"
5. page_allocator = "I need the OS to give me memory" (slowest, most flexible)
```
---
## What's Next
**Lesson 3 — Pointers & Slices:** You'll learn `*T`, `[*]T`, `[]T`, pointer arithmetic,
and how to safely pass blockchain data structures across function boundaries.
