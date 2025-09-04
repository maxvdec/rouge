//
// main.zig
// As part of the Rouge project
// Created by Maxims Enterprise in 2025
// --------------------------------------------------
// Description: Main entry point for the UEFI application
// Copyright (c) 2025 Maxims Enterprise
//

//! Main entry point for the UEFI application
//! The basic functions that setup everything the boot manager needs.
//! It initializes every bit that the UEFI system needs.
const std = @import("std");
const uefi = std.os.uefi;
const console = @import("rouge").console;
const time = @import("rouge").time;
const format = @import("rouge").format;
const graphics = @import("rouge").graphics;

/// Main entry point for the Boot Manager
pub fn main() void {
    console.print("Hello, World!\n");

    var out = graphics.Graphics.get() catch {
        console.printLine("Failed to get Graphics Output Protocol.");
        return;
    };
    console.printLine("Graphics Output Protocol found!");
    out.queryModes();
    console.printLine("Available Graphics Modes:");
    out.selectPreferredMode(.configuration_defined) catch |err| {
        console.printFormatted("Error occurred when selecting graphics mode: {}\n", .{err}, 100);
        return;
    };
    console.printLine("Preferred graphics mode selected!");

    for (0..out.graphicsOutput.mode.max_mode) |i| {
        const mode = out.modes[i];
        console.printFormatted("Mode {}: {} x {} @ {} bpp\n", .{ mode.id, mode.info.horizontal_resolution, mode.info.vertical_resolution, mode.info.pixel_format }, 100);
        console.printFormatted("    Score: {}, CPU Score: {}\n", .{ mode.rating, mode.cpu_rating }, 100);
    }
    console.printFormatted("Selected mode: {}\n", .{out.selected_mode.?.id}, 100);

    out.drawLine(graphics.Position{
        .x = 0,
        .y = out.getSize().y / 2,
    }, graphics.Position{ .x = out.getSize().x, .y = out.getSize().y / 2 }, graphics.Color{ .r = 0, .g = 255, .b = 0, .a = 255 });

    time.TimeDelay.fromSeconds(5).wait();
    out.destroy() catch {
        console.printLine("Failed to clean up graphics resources.");
    };
    console.printLine("Exiting Boot Manager.");
}
