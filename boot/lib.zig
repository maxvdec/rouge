//
// lib.zig
// As part of the Rouge project
// Created by Maxims Enterprise in 2025
// --------------------------------------------------
// Description: Main library file for the UEFI application
// Copyright (c) 2025 Maxims Enterprise
//

//! Utility functions for working with UEFI.
//! It also contains the main utilties for graphics and input handling.
pub const time = @import("time.zig");
pub const console = @import("output/console.zig");
pub const io = @import("utils/io.zig");
pub const serial = @import("output/serial.zig");
