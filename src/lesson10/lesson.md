# Lesson 10 — Cross-Compilation
## Why This Matters for Your Blockchain
Your blockchain node needs to run **everywhere**:
- **Linux servers** (x86_64) — production validators
- **Linux ARM** (aarch64) — Raspberry Pi nodes, AWS Graviton
- **macOS** (Apple Silicon) — developer machines
- **Windows** — desktop wallets, mining rigs
- **WebAssembly** — browser-based light clients
Zig's killer feature: **cross-compile to 40+ targets from ANY host machine**
with a single command. No Docker, no VMs, no cross-toolchains to install.
---
## Zig vs Other Languages — Cross-Compilation
| Language | Cross-Compile Linux→Windows | Cross-Compile ARM | Effort |
|----------|---------------------------|-------------------|--------|
| C/C++ | MinGW + sysroot + pain | Cross-toolchain | 🔴 Hard |
| Rust | `rustup target add` + linker config | Needs cross-linker | 🟡 Medium |
| Go | `GOOS=windows` (easy!) | `GOARCH=arm64` | 🟢 Easy |
| **Zig** | `zig build -Dtarget=x86_64-windows` | `-Dtarget=aarch64-linux` | 🟢 **Easiest** |
---
## Exercises
| # | File | Topic |
|---|------|-------|
| 01 | `01_targets.zig` | Query Zig's target list, detect current platform |
| 02 | `02_conditional.zig` | Conditional compilation per OS/arch |
| 03 | `build.zig` | Build system — `zig build` for multi-target builds |
| 04 | `04_sacrium_node.zig` | Full blockchain node binary — cross-compile ready |
```bash
# Exercise 1-2: Run directly
zig run 01_targets.zig
zig run 02_conditional.zig
# Exercise 3-4: Use the build system
zig build              # build for current platform
zig build run          # build and run
zig build -Dtarget=x86_64-linux        # cross-compile to Linux
zig build -Dtarget=aarch64-linux       # cross-compile to ARM Linux
zig build -Dtarget=x86_64-windows      # cross-compile to Windows
```



Lesson 10 — Cross-Compilation
Created all Lesson 10 files in lesson-10-cross-compile/: 

LESSON.md
, 

01_targets.zig
 (platform/CPU detection), 

02_conditional.zig
 (comptime OS/arch switches, wire safety), 

build.zig
 (build system with cross-compile support), 

04_sacrium_node.zig
 (full node binary with CLI, mining, tests). All 10 lessons complete.

Files Edited
Task

04_sacrium_node.zig

build.zig

02_conditional.zig

01_targets.zig

LESSON.md
Progress Updates
1
Creating lesson guide and exercise files for cross-compiling blockchain node to multiple platforms

2
Delivering final lesson to user

Lesson 10 — Cross-Compilation is ready! 🎯 This is the FINAL LESSON!

All files in lesson-10-cross-compile/:

bash
cd lesson-10-cross-compile
# Direct run:
zig run 01_targets.zig
zig run 02_conditional.zig
# Build system (Exercise 3+4):
zig build run -- --info          # show node info
zig build run -- --mine          # mine 3 test blocks
zig build test                   # run tests
# Cross-compile to other platforms:
zig build -Dtarget=x86_64-linux
zig build -Dtarget=aarch64-linux
zig build -Dtarget=x86_64-windows
Progression:

#	Topic	Blockchain Pattern
01	builtin platform/CPU detection	HW crypto check (AES-NI, ARM SHA2), pointer sizes
02	Comptime OS/arch switches	Platform configs, build mode tuning, wire protocol safety
03	build.zig — the build system	Multi-target builds, run/test steps, one-flag cross-compile
04	Sacrium Node Binary 🚀	Full CLI node with --info, --mine, platform detection, tests
Exercise 4 is the culmination — a shippable sacrium-node binary with:

Platform auto-detection (OS, arch, HW crypto)
Mining simulation with difficulty targeting
Tests that verify wire protocol sizes are platform-independent
Cross-compile to Linux/ARM/Windows with a single command
🎓 ALL 10 LESSONS COMPLETE!
#	Lesson	Key Skill
1	Structs & Serialization	extern struct, SHA-256 hash
2	Memory & Allocators	Arena, FixedBuffer, page_allocator
3	Pointers & Slices	*T, []T, sentinel arrays
4	Error Handling	Error unions, try/catch, error sets
5	Comptime	Generic functions, type reflection
6	FFI with C	@cImport, export fn, extern struct
7	Testing	test blocks, leak detection, expectError
8	File I/O	Binary block store, index files
9	Networking	TCP/UDP, wire protocol, P2P sync
10	Cross-Compilation	build.zig, multi-target, platform config
You now have every Zig skill needed to build Sacrium. The next step is combining everything into a real project. Want me to scaffold the full Sacrium blockchain project with a proper build.zig, source modules, and the real node architecture? 🚀