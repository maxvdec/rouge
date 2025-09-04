const std = @import("std");
const testing = std.testing;
const rouge = @import("rouge");

test "Time Nanoseconds" {
    try testing.expect(rouge.time.TimeDelay.fromSeconds(2).nanoseconds == 2_000_000_000);
}

test "UEFI String" {
    const result = &rouge.console.stringToUefi("Hi");
    try testing.expectEqualSlices(u16, result, &[_]u16{ 'H', 'i' });
}

test "Format String" {
    var buffer: [30]u8 = undefined;
    const result = rouge.format.string("Hello, {}!", [_][]const u8{"World"}, &buffer);
    try testing.expectEqualSlices(u8, result, "Hello, World!");
}

test "Format Decimal" {
    var buffer: [20]u8 = undefined;
    const result = rouge.format.decimal(12345, &buffer);
    try testing.expectEqualSlices(u8, result, "12345");
}

test "Format Hexadecimal" {
    var buffer: [20]u8 = undefined;
    const result = rouge.format.hexadecimal(0x1A2B3C4D5E6F7081, &buffer);
    try testing.expectEqualSlices(u8, result, "0x1A2B3C4D5E6F7081");
}
