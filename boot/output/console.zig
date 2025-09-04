//
// console.zig
// As part of the Rouge project
// Created by Maxims Enterprise in 2025
// --------------------------------------------------
// Description: Console Utilities for printing text
// Copyright (c) 2025 Maxims Enterprise
//

//! Console output for the UEFI bindings
//! It provides functions for printing messages to the console.
//! It also includes utilities for converting strings to UEFI-compatible formats.

const std = @import("std");
const uefi = std.os.uefi;

/// Maximum length for UEFI string conversion
const MAX_LEN: comptime_int = 512;

/// Static buffer for UEFI string conversion
var u16_str: [MAX_LEN]u16 = undefined;

/// Converts a UTF-8 string to a UEFI-compatible UTF-16 string.
/// Uses a static buffer, so subsequent calls will overwrite previous results.
pub fn stringToUefi(str: [*:0]const u8) [*:0]u16 {
    const str_len = std.mem.len(str);
    if (str_len >= MAX_LEN) {
        u16_str[0] = 0; // Return empty string if too long
        return @ptrCast(&u16_str);
    }

    for (0..str_len) |i| {
        u16_str[i] = @as(u16, str[i]);
    }
    u16_str[str_len] = 0; // Null-terminate

    return @ptrCast(&u16_str);
}

/// Prints a message to the UEFI console.
pub fn print(message: [*:0]const u8) void {
    const con_out = uefi.system_table.con_out.?;
    var pos = std.mem.len(message);
    var trim_back: usize = 0;
    while (pos > 0) : (pos -= 1) {
        if (message[pos - 1] == '\n' or message[pos - 1] == '\r' or message[pos - 1] == ' ') {
            trim_back += 1;
        } else {
            break;
        }
    }
    for (0..std.mem.len(message) - trim_back) |i| {
        var buffer: [2]u16 = undefined;
        buffer[0] = @as(u16, message[i]);
        buffer[1] = 0; // Null-terminate
        _ = con_out.outputString(@ptrCast(&buffer)) catch {};
    }
}

/// Prints a formatted message to the UEFI console.
pub fn printFormatted(message: [*:0]const u8, args: anytype, comptime max_length: usize) void {
    const formatted = @import("../utils/format.zig").string(message, args, max_length);
    print(&formatted);
}

/// Resets the UEFI console.
pub fn reset() void {
    const con_out = uefi.system_table.con_out.?;
    _ = con_out.reset(false) catch {};
}

/// Clears the UEFI console.
pub fn clear() void {
    const con_out = uefi.system_table.con_out.?;
    _ = con_out.clearScreen() catch {};
}
