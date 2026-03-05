const std = @import("std");
const net = std.net;
const http = std.http;

pub fn main() !void {
    const addr = try net.Address.parseIp4("127.0.0.1", 8080);
    var server = try addr.listen(.{ .reuse_address = true });
    defer server.deinit();

    std.debug.print("Server listening on http://127.0.0.1:8080\n", .{});

    while (true) {
        var res = try server.accept();
        defer res.stream.close();

        // 1. Setup the Buffers
        // var read_buffer: [4096]u8 = undefined;
        // var write_buffer: [4096]u8 = undefined;

        // 2. Initialize the HTTP Server directly using the stream's interfaces
        // In 0.15.2, we wrap the stream in a BufferedReader/BufferedWriter
        // to match the interface requirements of the HTTP Server.
        var br = std.io.bufferedReader(res.stream.reader());
        var bw = std.io.bufferedWriter(res.stream.writer());

        // 3. Get the generic "AnyReader" and "AnyWriter" from the buffered wrappers
        var reader = br.reader();
        var writer = bw.writer();

        var http_server = http.Server.init(&reader.any(), &writer.any());

        // 4. Handle the Request
        var head_buffer: [8192]u8 = undefined;
        var request = try http_server.receiveHead(&head_buffer);

        if (std.mem.eql(u8, request.head.target, "/api/hello")) {
            try request.respond("{\"status\":\"success\"}", .{
                .extra_headers = &.{.{ .name = "content-type", .value = "application/json" }},
            });
        }
    }
}
