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
const serial = @import("rouge").serial;
const format = @import("rouge").format;
const graphics = @import("graphics/graphics.zig");

/// Main entry point for the Boot Manager
pub fn main() void {
    console.print("Hello, World!");
    const boot_services = uefi.system_table.boot_services.?;
    serial.init(boot_services) catch {};
    serial.print("Hello, World!\n");

    time.TimeDelay.fromSeconds(5).wait();
    var out = graphics.Graphics.get() catch |err| {
        std.debug.print("Failed to get graphics: {}\n", .{err});
        return;
    };
    out.graphicsOutput.setMode(0);

    const boot_services = uefi.system_table.boot_services.?;

    _ = boot_services.stall(5 * 1000 * 1000) catch {};
}
