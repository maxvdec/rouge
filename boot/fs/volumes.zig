//
// volumes.zig
// As part of the Rouge project
// Created by Maxims Enterprise in 2025
// --------------------------------------------------
// Description: Volume management for the UEFI application
// Copyright (c) 2025 Maxims Enterprise
//

const std = @import("std");
const console = @import("../output/console.zig");
const uefi = std.os.uefi;

pub const Volume = struct {
    root: *uefi.protocol.File,
    name: []u8,
};

pub fn listVolumes() ![]Volume {
    const boot_services = uefi.system_table.boot_services.?;

    const handles = try boot_services.locateHandleBuffer(.{ .by_protocol = &uefi.protocol.SimpleFileSystem.guid }) orelse {
        return error.LocateHandleFailed;
    };

    var volumes: []Volume = undefined;
    const volume_buf = try boot_services.allocatePool(.loader_data, @sizeOf(Volume) * handles.len);
    @memset(volume_buf, 0);
    volumes = @as([*]Volume, @ptrCast(volume_buf))[0..handles.len];

    for (0..handles.len) |i| {
        const handle = handles[i];
        var fs = try boot_services.handleProtocol(uefi.protocol.SimpleFileSystem, handle);
        if (fs == null) {
            return error.HandleProtocolFailed;
        }

        var root = try fs.?.openVolume();

        var initial_buf: [1]u8 = [_]u8{0};
        var recorded_size: usize = 0;
        var status = root._get_info(root, &uefi.protocol.File.Info.VolumeLabel.guid, &recorded_size, &initial_buf);

        const correct_size = recorded_size;
        const buf_contents = try boot_services.allocatePool(.loader_data, correct_size);
        @memset(buf_contents, 0);
        var buf = @as([*]u8, @ptrCast(buf_contents));
        status = root._get_info(root, &uefi.protocol.File.Info.VolumeLabel.guid, &recorded_size, buf);

        if (status != uefi.Status.success) {
            return error.GetInfoFailed;
        }

        volumes[i] = Volume{
            .root = root,
            .name = buf[0..recorded_size],
        };
    }

    return volumes;
}
