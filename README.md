## Learn Zig

This repo is a **hands-on Zig workshop** that teaches the language from first principles while you incrementally build pieces of a **Bitcoin‑style blockchain**: transactions, Merkle trees, mempools, persistent storage, and a simple P2P node.

Each lesson focuses on one Zig concept (allocators, pointers, error handling, comptime, FFI, testing, IO, networking, cross‑compilation) and then applies it to a realistic blockchain building block.

---

## Prerequisites

- **Zig**: install from the official site (`zig version` should work in your terminal)
- Comfortable with at least one other language (C/Rust/Go/TS/etc.)
- Basic blockchain concepts (blocks, transactions, mempool, peers) are helpful but not required — the lessons explain context as you go.

---

## Getting Started

Clone the repo and run a few examples:

```bash
git clone <this-repo-url>
cd learn-zig

# Sanity check: run root tests
zig build test

# Run the main demo
zig run src/main.zig || zig build run -Doptimize=ReleaseFast
```

You should see:

- The size (in bytes) of a packed `Transaction` struct
- A SHA‑256 hash of that transaction
- A simulated block of many transactions allocated via an arena
- A small SIMD example using Zig vectors

---

## Project Structure

- `**build.zig` / `build.zig.zon**`: Zig build and dependency configuration.
- `**src/main.zig**`: Entry demo using a packed `Transaction` struct, hashing, allocators, and SIMD.
- `**src/root.zig**`: Small library example with `bufferedPrint` and a basic test.
- `**src/block.zig**`: Block‑related helpers (used in later lessons).
- `**src/lessonN/**`: Each numbered folder is a focused lesson with:
  - A `lesson.md` explainer
  - 3–4 `.zig` exercises you can run individually

You typically run files directly with:

```bash
cd src/lesson2
zig run 01_page_allocator.zig || zig run 01_page_allocator.zig -D ReleaseFast
```

---

## Lesson Map

Below is the high‑level curriculum so you know where to jump in or review.

- **Lesson 2 — Memory Management & Allocators** (`src/lesson2/`)
  - **Concepts**: `std.mem.Allocator`, `page_allocator`, `FixedBufferAllocator`, `ArenaAllocator`, `defer` for cleanup.
  - **Blockchain tie‑in**: dynamic transaction lists, block hashing buffers, batch processing of transactions, and a real **mempool** implementation.
  - **How to run**:
    - `zig run 01_page_allocator.zig` || `zig run src/lesson2/01_page_allocator.zig -D ReleaseFast`
    - `zig run 02_fixed_buffer.zig`
    - `zig run 03_arena_allocator.zig`
    - `zig run 04_blockchain_mempool.zig`
- **Lesson 3 — Pointers & Slices** (`src/lesson3/`)
  - **Concepts**: pointer types (`*T`, `[*]T`, `[]T`), slices, sentinel‑terminated arrays, safe data passing.
  - **Blockchain tie‑in**: representing chains of blocks and Merkle tree data.
  - **Files**: `01_pointer_basics.zig`, `02_slices.zig`, `03_sentinel_terminated.zig`, `04_blockchain_merkle.zig`.
- **Lesson 4 — Error Handling** (`src/lesson4/`)
  - **Concepts**: error sets, `try`, `catch`, `errdefer`, composable error handling.
  - **Blockchain tie‑in**: validator logic and failure modes for invalid transactions/blocks.
  - **Files**: `01_error_basics.zig`, `02_errdefer.zig`, `03_error_sets.zig`, `04_blockchain_validator.zig`.
- **Lesson 5 — Comptime & Generics** (`src/lesson5/`)
  - **Concepts**: `comptime` parameters, generic functions, type reflection.
  - **Blockchain tie‑in**: reusable, generic components over different block/transaction types.
  - **Files**: `01_comptime_basics.zig`, `02_generic_functions.zig`, `03_type_reflection.zig`, `04_blockchain_generics.zig`.
- **Lesson 6 — C Interop / FFI** (`src/lesson6/`)
  - **Concepts**: calling into C, using C structs, linking crypto libraries.
  - **Blockchain tie‑in**: using existing C crypto primitives from Zig.
  - **Files**: `01_libc_basics.zig`, `02_c_structs.zig`, `03_calling_c_crypto.zig`, `04_blockchain_ffi.zig`.
- **Lesson 7 — Testing** (`src/lesson7/`)
  - **Concepts**: Zig’s `test` blocks, test allocators, testing error paths.
  - **Blockchain tie‑in**: validating consensus rules and P2P behavior with tests.
  - **Files**: `01_test_basics.zig`, `02_test_allocator.zig`, `03_test_errors.zig`, `04_blockchain_tests.zig`.
- **Lesson 8 — Files & Storage** (`src/lesson8/`)
  - **Concepts**: file IO, binary formats, buffered IO.
  - **Blockchain tie‑in**: persisting chain state and blocks to disk.
  - **Files**: `01_file_basics.zig`, `02_binary_format.zig`, `03_buffered_io.zig`, `04_blockchain_storage.zig`.
- **Lesson 9 — Networking (TCP/UDP)** (`src/lesson9/`)
  - **Concepts**: `std.net` sockets, TCP servers/clients, UDP broadcast, binary protocol framing.
  - **Blockchain tie‑in**: P2P node, peer discovery, block propagation.
  - **How to run**:
    - `zig run 01_tcp_echo.zig -- server` and `zig run 01_tcp_echo.zig -- client`
    - `zig run 02_udp_discovery.zig`
    - `zig run 03_protocol_messages.zig`
    - `zig run 04_p2p_node.zig -- node1` and `zig run 04_p2p_node.zig -- node2`
- **Lesson 10 — Targets & Cross‑Compilation** (`src/lesson10/`)
  - **Concepts**: build targets, conditional compilation, custom `build.zig`.
  - **Blockchain tie‑in**: compiling your node for different OS/CPU targets.
  - **Files**: `01_targets.zig`, `02_conditional.zig`, `03_build.zig`, `04_sacrium_node.zig`.

Each lesson also has a `lesson.md` that gives you background, diagrams, and a narrative walkthrough.

---

## Suggested Learning Path

1. **Skim the lesson markdown** for context (e.g. `src/lesson2/lesson.md`).
2. **Run each exercise file** with `zig run <file.zig>`.
3. **Experiment**:
  - change parameters and types,
  - add logging,
  - break things on purpose to see compile‑time and runtime errors.
4. **Revisit earlier lessons** as you progress — concepts like allocators, errors, and slices build on each other.

---

## Running Tests

This repo uses built‑in Zig testing:

```bash
zig build test
```

You can also run test files directly:

```bash
zig test src/root.zig
zig test src/lesson7/01_test_basics.zig
```

---

## Contributing / Extending

Ideas for extending this workshop:

- Add **Lesson 1** style warm‑ups if you’re brand new to Zig syntax.
- Implement more **consensus rules** or block validation logic.
+- Add additional network messages or peer management strategies.
- Port parts of the node to **WASM** or embedded targets using Lesson 10 concepts.

Bugfixes, clearer explanations, and new exercises are all welcome.

---

## License

GPL-3.0