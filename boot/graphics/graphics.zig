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

pub const Mode = struct {
    id: u32,
    info: *uefi.protocol.GraphicsOutput.Mode.Info,
    rating: u32,
    cpu_rating: u32,
};

pub const Capabilities = enum {
    highest,
    cpu_friendly,
    lowest,
};

pub const Graphics = struct {
    graphicsOutput: *uefi.protocol.GraphicsOutput,
    modes: []Mode,

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

    pub fn queryModes(self: *Self) void {
        const mode_count = self.graphicsOutput.mode.?.max_mode;
        for (mode_count) |i| {
            const mode = self.graphicsOutput.queryMode(self.graphicsOutput, i) catch continue;
            self.modes[i] = Mode{
                .id = i,
                .info = mode,
            };
        }
    }

    pub fn selectPreferredMode(self: *Self, capabilities: Capabilities) !void {
        for (self.modes) |mode| {
            mode.rating = 0;
            mode.cpu_rating = 0;
            mode.rating += mode.info.resolution_horizontal * mode.info.resolution_vertical;
            mode.cpu_rating += mode.info.resolution_horizontal * mode.info.resolution_vertical;
            switch (mode.info.pixel_format) {
                .PixelBlueGreenRedReserved8BitPerColor, .PixelRedGreenBlueReserved8BitPerColor => {
                    mode.rating += 1000;
                    mode.cpu_rating += 1000;
                },
                .PixelBitMask => {
                    mode.rating += 500;
                    mode.cpu_rating += 2000;
                },
                .PixelBltOnly => {
                    mode.rating += 100;
                    mode.cpu_rating += 3000;
                },
                else => {},
            }
            mode.rating += @as(i32, mode.info.pixels_per_scan_line);
            mode.cpu_rating -= @as(i32, mode.info.pixels_per_scan_line);
        }

        var best_mode: ?Mode = null;

        if (capabilities == .highest) {
            for (self.modes) |mode| {
                if (best_mode == null or mode.rating > best_mode.?.rating) {
                    best_mode = mode;
                }
            }
        } else if (capabilities == .cpu_friendly) {
            for (self.modes) |mode| {
                if (best_mode == null or mode.cpu_rating > best_mode.?.cpu_rating) {
                    best_mode = mode;
                }
            }
        } else if (capabilities == .lowest) {
            for (self.modes) |mode| {
                if (best_mode == null or mode.rating < best_mode.?.rating) {
                    best_mode = mode;
                }
            }
        }

        self.graphicsOutput.setMode(best_mode.?.id) catch {
            return error.FailedToSetGraphicsMode;
        };
    }
};
