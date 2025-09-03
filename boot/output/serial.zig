//
// serial.zig
// As part of the Rouge project
// Created by Maxims Enterprise in 2025
// --------------------------------------------------
// Description: Serial output functions for the UEFI application
// Copyright (c) 2025 Maxims Enterprise
//

const std = @import("std");
const uefi = std.os.uefi;
const Status = uefi.Status;
const Guid = uefi.Guid;
const io = @import("../utils/io.zig");

const NO_PARITY = 0;
const STOP_BITS_1 = 0;

const EFI_SERIAL_IO_PROTOCOL_GUID = Guid{
    .time_low = 0xBB25CF6F,
    .time_mid = 0xF1D4,
    .time_high_and_version = 0x11D2,
    .clock_seq_high_and_reserved = 0x9A,
    .clock_seq_low = 0x0C,
    .node = .{ 0x00, 0x90, 0x27, 0x3F, 0xC1, 0xFD },
};

pub const EfiSerialIOProtocol = struct {
    const Self = @This();

    reset: *const fn (self: *Self) uefi.Status,
    setAttributes: *const fn (self: *Self, baudRate: u32, recieveFifoDepth: u32, timeout: u32, parity: u8, dataBits: u8, stopBits: u8) uefi.Status,
    setControl: *const fn (self: *Self, control: u32) uefi.Status,
    getControl: *const fn (self: *Self, control: *u32) uefi.Status,
    Write: *const fn (self: *Self, BufferSize: u64, Buffer: [*]const u8, NumberOfBytesWritten: *u64) uefi.Status,
    Read: *const fn (self: *Self, BufferSize: *u64, Buffer: [*]u8) uefi.Status,
};

pub const SerialError = error{
    failedToLocateProtocol,
};

pub const Serial = struct {
    serial: *EfiSerialIOProtocol,

    pub fn get(boot_services: *uefi.tables.BootServices) SerialError!Serial {
        var serial_io: ?*EfiSerialIOProtocol = undefined;
        var status = boot_services._locateProtocol(&EFI_SERIAL_IO_PROTOCOL_GUID, null, @ptrCast(&serial_io));
        if (status != uefi.Status.success) {
            return SerialError.failedToLocateProtocol;
        }
        if (serial_io == null) {
            return SerialError.failedToLocateProtocol;
        }

        status = serial_io.?.setAttributes(serial_io.?, 115200, 16, 0, NO_PARITY, 8, STOP_BITS_1);
        return Serial{ .serial = serial_io.? };
    }

    pub fn write(self: *Serial, data: []const u8) !void {
        var bytes_written: u64 = 0;
        const status = self.serial.Write(self.serial, @as(u64, data.len), @ptrCast(data.ptr), &bytes_written);
        if (status != Status.success) {
            return io.WriteError.CannotWrite;
        }
    }

    pub fn read(self: *Serial, buffer: []u8) SerialError!u64 {
        var bytes_read: u64 = 0;
        const status = self.serial.Read(&bytes_read, buffer);
        if (status != uefi.Status.success) {
            return io.ReadError.CannotRead;
        }
        return bytes_read;
    }
};
