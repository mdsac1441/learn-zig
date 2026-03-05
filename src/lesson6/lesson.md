# Lesson 6 — FFI with C Libraries
## Why This Matters for Your Blockchain
Zig's killer feature for systems programming is **seamless C interop**. Unlike Rust (which
needs `bindgen`, unsafe blocks, and wrapper crates), Zig can `@cImport` C headers directly.
For your blockchain this means:
- **Use battle-tested C crypto** — OpenSSL, libsodium, secp256k1 (Bitcoin's curve)
- **Link C networking libs** — libuv, liburing for io_uring
- **Embed C VMs** — link a WASM runtime or EVM written in C
- **Reuse existing C code** — databases (LMDB, RocksDB), serialization (protobuf-c)
---
## Zig C Interop vs Other Languages
| Language | C Interop Approach | Friction |
|----------|-------------------|----------|
| C++ | Native, but header complexity | Low |
| Rust | `bindgen` + `unsafe` + build.rs | **High** |
| Go | `cgo` (slow, limited) | Medium |
| **Zig** | `@cImport(@cInclude("header.h"))` | **Almost zero** |
---
## Core Concepts
### 1. `@cImport` / `@cInclude` — Import C Headers Directly
```zig
const c = @cImport({ @cInclude("openssl/sha.h"); });
```
### 2. Calling C Functions
```zig
c.SHA256(data.ptr, data.len, &output);
```
### 3. Type Bridging — Zig ↔ C
```zig
// Zig slice → C pointer + length
c_func(slice.ptr, @intCast(slice.len));
// C pointer → Zig slice
const zig_slice = c_ptr[0..known_length];
```
### 4. Writing C Code IN Zig Files
```zig
// Inline C source for small wrappers
const c_code = @cImport({ @cDefine("MY_CONST", "42"); });
```
---
## Exercises
| # | File | Topic |
|---|------|-------|
| 01 | `01_libc_basics.zig` | Using libc from Zig — `memcpy`, `memset`, `printf`, time functions |
| 02 | `02_c_structs.zig` | C-compatible struct layouts, `extern struct`, passing to C |
| 03 | `03_calling_c_crypto.zig` | Zig's built-in crypto vs C-style API patterns |
| 04 | `04_blockchain_ffi.zig` | Build a hybrid Zig/C blockchain hasher — real FFI patterns |
```bash
zig run 01_libc_basics.zig
zig run 02_c_structs.zig
zig run 03_calling_c_crypto.zig
zig run 04_blockchain_ffi.zig
```
> **Note:** These exercises use Zig's built-in libc linking (`-lc`). On macOS, Zig
> automatically finds system libc. For OpenSSL exercises, you'd run:
> `zig run file.zig -lssl -lcrypto -I/opt/homebrew/include -L/opt/homebrew/lib`

# zig run 01_libc_basics.zig -lc

Progression:

#	Topic	Blockchain Pattern
01	libc from Zig — memset, memcmp, time, printf	Block timestamps via C, buffer ops
02	extern struct + packed struct	Wire protocol layout, compact TX flags (4 fields in 1 byte!)
03	C-style vs Zig crypto APIs	SHA-256, double-SHA256 (Bitcoin), HMAC, BLAKE3, Init/Update/Final
04	Hybrid Blockchain Hasher ⛏️	Wire format, Merkle root, mining, export fn for C-callable API
Key patterns from this lesson:

extern struct = deterministic layout for network wire format
packed struct = bit-level compact encoding (4 flags in 1 byte)
export fn = expose your Zig functions to C programs
@cImport = import any C header with zero boilerplate
Exercise 4 actually mines a block and exports a C-compatible API (sacrium_hash_header, sacrium_check_difficulty, sacrium_timestamp). You could build this as a shared library with zig build-lib -dynamic.

Say next for Lesson 7 — Testing in Zig!