//
// graphics.zig
// As part of the Rouge project
// Created by Maxims Enterprise in 2025
// --------------------------------------------------
// Description: Basic graphics functions for the UEFI application
// Copyright (c) 2025 Maxims Enterprise
//

const std = @import("std");
const uefi = std.os.uefi;

pub const Graphics = struct {
    graphicsOutput: *uefi.protocol.GraphicsOutput,

    const Self = @This();

    pub fn get() !Graphics {
        const boot_services = uefi.system_table.boot_services.?;

        const gop = try boot_services.locateProtocol(uefi.protocol.GraphicsOutput, null);
        if (gop) |protocol| {
            return Graphics{
                .graphicsOutput = protocol,
            };
        } else {
            return error.GraphicsOutputNotFound;
        }
    }
};
