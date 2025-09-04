//
// io.zig
// As part of the Rouge project
// Created by Maxims Enterprise in 2025
// --------------------------------------------------
// Description: I/O utilities for the Rouge project
// Copyright (c) 2025 Maxims Enterprise
//

//! Utility types and functions for I/O operations.
//! It defines traits for readable and writable entities.
//! These can be implemented by various I/O devices or streams.

const std = @import("std");

/// Represents errors that can occur during write operations.
pub const WriteError = error{
    OutOfMemory,
    CannotWrite,
    Unknown,
};

/// Represents a writable entity.
pub const Writable = struct {
    write: fn (self: *Writable, buffer: []const u8) WriteError!void,
};

/// Represents errors that can occur during read operations.
pub const ReadError = error{
    OutOfMemory,
    CannotRead,
    Unknown,
};

/// Represents a readable entity.
pub const Readable = struct {
    read: fn (self: *Readable, buffer: []u8) ReadError!void,
};
