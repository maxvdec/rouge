//
// console.zig
// As part of the Rouge project
// Created by Maxims Enterprise in 2025
// --------------------------------------------------
// Description: Console Utilities for printing text
// Copyright (c) 2025 Maxims Enterprise
//

//! This module handles console output for the UEFI bindings
//! It provides functions for printing messages to the console.
//! It also includes utilities for converting strings to UEFI-compatible formats.

const std = @import("std");
const uefi = std.os.uefi;

/// Converts a UTF-8 string to a UEFI-compatible UTF-16 string.
pub fn stringToUefi(comptime str: [*:0]const u8) [std.mem.len(str):0]u16 {
    var u16_str: [std.mem.len(str):0]u16 = undefined;
    for (0..std.mem.len(str)) |i| {
        u16_str[i] = @as(u16, str[i]);
    }
    u16_str[std.mem.len(str)] = 0; // Null-terminate the string
    return u16_str;
}

pub fn print(comptime message: [*:0]const u8) void {
    const con_out = uefi.system_table.con_out.?;
    _ = con_out.outputString(&stringToUefi(message)) catch {};
}

pub fn reset() void {
    const con_out = uefi.system_table.con_out.?;
    _ = con_out.reset(false) catch {};
}

pub fn clear() void {
    const con_out = uefi.system_table.con_out.?;
    _ = con_out.clearScreen() catch {};
}
