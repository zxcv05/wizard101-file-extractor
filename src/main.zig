const std = @import("std");
const w101 = @import("w101.zig");
const latest_file_list = @import("latest_file_list.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var alloc = gpa.allocator();

pub fn main() !void {
    var client = std.http.Client{
        .allocator = alloc,
    };

    const files = try latest_file_list.extract_files(alloc, &client);

    const cwd = std.fs.cwd();
    try cwd.makePath(w101.DATA_FILE_PREFIX);

    const server_header_buffer = try alloc.alloc(u8, 1024);
    defer alloc.free(server_header_buffer);

    const content_buffer = try alloc.alloc(u8, 4096);
    defer alloc.free(content_buffer);

    for (0..files.len) |i| {
        const file_name = files[i];
        defer alloc.free(file_name);

        var file = cwd.createFile(file_name, .{ .exclusive = true }) catch blk: {
            const stat = cwd.statFile(file_name) catch continue;
            if (stat.size > 8) continue;

            break :blk cwd.openFile(file_name, .{ .mode = .write_only }) catch continue;
        };
        defer file.close();

        std.debug.print("\rGetting file {d}: {s}", .{ i + 1, file_name });

        errdefer cwd.deleteFile(file_name) catch {};
        errdefer std.debug.print("\rFailed to get file! {s}\n", .{file_name});

        const url = try std.fs.path.join(alloc, &.{ w101.WIZ_PATCHER_BASE_URL, "LatestBuild/", file_name });
        defer alloc.free(url);

        for (0..3) |_| {
            var req = client.open(.GET, try std.Uri.parse(url), .{
                .server_header_buffer = server_header_buffer,
            }) catch continue;

            try req.send();
            try req.wait();

            var read: usize = content_buffer.len;
            while (read >= content_buffer.len) {
                read = try req.readAll(content_buffer);
                try file.writeAll(content_buffer[0..read]);
            }

            std.debug.print("\rGot file {d}/{d}: {s}\n", .{ i + 1, files.len, file_name });
            break;
        } else {
            std.debug.print("\rFailed to download: {s}\n", .{file_name});
        }
    }
}
