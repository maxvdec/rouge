//
// format.zig
// As part of the Rouge project
// Created by Maxims Enterprise in 2025
// --------------------------------------------------
// Description: Format utilities for the UEFI application
// Copyright (c) 2025 Maxims Enterprise
//

//! Simple formatting utilities for the UEFI application
//! It provides functions to format numbers and strings into buffers.

const std = @import("std");

/// Formats a u64 value as a hexadecimal string.
pub fn hexadecimal(value: u64, comptime max_length: usize) [max_length:0]u8 {
    var buffer: [max_length:0]u8 = undefined;
    if (buffer.len < 18) return buffer;
    buffer[0] = '0';
    buffer[1] = 'x';
    const hex_chars = "0123456789ABCDEF";
    var i: usize = 17;
    var val = value;
    while (i > 1) : (i -= 1) {
        buffer[i] = hex_chars[val & 0xF];
        val >>= 4;
    }
    buffer[18] = 0; // Null-terminate
    return buffer;
}

/// Formats a u64 value as a decimal string.
pub fn decimal(value: u64, comptime max_length: usize) [max_length:0]u8 {
    var buffer: [max_length:0]u8 = undefined;
    if (value == 0) {
        buffer[0] = '0';
        return buffer;
    }
    var val = value;
    var len: usize = 0;
    // Count digits
    var temp = val;
    while (temp > 0) {
        temp /= 10;
        len += 1;
    }
    if (len > buffer.len) return buffer;
    // Fill buffer from right to left
    var i = len;
    while (val > 0) {
        i -= 1;
        buffer[i] = @intCast((val % 10) + '0');
        val /= 10;
    }
    buffer[len] = 0; // Null-terminate
    return buffer;
}

/// Formats a string with placeholders `{}` replaced by provided arguments.
pub fn string(comptime template: []const u8, args: anytype, comptime max_length: usize) [max_length:0]u8 {
    var pos: usize = 0;
    var arg_index: usize = 0;
    var i: usize = 0;
    var buffer: [max_length:0]u8 = undefined;

    while (i < template.len and pos < buffer.len) {
        if (template[i] == '{' and i + 1 < template.len and template[i + 1] == '}') {
            // Found placeholder
            if (arg_index < args.len) {
                inline for (args, 0..) |arg, idx| {
                    if (idx == arg_index) {
                        const T = @TypeOf(arg);
                        if (T == []const u8) {
                            // String argument
                            var j: usize = 0;
                            while (j < arg.len and pos < buffer.len) {
                                buffer[pos] = arg[j];
                                pos += 1;
                                j += 1;
                            }
                        }
                        break;
                    }
                }
                arg_index += 1;
            }
            i += 2;
        } else {
            buffer[pos] = template[i];
            pos += 1;
            i += 1;
        }
    }

    while (pos < buffer.len) {
        buffer[pos] = 0;
        pos += 1;
    }

    return buffer;
}
