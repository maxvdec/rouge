//
// time.zig
// As part of the Rouge project
// Created by Maxims Enterprise in 2025
// --------------------------------------------------
// Description: Time Utilities for the UEFI application
// Copyright (c) 2025 Maxims Enterprise
//

const std = @import("std");
const uefi = std.os.uefi;

pub const TimeStamp = struct {
    seconds: u64,

    pub fn now() TimeStamp {
        const time = uefi.system_table.runtime_services.?.getTime() catch unreachable;
        return TimeStamp{
            .seconds = @as(u64, time.second) + @as(u64, time.nanosecond) / 1_000_000_000,
        };
    }
};

pub const TimeDelay = struct {
    nanoseconds: u64,

    pub fn new(nanoseconds: u64) TimeDelay {
        return TimeDelay{
            .nanoseconds = nanoseconds,
        };
    }

    pub fn fromSeconds(seconds: u64) TimeDelay {
        return TimeDelay{
            .nanoseconds = seconds * 1_000_000_000,
        };
    }
};

pub fn wait(delay: TimeDelay) void {
    const boot_services = uefi.system_table.boot_services.?;

    _ = boot_services.stall(delay.nanoseconds) catch {};
}
