//
// filesystem.zig
// As part of the Rouge project
// Created by Maxims Enterprise in 2025
// --------------------------------------------------
// Description: File system utilities for the UEFI application
// Copyright (c) 2025 Maxims Enterprise
//

const std = @import("std");
const uefi = std.os.uefi;
const console = @import("../output/console.zig");

pub const File = struct {
    handle: *uefi.protocol.File,
    info: uefi.protocol.File.Info,
};

pub const Directory = struct {
    handle: *uefi.protocol.File,
    info: uefi.protocol.File.Info,

    pub fn list(self: *const Directory) ![]DirectoryEntry {
        return listDirectory(self);
    }
};

pub const DirectoryEntry = struct {
    handle: *uefi.protocol.File,
    info: uefi.protocol.File.Info,
    is_directory: bool,
    name: []u8,
};

const BUFFER_SIZE = 1024;

fn countFiles(handle: *uefi.protocol.File, buffer: []u8) !usize {
    var count: usize = 0;
    var buf_len: usize = BUFFER_SIZE;

    while (true) {
        @memset(buffer, 0);
        const status = handle._read(handle, &buf_len, buffer.ptr);
        if (status != uefi.Status.success) {
            return error.ReadFailed;
        }
        if (buf_len == 0) break;

        count += 1;
    }
    return count;
}

fn convertUtf16ToUtf8(utf16_name: [*]const u16, boot_services: *uefi.tables.BootServices) ![]u8 {
    var utf16_len: usize = 0;
    while (utf16_name[utf16_len] != 0) {
        utf16_len += 1;
    }

    if (utf16_len == 0) {
        const empty_name = try boot_services.allocatePool(.loader_data, 1);
        const name_slice = @as([*]u8, @ptrCast(empty_name))[0..1];
        name_slice[0] = 0;
        return name_slice[0..0];
    }

    const utf8_buffer = try boot_services.allocatePool(.loader_data, utf16_len * 3 + 1);
    const utf8_slice = @as([*]u8, @ptrCast(utf8_buffer))[0 .. utf16_len * 3 + 1];
    @memset(utf8_slice, 0);

    var utf8_len: usize = 0;
    for (0..utf16_len) |i| {
        const char = utf16_name[i];
        if (char < 128) { // ASCII range
            utf8_slice[utf8_len] = @as(u8, @truncate(char));
            utf8_len += 1;
        } else { // Non-ASCII becomes '?'
            utf8_slice[utf8_len] = '?';
            utf8_len += 1;
        }
    }

    return utf8_slice[0..utf8_len];
}

pub fn listDirectory(dir: *const Directory) ![]DirectoryEntry {
    const boot_services = uefi.system_table.boot_services.?;

    _ = try dir.handle.setPosition(0);

    // First pass: count entries
    const buffer = try boot_services.allocatePool(.loader_data, BUFFER_SIZE);
    var entry_count: usize = 0;

    while (true) {
        var buf_len: usize = BUFFER_SIZE;
        @memset(@as([*]u8, @ptrCast(buffer))[0..BUFFER_SIZE], 0);

        const status = dir.handle._read(dir.handle, &buf_len, buffer.ptr);

        if (status != uefi.Status.success or buf_len == 0) {
            break;
        }

        const name_offset = @sizeOf(uefi.protocol.File.Info);
        const name_ptr = @as([*]const u16, @ptrCast(@alignCast(@as([*]u8, @ptrCast(buffer)) + name_offset)));

        // Get filename length
        var name_len: usize = 0;
        while (name_ptr[name_len] != 0) name_len += 1;

        entry_count += 1;
    }

    console.printFormatted("Found {} directory entries\n", .{entry_count}, 50);

    const entries_buffer = try boot_services.allocatePool(.loader_data, @sizeOf(DirectoryEntry) * entry_count);
    const entries = @as([*]DirectoryEntry, @ptrCast(entries_buffer))[0..entry_count];
    @memset(@as([*]u8, @ptrCast(entries_buffer))[0 .. @sizeOf(DirectoryEntry) * entry_count], 0);

    // Second pass: populate entries
    _ = try dir.handle.setPosition(0);
    var current_entry: usize = 0;

    while (current_entry < entry_count) {
        var buf_len: usize = BUFFER_SIZE;
        @memset(@as([*]u8, @ptrCast(buffer))[0..BUFFER_SIZE], 0);

        const status = dir.handle._read(dir.handle, &buf_len, buffer.ptr);

        if (status != uefi.Status.success or buf_len == 0) {
            break;
        }

        const info = @as(*uefi.protocol.File.Info, @ptrCast(@alignCast(buffer)));
        const name_offset = @sizeOf(uefi.protocol.File.Info);
        const name_ptr = @as([*]const u16, @ptrCast(@alignCast(@as([*]u8, @ptrCast(buffer)) + name_offset)));

        const name_utf8 = convertUtf16ToUtf8(name_ptr, boot_services) catch |err| {
            console.printFormatted("Failed to convert filename: {}\n", .{err}, 50);
            continue;
        };

        entries[current_entry] = DirectoryEntry{
            .handle = dir.handle,
            .info = info.*,
            .is_directory = info.file.attribute.directory,
            .name = name_utf8,
        };

        current_entry += 1;
    }

    return entries[0..current_entry];
}
