const std = @import("std");
// ============================================================
// EXERCISE 3: Zig Crypto vs C-Style API Patterns
// ============================================================
// Zig ships with a full crypto library (std.crypto). This
// exercise shows both Zig's native approach AND how to write
// C-compatible wrappers — the same pattern you'd use to call
// OpenSSL, libsodium, or secp256k1 via FFI.
//
// YOUR BLOCKCHAIN USE CASE:
//   - SHA-256 for block hashing (Zig native)
//   - HMAC for authentication tokens
//   - Key derivation patterns
//   - When to use C crypto vs Zig crypto
// ============================================================
// ---------------------------------------------------------
// STEP 1: C-style crypto API pattern
// ---------------------------------------------------------
/// Mimics C's OpenSSL SHA256 API:
///   unsigned char *SHA256(const unsigned char *d, size_t n,
///                         unsigned char *md);
///
/// This is the PATTERN you'd use when calling real C crypto.
const CryptoApi = struct {
    /// C-style: takes raw pointer + length, writes to output buffer
    fn sha256_c_style(
        data: [*]const u8,
        len: usize,
        output: [*]u8,
    ) [*]u8 {
        const slice = data[0..len];
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(slice, &hash, .{});
        @memcpy(output[0..32], &hash);
        return output;
    }
    /// C-style HMAC: key + data → MAC
    fn hmac_c_style(
        key: [*]const u8,
        key_len: usize,
        data: [*]const u8,
        data_len: usize,
        output: [*]u8,
    ) void {
        const key_slice = key[0..key_len];
        const data_slice = data[0..data_len];
        var mac: [32]u8 = undefined;
        std.crypto.auth.hmac.sha2.HmacSha256.create(&mac, data_slice, key_slice);
        @memcpy(output[0..32], &mac);
    }
    /// C-style incremental hashing (Init/Update/Final pattern)
    const HashContext = struct {
        state: std.crypto.hash.sha2.Sha256,
        fn init() HashContext {
            return .{ .state = std.crypto.hash.sha2.Sha256.init(.{}) };
        }
        fn update(self: *HashContext, data: [*]const u8, len: usize) void {
            self.state.update(data[0..len]);
        }
        fn final(self: *HashContext, output: [*]u8) void {
            var hash: [32]u8 = undefined;
            self.state.final(&hash);
            @memcpy(output[0..32], &hash);
        }
    };
};
// ---------------------------------------------------------
// STEP 2: Zig-native crypto wrappers (what you SHOULD use)
// ---------------------------------------------------------
const ZigCrypto = struct {
    /// Clean Zig-style: takes slices, returns array
    fn sha256(data: []const u8) [32]u8 {
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(data, &hash, .{});
        return hash;
    }
    /// Double SHA-256 (Bitcoin-style)
    fn doubleSha256(data: []const u8) [32]u8 {
        const first = sha256(data);
        return sha256(&first);
    }
    /// HMAC-SHA256
    fn hmacSha256(data: []const u8, key: []const u8) [32]u8 {
        var mac: [32]u8 = undefined;
        std.crypto.auth.hmac.sha2.HmacSha256.create(&mac, data, key);
        return mac;
    }
    /// BLAKE3 (modern, faster than SHA-256)
    fn blake3(data: []const u8) [32]u8 {
        var hash: [32]u8 = undefined;
        std.crypto.hash.Blake3.hash(data, &hash, .{});
        return hash;
    }
    /// Incremental hasher for streaming data
    fn hashMultiple(chunks: []const []const u8) [32]u8 {
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        for (chunks) |chunk| {
            hasher.update(chunk);
        }
        var result: [32]u8 = undefined;
        hasher.final(&result);
        return result;
    }
};
fn printHash(label: []const u8, hash: [32]u8) void {
    std.debug.print("    {s}: ", .{label});
    for (hash[0..16]) |byte| std.debug.print("{x:0>2}", .{byte});
    std.debug.print("...\n", .{});
}
pub fn main() !void {
    std.debug.print("\n=== Lesson 6.3: Crypto API Patterns ===\n\n", .{});
    const test_data = "sacrium genesis block v1.0";
    // ---------------------------------------------------------
    // C-style vs Zig-style hashing
    // ---------------------------------------------------------
    std.debug.print("  --- C-style vs Zig-style SHA-256 ---\n\n", .{});
    // C-style: raw pointers + length + output buffer
    var c_output: [32]u8 = undefined;
    _ = CryptoApi.sha256_c_style(test_data.ptr, test_data.len, &c_output);
    printHash("C-style SHA256 ", c_output);
    // Zig-style: slice in, array out — clean!
    const zig_output = ZigCrypto.sha256(test_data);
    printHash("Zig-style SHA256", zig_output);
    // Verify they produce the same result
    const match = std.mem.eql(u8, &c_output, &zig_output);
    std.debug.print("    Results match: {s}\n", .{if (match) "✅ YES" else "❌ NO"});
    // ---------------------------------------------------------
    // Double SHA-256 (Bitcoin uses this)
    // ---------------------------------------------------------
    std.debug.print("\n  --- Double SHA-256 (Bitcoin-style) ---\n\n", .{});
    const single = ZigCrypto.sha256(test_data);
    const double = ZigCrypto.doubleSha256(test_data);
    printHash("Single SHA256 ", single);
    printHash("Double SHA256 ", double);
    std.debug.print("    (Bitcoin hashes blocks with SHA256(SHA256(data)))\n", .{});
    // ---------------------------------------------------------
    // HMAC-SHA256 (authentication)
    // ---------------------------------------------------------
    std.debug.print("\n  --- HMAC-SHA256 ---\n\n", .{});
    const api_key = "node-secret-key-42";
    // C-style
    var c_mac: [32]u8 = undefined;
    CryptoApi.hmac_c_style(api_key.ptr, api_key.len, test_data.ptr, test_data.len, &c_mac);
    printHash("C-style HMAC ", c_mac);
    // Zig-style
    const zig_mac = ZigCrypto.hmacSha256(test_data, api_key);
    printHash("Zig-style HMAC", zig_mac);
    // ---------------------------------------------------------
    // BLAKE3 (modern alternative)
    // ---------------------------------------------------------
    std.debug.print("\n  --- BLAKE3 (Modern Hash) ---\n\n", .{});
    const blake3_hash = ZigCrypto.blake3(test_data);
    printHash("BLAKE3        ", blake3_hash);
    std.debug.print("    BLAKE3 is 3-5x faster than SHA-256!\n", .{});
    std.debug.print("    Consider it for your proof-driven hybrid chain.\n", .{});
    // ---------------------------------------------------------
    // Incremental hashing (Init/Update/Final)
    // ---------------------------------------------------------
    std.debug.print("\n  --- Incremental Hashing ---\n\n", .{});
    std.debug.print("    Pattern used by OpenSSL: Init → Update → Update → Final\n\n", .{});
    // C-style incremental
    var ctx = CryptoApi.HashContext.init();
    ctx.update("block_header:", "block_header:".len);
    ctx.update(test_data.ptr, test_data.len);
    var c_incremental: [32]u8 = undefined;
    ctx.final(&c_incremental);
    printHash("C incremental ", c_incremental);
    // Zig-style: pass multiple chunks
    const chunks = [_][]const u8{ "block_header:", test_data };
    const zig_incremental = ZigCrypto.hashMultiple(&chunks);
    printHash("Zig incremental", zig_incremental);
    const inc_match = std.mem.eql(u8, &c_incremental, &zig_incremental);
    std.debug.print("    Results match: {s}\n", .{if (inc_match) "✅ YES" else "❌ NO"});
    // ---------------------------------------------------------
    // When to use C crypto vs Zig crypto
    // ---------------------------------------------------------
    std.debug.print("\n  --- When to Use What ---\n\n", .{});
    std.debug.print("    ┌─────────────────────┬───────────────────────────────────────┐\n", .{});
    std.debug.print("    │ Use Zig std.crypto   │ Use C Crypto (OpenSSL/libsodium)     │\n", .{});
    std.debug.print("    ├─────────────────────┼───────────────────────────────────────┤\n", .{});
    std.debug.print("    │ SHA-256, BLAKE3     │ secp256k1 (Bitcoin ECDSA)             │\n", .{});
    std.debug.print("    │ HMAC, HKDF          │ ed25519 batch verify (libsodium)      │\n", .{});
    std.debug.print("    │ X25519 key exchange │ TLS/SSL connections                   │\n", .{});
    std.debug.print("    │ ChaCha20-Poly1305   │ Hardware AES-NI acceleration          │\n", .{});
    std.debug.print("    │ Argon2 (passwords)  │ BLS signatures (blst library)         │\n", .{});
    std.debug.print("    └─────────────────────┴───────────────────────────────────────┘\n", .{});
    std.debug.print("\n✅ Crypto API patterns mastered!\n\n", .{});
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. C crypto APIs: raw pointers + lengths + output buffers
// 2. Zig crypto APIs: slices in, arrays out — much cleaner
// 3. Zig's std.crypto is production-ready for most algorithms
// 4. Use C crypto libs for: secp256k1, BLS, TLS, hardware accel
// 5. Incremental hashing: Init → Update → Final (C pattern)
// 6. BLAKE3 is faster than SHA-256 — consider for your chain
//
// 🔬 EXPERIMENT:
//   - Hash a block header using both SHA-256 and BLAKE3
//     and time them (which is faster for 10000 hashes?)
//   - Implement a Merkle tree using doubleSha256 (Bitcoin-style)
//   - Write a C-compatible API for your blockchain's hash function
//     using export fn for other C programs to call INTO Zig
// ============================================================
