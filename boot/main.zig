//
// main.zig
// As part of the Rouge project
// Created by Maxims Enterprise in 2025
// --------------------------------------------------
// Description: Main entry point for the UEFI application
// Copyright (c) 2025 Maxims Enterprise
//

//! Main entry point for the UEFI application
//! This module contains the basic functions that setup everything the boot manager needs.
//! It initializes every bit that the UEFI system needs.
const std = @import("std");
const uefi = std.os.uefi;

/// Function that converts a string made out of UTF-8 bytes to a UEFI string (UTF-16)
fn toUefiString(comptime str: [*:0]const u8) [std.mem.len(str):0]u16 {
    var u16_str: [std.mem.len(str):0]u16 = undefined;
    for (0..std.mem.len(str)) |i| {
        u16_str[i] = @as(u16, str[i]);
    }
    return u16_str;
}

/// Main entry point for the Boot Manager
pub fn main() void {
    const con_out = uefi.system_table.con_out.?;

    _ = con_out.reset(false) catch {};

    _ = con_out.outputString(&toUefiString("Hello, World!\n")) catch {};

    const boot_services = uefi.system_table.boot_services.?;

    _ = boot_services.stall(5 * 1000 * 1000) catch {};
}
