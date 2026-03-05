const std = @import("std");
// ============================================================
// EXERCISE 3: Type Reflection — @typeInfo, Field Iteration
// ============================================================
// Zig can inspect ANY type at compile time using @typeInfo.
// You can iterate struct fields, check types, and generate
// code — all at compile time.
//
// YOUR BLOCKCHAIN USE CASE:
//   - Auto-generate serialization/deserialization for any struct
//   - Build a debug inspector that prints any blockchain type
//   - Validate struct layouts match the wire protocol
// ============================================================
const Transaction = struct {
    sender: u64,
    receiver: u64,
    amount: u64,
    fee: u64,
    nonce: u64,
};
const BlockHeader = struct {
    version: u32,
    height: u64,
    prev_hash: [32]u8,
    merkle_root: [32]u8,
    timestamp: u64,
    difficulty: u32,
    nonce: u64,
};
const PeerInfo = struct {
    id: u64,
    port: u16,
    reputation: i32,
    is_validator: bool,
    last_seen: u64,
};
// ---------------------------------------------------------
// STEP 1: Inspect struct fields at comptime
// ---------------------------------------------------------
/// Print the layout of any struct type — computed at compile time
fn printTypeInfo(comptime T: type) void {
    const info = @typeInfo(T);
    switch (info) {
        .@"struct" => |s| {
            std.debug.print("    struct {s} ({d} bytes, {d} fields):\n", .{
                @typeName(T),
                @sizeOf(T),
                s.fields.len,
            });
            inline for (s.fields) |field| {
                std.debug.print("      .{s:<16} : {s:<20} ({d} bytes, offset {d})\n", .{
                    field.name,
                    @typeName(field.type),
                    @sizeOf(field.type),
                    @offsetOf(T, field.name),
                });
            }
        },
        else => {
            std.debug.print("    {s}: not a struct\n", .{@typeName(T)});
        },
    }
}
// ---------------------------------------------------------
// STEP 2: Auto-generate debug printing for any struct
// ---------------------------------------------------------
/// Automatically print all fields of any struct instance
fn debugPrint(comptime T: type, value: *const T) void {
    const info = @typeInfo(T).@"struct";
    std.debug.print("    {s} {{\n", .{@typeName(T)});
    inline for (info.fields) |field| {
        const field_value = @field(value.*, field.name);
        if (field.type == bool) {
            std.debug.print("      .{s} = {}\n", .{ field.name, field_value });
        } else if (field.type == u64 or field.type == u32 or field.type == u16 or field.type == i32) {
            std.debug.print("      .{s} = {d}\n", .{ field.name, field_value });
        } else if (@typeInfo(field.type) == .array) {
            std.debug.print("      .{s} = [", .{field.name});
            const arr = &field_value;
            const show = @min(arr.len, 4);
            for (arr[0..show]) |byte| {
                std.debug.print("{x:0>2}", .{byte});
            }
            if (arr.len > 4) std.debug.print("...({d} bytes)", .{arr.len});
            std.debug.print("]\n", .{});
        } else {
            std.debug.print("      .{s} = (complex type)\n", .{field.name});
        }
    }
    std.debug.print("    }}\n", .{});
}
// ---------------------------------------------------------
// STEP 3: Compile-time struct validation
// ---------------------------------------------------------
/// Validate a struct is suitable for wire serialization
fn validateWireFormat(comptime T: type) void {
    const info = @typeInfo(T).@"struct";
    // Rule 1: No pointers allowed (can't serialize pointers!)
    inline for (info.fields) |field| {
        const field_info = @typeInfo(field.type);
        if (field_info == .pointer) {
            @compileError("Wire format struct cannot contain pointer: " ++ field.name);
        }
        if (field_info == .@"struct") {
            // Recursively validate nested structs
            validateWireFormat(field.type);
        }
    }
    // Rule 2: Must be <= 1024 bytes
    if (@sizeOf(T) > 1024) {
        @compileError("Wire format struct too large: " ++ @typeName(T));
    }
}
// ---------------------------------------------------------
// STEP 4: Compile-time field counter by type
// ---------------------------------------------------------
/// Count how many fields of a given type exist in a struct
fn countFieldsOfType(comptime T: type, comptime FieldType: type) usize {
    const info = @typeInfo(T).@"struct";
    var count: usize = 0;
    inline for (info.fields) |field| {
        if (field.type == FieldType) count += 1;
    }
    return count;
}
// ---------------------------------------------------------
// STEP 5: Auto-generate a zero/default value for any struct
// ---------------------------------------------------------
fn zeroInit(comptime T: type) T {
    const info = @typeInfo(T).@"struct";
    var result: T = undefined;
    inline for (info.fields) |field| {
        if (field.type == bool) {
            @field(result, field.name) = false;
        } else if (@typeInfo(field.type) == .array) {
            @memset(&@field(result, field.name), 0);
        } else if (@typeInfo(field.type) == .int) {
            @field(result, field.name) = 0;
        }
    }
    return result;
}
pub fn main() !void {
    std.debug.print("\n=== Lesson 5.3: Type Reflection ===\n\n", .{});
    // ---------------------------------------------------------
    // Struct layout inspection
    // ---------------------------------------------------------
    std.debug.print("  --- Type Layouts ---\n\n", .{});
    printTypeInfo(Transaction);
    std.debug.print("\n", .{});
    printTypeInfo(BlockHeader);
    std.debug.print("\n", .{});
    printTypeInfo(PeerInfo);
    // ---------------------------------------------------------
    // Auto debug printing
    // ---------------------------------------------------------
    std.debug.print("\n  --- Auto Debug Print ---\n\n", .{});
    const tx = Transaction{ .sender = 42, .receiver = 99, .amount = 5000, .fee = 50, .nonce = 7 };
    debugPrint(Transaction, &tx);
    std.debug.print("\n", .{});
    var header: BlockHeader = undefined;
    header.version = 1;
    header.height = 1337;
    @memset(&header.prev_hash, 0xAB);
    @memset(&header.merkle_root, 0xCD);
    header.timestamp = 1708900000;
    header.difficulty = 24;
    header.nonce = 999999;
    debugPrint(BlockHeader, &header);
    std.debug.print("\n", .{});
    const peer = PeerInfo{ .id = 7, .port = 8333, .reputation = 95, .is_validator = true, .last_seen = 1708900000 };
    debugPrint(PeerInfo, &peer);
    // ---------------------------------------------------------
    // Wire format validation (compile-time!)
    // ---------------------------------------------------------
    std.debug.print("\n  --- Wire Format Validation (comptime) ---\n", .{});
    // These run at compile time — if they fail, BUILD fails
    comptime validateWireFormat(Transaction);
    comptime validateWireFormat(BlockHeader);
    comptime validateWireFormat(PeerInfo);
    std.debug.print("    Transaction: ✅ wire-safe\n", .{});
    std.debug.print("    BlockHeader: ✅ wire-safe\n", .{});
    std.debug.print("    PeerInfo:    ✅ wire-safe\n", .{});
    // Uncomment this to see a compile error:
    // const BadStruct = struct { name: []const u8 }; // has a pointer!
    // comptime validateWireFormat(BadStruct);
    // ---------------------------------------------------------
    // Field counting
    // ---------------------------------------------------------
    std.debug.print("\n  --- Field Analysis (comptime) ---\n", .{});
    std.debug.print("    Transaction u64 fields: {d}\n", .{comptime countFieldsOfType(Transaction, u64)});
    std.debug.print("    BlockHeader u64 fields: {d}\n", .{comptime countFieldsOfType(BlockHeader, u64)});
    std.debug.print("    BlockHeader u32 fields: {d}\n", .{comptime countFieldsOfType(BlockHeader, u32)});
    std.debug.print("    PeerInfo bool fields:   {d}\n", .{comptime countFieldsOfType(PeerInfo, bool)});
    // ---------------------------------------------------------
    // Zero initialization
    // ---------------------------------------------------------
    std.debug.print("\n  --- Auto Zero Init ---\n\n", .{});
    const zero_tx = comptime zeroInit(Transaction);
    debugPrint(Transaction, &zero_tx);
    std.debug.print("\n✅ Type reflection mastered!\n\n", .{});
}
// ============================================================
// 🧠 KEY TAKEAWAYS:
//
// 1. @typeInfo(T) returns full type metadata at compile time
// 2. @typeInfo(T).@"struct".fields = iterate all struct fields
// 3. @field(value, "name") = access field by comptime string
// 4. @offsetOf(T, "field") = byte offset (for wire protocols!)
// 5. @typeName(T) = type name as a string
// 6. inline for over fields = generates specialized code per field
//
// 🔬 EXPERIMENT:
//   - Add a struct with a []const u8 field and try
//     validateWireFormat — see the compile error
//   - Write a comptimeHash that includes field NAMES in the hash
//   - Build an auto-serializer that writes fields as JSON
// ============================================================
