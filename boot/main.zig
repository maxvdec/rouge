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

/// Main entry point for the Boot Manager
pub fn main() void {
    console.clear();
    console.print("Hello, World!");
    const boot_services = uefi.system_table.boot_services.?;
    var serial_out = serial.Serial.get(boot_services) catch |err| {
        const result = format.string("Failed to get serial output: {}", .{err}, 100);
        console.print(&result);
        return;
    };

    serial_out.write("Hello from Serial!\n") catch |err| {
        const result = format.string("Failed to write to serial: {}", .{err}, 100);
        console.print(&result);
        return;
    };
    time.TimeDelay.fromSeconds(5).wait();
}
