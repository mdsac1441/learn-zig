# Lesson 8 — File I/O & Binary Formats
## Why This Matters for Your Blockchain
A blockchain node must **persist data to disk**:
- **Block storage** — the entire chain history
- **State database** — account balances, smart contract storage
- **Index files** — block height → file offset lookup
- **WAL (Write-Ahead Log)** — crash recovery
Zig gives you direct control over file I/O with no hidden buffering
or garbage collection pauses — critical for a node handling thousands
of blocks.
---
## Zig File I/O vs Other Languages
| Feature | Node.js (fs) | Rust (std::fs) | **Zig (std.fs)** |
|---------|-------------|----------------|------------------|
| Buffered I/O | Default | Default | **Explicit** (`BufferedWriter`) |
| Binary read/write | Buffer hacks | `read_exact`/`Write` | **`readStruct`/`writeStruct`** |
| Memory-mapped files | External lib | `memmap2` | **OS-level mmap** |
| Error handling | Callbacks/try | `Result<>` | **Error unions** |
---
## Exercises
| # | File | Topic |
|---|------|-------|
| 01 | `01_file_basics.zig` | Open, write, read, seek — fundamental file ops |
| 02 | `02_binary_format.zig` | Read/write structs as raw bytes — blockchain binary format |
| 03 | `03_buffered_io.zig` | BufferedWriter/Reader for high-throughput block storage |
| 04 | `04_blockchain_storage.zig` | Full block store — append blocks, read by height, build index |
```bash
zig run 01_file_basics.zig
zig run 02_binary_format.zig
zig run 03_buffered_io.zig
zig run 04_blockchain_storage.zig
```
> **Note:** These exercises create files in the current directory.
> Run `ls *.dat *.bin *.idx` after each exercise to see the output files.


Progression:

#	Topic	Blockchain Pattern
01	Create, read, write, seek, append	Genesis file, config loading, log entries
02	writeStruct/readStruct — binary format	Block files with magic bytes, round-trip serialization
03	BufferedWriter, FixedBufferStream, CountingWriter	High-throughput chain sync, in-memory serialization
04	Full BlockStore 📦	Append-only .dat + index .idx for O(1) lookup, chain verification
Exercise 4 is the big one — it implements Bitcoin Core's storage architecture:

blocks.dat — append-only data file for block headers + transactions
blocks.idx — index file mapping height → file_offset for instant random access
Chain verification — walk the chain validating prev_hash links
All temp files are auto-cleaned after each exercise runs.

Say next for Lesson 9 — Networking (TCP/UDP)!