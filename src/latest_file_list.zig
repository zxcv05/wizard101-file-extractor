const std = @import("std");
const w101 = @import("w101.zig");

fn get_list(alloc: std.mem.Allocator, client: *std.http.Client) ![]u8 {
    const buffer = try alloc.alloc(u8, 8 * 1024 * 1024); // 8MiB
    const server_headers = try alloc.alloc(u8, 1024);
    defer alloc.free(server_headers);

    var req = try client.open(
        .GET,
        try std.Uri.parse(w101.WIZ_PATCHER_BASE_URL ++ "Windows/LatestFileList.bin"),
        .{ .server_header_buffer = server_headers },
    );

    try req.send();
    try req.wait();

    const read = try req.readAll(buffer);
    return alloc.realloc(buffer, read);
}

pub fn extract_files(alloc: std.mem.Allocator, client: *std.http.Client) ![][]u8 {
    var files = std.ArrayList([]u8).init(alloc); // TODO: to slice

    const file_list_data = try get_list(alloc, client);
    defer alloc.free(file_list_data);

    var k: usize = 0;
    var i: usize = 0;
    var buffer: [1024]u8 = undefined;

    while (i < file_list_data.len) : (i += 1) {
        if (std.ascii.isPrint(file_list_data[i])) {
            buffer[k] = file_list_data[i];
            k += 1;
        } else {
            if (std.mem.startsWith(u8, buffer[0..k], w101.DATA_FILE_PREFIX)) {
                try files.append(try alloc.dupe(u8, buffer[0..k]));
            }
            k = 0;
        }
    }

    return files.toOwnedSlice();
}
