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
const volumes = @import("rouge").volumes;

/// Main entry point for the Boot Manager
pub fn main() void {
    console.reset();
    console.print("Hello, World!\n");

    const vols = volumes.listVolumes() catch |err| {
        console.printFormatted("Failed to list volumes: {}\n", .{err}, 50);
        while (true) {}
    };
    for (vols) |vol| {
        _ = vol;
    }
    time.TimeDelay.fromSeconds(10).wait();
}
