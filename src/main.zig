const std = @import("std");
const readline = @import("readline");
const history = @import("history");

const stdout = std.io.getStdOut().writer();

const history_file = "/tmp/.readline-test-history";

pub fn main() !void {
  try stdout.print("type \"quit\" or \"exit\" or ^D, to quit.\n", .{});

  _ = history.read_history(history_file);
  while (true) {
    const result = readline.readline("> ");
    if (result == null) {
      try stdout.print("^D\n", .{});
      break;
    }
    if (std.mem.eql(u8, "exit", std.mem.span(result)) or std.mem.eql(u8, "quit", std.mem.span(result))) {
      try stdout.print("bye!\n", .{});
      break;
    }
    if (std.mem.len(result) > 1) {
      try stdout.print("{s}\n", .{ result });
    }
    _ = history.add_history(result);
  }
  _ = history.write_history(history_file);
}
