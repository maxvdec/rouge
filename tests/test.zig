const std = @import("std");
const testing = std.testing;
const rouge = @import("rouge");

test "Time Nanoseconds" {
    try testing.expect(rouge.time.TimeDelay.fromSeconds(2).nanoseconds == 2_000_000_000);
}

test "UEFI String" {
    const result = rouge.console.stringToUefi("Hi");
    try testing.expectEqualSlices(u16, result[0..2], &[_]u16{ 'H', 'i' });
}

test "Format String" {
    const result = rouge.format.string("Hello, {}!", [_][]const u8{"World"}, 30);
    try testing.expectEqualSlices(u8, result[0..13], "Hello, World!");
}

test "Format Decimal" {
    const result = rouge.format.decimal(12345, 30);
    try testing.expectEqualSlices(u8, result[0..5], "12345");
}

test "Format Hexadecimal" {
    const result = rouge.format.hexadecimal(0x1A2B3C4D5E6F7081, 30);
    try testing.expectEqualSlices(u8, result[0..18], "0x1A2B3C4D5E6F7081");
}
