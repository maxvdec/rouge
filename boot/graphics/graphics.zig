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
    modes: [*]Mode,

    const Self = @This();

    pub fn get() !Graphics {
        const boot_services = uefi.system_table.boot_services.?;

        const gop = try boot_services.locateProtocol(uefi.protocol.GraphicsOutput, null);
        if (gop) |protocol| {
            return Graphics{
                .graphicsOutput = protocol,
                .modes = undefined,
            };
        } else {
            return error.GraphicsOutputNotFound;
        }
    }

    pub fn destroy(self: *Self) !void {
        const boot_services = uefi.system_table.boot_services.?;
        try boot_services.freePool(self.modes);
    }

    pub fn queryModes(self: *Self) void {
        const mode_count = self.graphicsOutput.mode.max_mode;
        var buffer = uefi.system_table.boot_services.?.allocatePool(.loader_data, @sizeOf(Mode) * mode_count) catch return;
        self.modes = @ptrCast(&buffer);
        for (0..mode_count) |i| {
            const mode = self.graphicsOutput.queryMode(@intCast(i)) catch continue;
            self.modes[i] = Mode{ .id = @intCast(i), .info = mode, .rating = 0, .cpu_rating = 0 };
        }
    }

    pub fn selectPreferredMode(self: *Self, capabilities: Capabilities) !void {
        for (0..self.graphicsOutput.mode.max_mode) |i| {
            var mode = self.modes[i];
            mode.rating = 0;
            mode.cpu_rating = 0;
            mode.rating += mode.info.horizontal_resolution * mode.info.vertical_resolution;
            mode.cpu_rating += mode.info.horizontal_resolution * mode.info.vertical_resolution;
            switch (mode.info.pixel_format) {
                .blue_green_red_reserved_8_bit_per_color, .red_green_blue_reserved_8_bit_per_color => {
                    mode.rating += 1000;
                    mode.cpu_rating += 1000;
                },
                .bit_mask => {
                    mode.rating += 500;
                    mode.cpu_rating += 2000;
                },
                .blt_only => {
                    mode.rating += 100;
                    mode.cpu_rating += 3000;
                },
            }
            mode.rating += @intCast(mode.info.pixels_per_scan_line);
            mode.cpu_rating -= @intCast(mode.info.pixels_per_scan_line);
        }

        var best_mode: ?Mode = null;

        if (capabilities == .highest) {
            for (0..self.graphicsOutput.mode.max_mode) |i| {
                const mode = self.modes[i];
                if (best_mode == null or mode.rating > best_mode.?.rating) {
                    best_mode = mode;
                }
            }
        } else if (capabilities == .cpu_friendly) {
            for (0..self.graphicsOutput.mode.max_mode) |i| {
                const mode = self.modes[i];
                if (best_mode == null or mode.cpu_rating > best_mode.?.cpu_rating) {
                    best_mode = mode;
                }
            }
        } else if (capabilities == .lowest) {
            for (0..self.graphicsOutput.mode.max_mode) |i| {
                const mode = self.modes[i];
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
