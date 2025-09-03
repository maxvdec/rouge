//
// time.zig
// As part of the Rouge project
// Created by Maxims Enterprise in 2025
// --------------------------------------------------
// Description: Time Utilities for the UEFI application
// Copyright (c) 2025 Maxims Enterprise
//

//! Time Utilities for the UEFI application

const std = @import("std");
const uefi = std.os.uefi;

/// Represents a point in time.
pub const TimeStamp = struct {
    /// The number of seconds since the epoch.
    seconds: u64,

    /// Gets the current time.
    pub fn now() TimeStamp {
        const time = uefi.system_table.runtime_services.?.getTime() catch unreachable;
        return TimeStamp{
            .seconds = @as(u64, time.second) + @as(u64, time.nanosecond) / 1_000_000_000,
        };
    }
};

/// Represents a delay in time.
pub const TimeDelay = struct {
    /// The number of nanoseconds to wait.
    nanoseconds: u64,

    /// Creates a new TimeDelay.
    pub fn new(nanoseconds: u64) TimeDelay {
        return TimeDelay{
            .nanoseconds = nanoseconds,
        };
    }

    /// Creates a new TimeDelay from seconds.
    pub fn fromSeconds(seconds: u64) TimeDelay {
        return TimeDelay{
            .nanoseconds = seconds * 1_000_000_000,
        };
    }

    /// Waits for the specified amount of time.
    pub fn wait(delay: TimeDelay) void {
        const boot_services = uefi.system_table.boot_services.?;

        _ = boot_services.stall(delay.nanoseconds) catch {};
    }
};
