//
// graphics.zig
// As part of the Rouge project
// Created by Maxims Enterprise in 2025
// --------------------------------------------------
// Description: Basic graphics functions for the UEFI application
// Copyright (c) 2025 Maxims Enterprise
//

const std = @import("std");
const console = @import("../output/console.zig");
const uefi = std.os.uefi;

pub const Mode = struct {
    id: u32,
    info: *uefi.protocol.GraphicsOutput.Mode.Info,
    rating: u32,
    cpu_rating: u32,
};

pub const Capabilities = enum { highest, cpu_friendly, lowest, standard };

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

pub const Position = struct {
    x: u32,
    y: u32,
};

pub const Graphics = struct {
    graphicsOutput: *uefi.protocol.GraphicsOutput,
    modes: []Mode,
    selected_mode: ?Mode,

    const Self = @This();

    pub fn get() !Graphics {
        const boot_services = uefi.system_table.boot_services.?;

        const gop = try boot_services.locateProtocol(uefi.protocol.GraphicsOutput, null);
        if (gop) |protocol| {
            return Graphics{
                .graphicsOutput = protocol,
                .modes = undefined,
                .selected_mode = null,
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

        const buf = uefi.system_table.boot_services.?.allocatePool(.loader_data, @sizeOf(Mode) * mode_count) catch return;
        @memset(buf, 0);
        self.modes = @as([*]Mode, @ptrCast(buf))[0..mode_count];

        for (0..mode_count) |i| {
            const mode = self.graphicsOutput.queryMode(@intCast(i)) catch continue;
            const current_mode = &self.modes[i];
            current_mode.* = Mode{ .id = @intCast(i), .info = mode, .rating = 0, .cpu_rating = 0 };
        }
    }

    pub fn selectPreferredMode(self: *Self, capabilities: Capabilities) !void {
        for (0..self.graphicsOutput.mode.max_mode) |i| {
            var mode = &self.modes[i];
            mode.rating = 0;
            mode.cpu_rating = 0;
            mode.rating += mode.info.horizontal_resolution * mode.info.vertical_resolution;
            mode.cpu_rating += mode.info.horizontal_resolution * mode.info.vertical_resolution;
            const aspect = @as(f64, @floatFromInt(mode.info.horizontal_resolution)) / @as(f64, @floatFromInt(mode.info.vertical_resolution));
            var horizontal_bias: f64 = 1.0;

            if (aspect >= 2.0) {
                horizontal_bias = 3.0;
            } else if (aspect >= 16.0 / 9.0) {
                horizontal_bias = 2.0;
            } else if (aspect >= 4.0 / 3.0) {
                horizontal_bias = 1.5;
            } else {
                horizontal_bias = 1.0; // nearly square
            }

            mode.rating = @intCast(@as(u32, @intFromFloat(@as(f64, @floatFromInt(mode.rating)) * horizontal_bias)));
            mode.cpu_rating = @intCast(@as(u32, @intFromFloat(@as(f64, @floatFromInt(mode.cpu_rating)) * horizontal_bias)));
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
        } else if (capabilities == .standard) {
            for (0..self.graphicsOutput.mode.max_mode) |i| {
                const mode = self.modes[i];
                if (mode.info.horizontal_resolution == 1920 and mode.info.vertical_resolution == 1080) {
                    best_mode = mode;
                    break;
                } else if (mode.info.horizontal_resolution == 1280 and mode.info.vertical_resolution == 720) {
                    best_mode = mode;
                }
            }
            if (best_mode == null) {
                for (0..self.graphicsOutput.mode.max_mode) |i| {
                    const mode = self.modes[i];
                    if (best_mode == null or mode.rating > best_mode.?.rating) {
                        best_mode = mode;
                    }
                }
            }
        }

        self.selected_mode = best_mode;

        self.graphicsOutput.setMode(best_mode.?.id) catch {
            return error.FailedToSetGraphicsMode;
        };
    }

    pub fn drawPixel(self: *Self, position: Position, color: Color) void {
        var fb: [*]u8 = @ptrFromInt(@as(usize, @intCast(self.graphicsOutput.mode.frame_buffer_base)));
        const pixels_per_scan_line = self.graphicsOutput.mode.info.pixels_per_scan_line;
        const pixel_format = self.graphicsOutput.mode.info.pixel_format;
        const bytes_per_pixel = 4; // Assuming 32 bits per pixel
        const offset = (position.y * pixels_per_scan_line + position.x) * bytes_per_pixel;
        switch (pixel_format) {
            .blue_green_red_reserved_8_bit_per_color => {
                fb[offset + 0] = color.b;
                fb[offset + 1] = color.g;
                fb[offset + 2] = color.r;
                fb[offset + 3] = color.a;
            },
            .red_green_blue_reserved_8_bit_per_color => {
                fb[offset + 0] = color.r;
                fb[offset + 1] = color.g;
                fb[offset + 2] = color.b;
                fb[offset + 3] = color.a;
            },
            .bit_mask => {},
            .blt_only => {},
        }
    }

    pub fn drawLine(self: *Self, start: Position, end: Position, color: Color) void {
        var x: i32 = @as(i32, @intCast(start.x));
        var y: i32 = @as(i32, @intCast(start.y));
        const x1: i32 = @as(i32, @intCast(end.x));
        const y1: i32 = @as(i32, @intCast(end.y));

        const dx: i32 = @intCast(@abs(x1 - x));
        const dy: i32 = @intCast(@abs(y1 - y));
        const sx: i32 = if (x < x1) 1 else -1;
        const sy: i32 = if (y < y1) 1 else -1;
        var err: i32 = dx - dy;

        while (true) {
            self.drawPixel(Position{ .x = @as(u32, @intCast(x)), .y = @as(u32, @intCast(y)) }, color);
            if (x == x1 and y == y1) break;
            const e2 = err * 2;
            if (e2 > -dy) {
                err -= dy;
                x += sx;
            }
            if (e2 < dx) {
                err += dx;
                y += sy;
            }
        }
    }

    pub fn getSize(self: *Self) Position {
        return Position{
            .x = self.selected_mode.?.info.horizontal_resolution,
            .y = self.selected_mode.?.info.vertical_resolution,
        };
    }
};
