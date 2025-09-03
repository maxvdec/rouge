//
// io.zig
// As part of the Rouge project
// Created by Maxims Enterprise in 2025
// --------------------------------------------------
// Description: I/O utilities for the Rouge project
// Copyright (c) 2025 Maxims Enterprise
//

const std = @import("std");

pub const WriteError = error{
    OutOfMemory,
    CannotWrite,
    Unknown,
};

pub const Writable = struct {
    write: fn (self: *Writable, buffer: []const u8) WriteError!void,
};

pub const ReadError = error{
    OutOfMemory,
    CannotRead,
    Unknown,
};

pub const Readable = struct {
    read: fn (self: *Readable, buffer: []u8) ReadError!void,
};
