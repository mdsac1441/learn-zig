# Lesson 9 — Networking (TCP/UDP)
## Why This Matters for Your Blockchain
A blockchain is a **distributed system** — nodes communicate over the network to:
- **Broadcast transactions** to the mempool
- **Propagate new blocks** to peers
- **Sync the chain** with new nodes (Initial Block Download)
- **Peer discovery** — find and maintain connections
Zig's `std.net` gives you direct TCP/UDP socket access with no runtime overhead —
perfect for building a high-performance P2P protocol.
---
## Network Architecture of a Blockchain Node
```
┌─────────────────────────────────────┐
│           YOUR NODE                  │
│                                      │
│  ┌──────────┐    ┌──────────────┐   │
│  │ TCP      │    │ Protocol     │   │
│  │ Listener │───▶│ Handler      │   │
│  │ :8333    │    │ (messages)   │   │
│  └──────────┘    └──────┬───────┘   │
│                         │           │
│  ┌──────────┐    ┌──────▼───────┐   │
│  │ Outbound │    │ Mempool /    │   │
│  │ Peers    │◀──▶│ Chain State  │   │
│  └──────────┘    └──────────────┘   │
└─────────────────────────────────────┘
         │                  │
    ┌────▼────┐       ┌────▼────┐
    │ Peer A  │       │ Peer B  │
    └─────────┘       └─────────┘
```
---
## Exercises
| # | File | Topic | How to Run |
|---|------|-------|-----------|
| 01 | `01_tcp_echo.zig` | TCP server + client — echo protocol | Terminal 1: `zig run 01_tcp_echo.zig -- server` <br> Terminal 2: `zig run 01_tcp_echo.zig -- client` |
| 02 | `02_udp_discovery.zig` | UDP broadcast for peer discovery | `zig run 02_udp_discovery.zig` |
| 03 | `03_protocol_messages.zig` | Binary protocol message framing | `zig run 03_protocol_messages.zig` |
| 04 | `04_p2p_node.zig` | P2P blockchain node — block propagation | Terminal 1: `zig run 04_p2p_node.zig -- node1` <br> Terminal 2: `zig run 04_p2p_node.zig -- node2` |
> **Note:** Exercises 01 and 04 require **two terminals** — one for the server/node
> and one for the client/peer. Exercise 02 and 03 are self-contained.


Progression:

#	Topic	Blockchain Pattern
01	TCP echo server + client	Foundation: listen, accept, connect, read/write
02	UDP broadcast peer discovery	DISCOVER → ANNOUNCE → build peer list, find best sync peer
03	Binary protocol framing	[MAGIC][TYPE][LENGTH][PAYLOAD][CRC32] — tamper detection
04	P2P Blockchain Node 🔗	VERSION/VERACK handshake → GETBLOCKS → BLOCK stream → chain validation
Exercise 4 is the real deal — it implements Bitcoin's P2P protocol:

Handshake: VERSION ↔ VERSION ↔ VERACK ↔ VERACK (learn each other's chain height)
Chain sync: GETBLOCKS(0, 100) → receives blocks with chain link validation
Verification: Each received block's prev_hash is checked during download
Node1 generates 5 blocks and serves them. Node2 connects, handshakes, downloads, validates, and displays the synced chain.

Say next for Lesson 10 — Cross-Compilation (the final lesson)! 🎓