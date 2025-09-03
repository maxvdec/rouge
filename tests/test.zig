const std = @import("std");
const testing = std.testing;
const rouge = @import("rouge");

test "Time Nanoseconds" {
    try testing.expect(rouge.time.TimeDelay.fromSeconds(2).nanoseconds == 2_000_000_000);
}

test "UEFI String" {
    std.debug.print("UEFI String Test\n", .{});
    const result = &rouge.console.stringToUefi("Hi");
    std.debug.print("Result: {any}\n", .{result});
    try testing.expectEqualSlices(u16, result, &[_]u16{ 'H', 'i' });
}
