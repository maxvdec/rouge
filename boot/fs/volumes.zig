//
// volumes.zig
// As part of the Rouge project
// Created by Maxims Enterprise in 2025
// --------------------------------------------------
// Description: Volume management for the UEFI application
// Copyright (c) 2025 Maxims Enterprise
//

//! Volume management for the UEFI application
//! This module provides functions to list and manage volumes in the UEFI environment.
//! It interacts with UEFI protocols to retrieve volume information.
//! It also provides error handling for volume operations.
//! The module is designed to be used in the boot manager context.

const std = @import("std");
const console = @import("../output/console.zig");
const uefi = std.os.uefi;
const file = @import("filesystem.zig");

/// A Volume represents a mounted file system volume in UEFI.
pub const Volume = struct {
    /// The root directory of the volume.
    root: *uefi.protocol.File,
    /// The name of the volume.
    name: []u8,
    /// The UEFI handle associated with the volume.
    handle: uefi.Handle,

    /// Retrieves the root directory of the volume.
    pub fn getRoot(self: *const Volume) file.Directory {
        return file.Directory{
            .handle = self.root,
            .info = undefined,
        };
    }
};

/// Function that lists all available volumes in the UEFI environment.
pub fn listVolumes() ![]Volume {
    const boot_services = uefi.system_table.boot_services.?;

    const handles = try boot_services.locateHandleBuffer(.{ .by_protocol = &uefi.protocol.SimpleFileSystem.guid }) orelse {
        return error.LocateHandleFailed;
    };

    console.printFormatted("Found {} file system handles\n", .{handles.len}, 50);

    const volume_buf = try boot_services.allocatePool(.loader_data, @sizeOf(Volume) * handles.len);
    @memset(volume_buf, 0);
    var volumes = @as([*]Volume, @ptrCast(volume_buf))[0..handles.len];

    var valid_volumes: usize = 0;

    for (0..handles.len) |i| {
        const handle = handles[i];
        console.printFormatted("Processing handle {}\n", .{i}, 50);

        var fs = boot_services.handleProtocol(uefi.protocol.SimpleFileSystem, handle) catch |err| {
            console.printFormatted("Failed to get SimpleFileSystem protocol for handle {}: {}\n", .{ i, err }, 100);
            continue;
        };

        if (fs == null) {
            console.printFormatted("SimpleFileSystem protocol is null for handle {}\n", .{i}, 50);
            continue;
        }

        const root = fs.?.openVolume() catch |err| {
            console.printFormatted("Failed to open volume for handle {}: {}\n", .{ i, err }, 100);
            continue;
        };

        const volume_name = try getVolumeLabel(root, boot_services);

        volumes[valid_volumes] = Volume{
            .root = root,
            .name = volume_name,
            .handle = handle,
        };

        console.printFormatted("Added volume {}: '{}'\n", .{ valid_volumes, volume_name }, 200);
        valid_volumes += 1;
    }

    return volumes[0..valid_volumes];
}

/// Retrieves the volume label for a given root directory.
fn getVolumeLabel(root: *uefi.protocol.File, boot_services: *uefi.tables.BootServices) ![]u8 {
    var buffer_size: usize = 0;
    var status = root._get_info(root, &uefi.protocol.File.Info.VolumeLabel.guid, &buffer_size, null);

    if (status != uefi.Status.buffer_too_small and status != uefi.Status.success) {
        return error.GetInfoFailed;
    }

    if (buffer_size == 0) {
        const empty_name = try boot_services.allocatePool(.loader_data, 1);
        const name_slice = @as([*]u8, @ptrCast(empty_name))[0..1];
        name_slice[0] = 0;
        return name_slice[0..0];
    }

    const label_buffer = try boot_services.allocatePool(.loader_data, buffer_size);
    @memset(label_buffer, 0);

    status = root._get_info(root, &uefi.protocol.File.Info.VolumeLabel.guid, &buffer_size, label_buffer.ptr);

    if (status != uefi.Status.success) {
        return error.GetInfoFailed;
    }

    const label_ptr = @as([*]u16, @ptrCast(@alignCast(label_buffer)));

    var utf16_len: usize = 0;
    while (utf16_len < buffer_size / 2 and label_ptr[utf16_len] != 0) {
        utf16_len += 1;
    }

    const utf8_buffer = try boot_services.allocatePool(.loader_data, utf16_len + 1);
    const utf8_slice = @as([*]u8, @ptrCast(utf8_buffer))[0 .. utf16_len + 1];
    @memset(utf8_slice, 0);

    for (0..utf16_len) |j| {
        if (label_ptr[j] < 128) {
            utf8_slice[j] = @as(u8, @truncate(label_ptr[j]));
        } else {
            utf8_slice[j] = '?';
        }
    }

    return utf8_slice[0..utf16_len];
}
