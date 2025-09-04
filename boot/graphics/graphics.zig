//
// graphics.zig
// As part of the Rouge project
// Created by Maxims Enterprise in 2025
// --------------------------------------------------
// Description: Basic graphics functions for the UEFI application
// Copyright (c) 2025 Maxims Enterprise
//

//! Basic graphics functions for the UEFI application
//! It provides functions to initialize graphics, set modes, and draw basic shapes.
//! It uses the UEFI Graphics Output Protocol (GOP).
//! This is essential for any graphical boot manager or OS loader.

const std = @import("std");
const console = @import("../output/console.zig");
const uefi = std.os.uefi;
const config = @import("config");

/// A Graphics Mode supported by the Graphics Output Protocol
pub const Mode = struct {
    /// The mode ID.
    id: u32,
    /// Information about the mode.
    info: *uefi.protocol.GraphicsOutput.Mode.Info,
    /// A rating for the mode based on resolution and pixel format.
    rating: u32,
    /// A CPU-friendly rating for the mode.
    cpu_rating: u32,
};

/// The different ways of selecting a graphics mode.
pub const Capabilities = enum { highest, cpu_friendly, lowest, standard, configuration_defined };

/// Represents a color in RGBA format.
pub const Color = struct {
    /// Red component.
    r: u8,
    /// Green component.
    g: u8,
    /// Blue component.
    b: u8,
    /// Alpha component.
    a: u8,
};

/// Represents a position on the screen.
pub const Position = struct {
    /// X coordinate.
    x: u32,
    /// Y coordinate.
    y: u32,
};

/// Main Graphics structure to manage the Graphics Output Protocol.
pub const Graphics = struct {
    /// The Graphics Output Protocol instance.
    graphicsOutput: *uefi.protocol.GraphicsOutput,
    /// Available graphics modes.
    modes: []Mode,
    /// The currently selected graphics mode.
    selected_mode: ?Mode,

    const Self = @This();

    /// Initializes the Graphics Output Protocol.
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

    /// Cleans up allocated resources.
    pub fn destroy(self: *Self) !void {
        const boot_services = uefi.system_table.boot_services.?;
        try boot_services.freePool(@ptrCast(self.modes));
    }

    /// Queries and stores all available graphics modes.
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

    /// Selects the preferred graphics mode based on the given capabilities.
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
        } else if (capabilities == .configuration_defined) {
            const desired_width = config.default_resolution.width;
            const desired_height = config.default_resolution.height;
            for (0..self.graphicsOutput.mode.max_mode) |i| {
                const mode = self.modes[i];
                if (mode.info.horizontal_resolution == desired_width and mode.info.vertical_resolution == desired_height) {
                    best_mode = mode;
                    break;
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

    /// Draws a pixel at the specified position with the given color.
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

    /// Draws a line from start to end positions with the given color using Bresenham's algorithm.
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

    /// Gets the current screen size.
    pub fn getSize(self: *Self) Position {
        return Position{
            .x = self.selected_mode.?.info.horizontal_resolution,
            .y = self.selected_mode.?.info.vertical_resolution,
        };
    }
};
