//
// volumes.zig
// As part of the Rouge project
// Created by Maxims Enterprise in 2025
// --------------------------------------------------
// Description: Volume management for the UEFI application
// Copyright (c) 2025 Maxims Enterprise
//

const std = @import("std");
const uefi = std.os.uefi;

pub const Volume = struct {
    root: *uefi.protocol.File,
    name: []u16,
};

pub fn listVolumes() ![]Volume {
    const boot_services = uefi.system_table.boot_services.?;

    var handle_count: usize = 0;
    const handles: ?[*]uefi.Handle = null;

    var status = boot_services._locateHandle(uefi.tables.LocateSearchType.by_protocol, &uefi.protocol.SimpleFileSystem.guid, null, &handle_count, handles);
    if (status != uefi.Status.success) {
        return error.LocateHandleFailed;
    }

    var volumes: []Volume = undefined;
    const volume_buf = try boot_services.allocatePool(.loader_data, @sizeOf(Volume) * handle_count);
    @memset(volume_buf, 0);
    defer boot_services.freePool(volume_buf.ptr) catch {};
    volumes = @as([*]Volume, @ptrCast(volume_buf))[0..handle_count];

    for (0..handle_count) |i| {
        const handle = handles.?[i];
        var fs = try boot_services.handleProtocol(uefi.protocol.SimpleFileSystem, handle);
        if (fs == null) {
            return error.HandleProtocolFailed;
        }

        var root = try fs.?.openVolume();

        var buf: [512]u8 = undefined;
        status = root.getInfo(&uefi.protocol.File.Info, &buf);
        if (status != uefi.Status.success) {
            return error.GetInfoFailed;
        }

        volumes[i] = Volume{
            .root = root,
            .name = buf[0..].ptrCast(),
        };
    }

    return volumes;
}
