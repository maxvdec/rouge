//
// format.zig
// As part of the Rouge project
// Created by Maxims Enterprise in 2025
// --------------------------------------------------
// Description: Format utilities for the UEFI application
// Copyright (c) 2025 Maxims Enterprise
//

const std = @import("std");

pub fn hexadecimal(value: u64, buffer: []u8) []u8 {
    if (buffer.len < 18) return buffer[0..0];

    buffer[0] = '0';
    buffer[1] = 'x';

    const hex_chars = "0123456789ABCDEF";
    var i: usize = 17;
    var val = value;

    while (i > 1) : (i -= 1) {
        buffer[i] = hex_chars[val & 0xF];
        val >>= 4;
    }

    return buffer[0..18];
}

pub fn decimal(value: u64, buffer: []u8) []u8 {
    if (buffer.len == 0) return buffer[0..0];
    if (value == 0) {
        buffer[0] = '0';
        return buffer[0..1];
    }

    var val = value;
    var len: usize = 0;

    // Count digits
    var temp = val;
    while (temp > 0) {
        temp /= 10;
        len += 1;
    }

    if (len > buffer.len) return buffer[0..0];

    // Fill buffer from right to left
    var i = len;
    while (val > 0) {
        i -= 1;
        buffer[i] = @intCast((val % 10) + '0');
        val /= 10;
    }

    return buffer[0..len];
}

pub fn string(comptime template: []const u8, args: anytype, buffer: []u8) []u8 {
    var pos: usize = 0;
    var arg_index: usize = 0;
    var i: usize = 0;

    while (i < template.len and pos < buffer.len) {
        if (template[i] == '{' and i + 1 < template.len and template[i + 1] == '}') {
            // Found placeholder
            if (arg_index < args.len) {
                const arg = args[arg_index];
                const T = @TypeOf(arg);

                if (T == []const u8) {
                    // String argument
                    var j: usize = 0;
                    while (j < arg.len and pos < buffer.len) {
                        buffer[pos] = arg[j];
                        pos += 1;
                        j += 1;
                    }
                } else if (@typeInfo(T) == .Int) {
                    // Integer argument - format as decimal
                    var temp_buf: [32]u8 = undefined;
                    const formatted = decimal(@intCast(arg), &temp_buf);
                    var j: usize = 0;
                    while (j < formatted.len and pos < buffer.len) {
                        buffer[pos] = formatted[j];
                        pos += 1;
                        j += 1;
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

    return buffer[0..pos];
}
