const std = @import("std");

pub fn get_readline_module(b: *std.Build, target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode, lib: *std.Build.Step.Compile) struct {
    module: *std.Build.Module,
    translation: *std.Build.Step.TranslateC,
} {
    // Create the readline module to be used in zig with `@import("readline")`
    const readline_translation = b.addTranslateC(.{
        // readline needs stdio to be included first, that's why this shenanigan
        .root_source_file = b.addWriteFiles().add("readline-bundle.h",
            \\#include <stdio.h>
            \\#include <readline/readline.h>
        ),
        .target = target,
        .optimize = optimize,
    });
    readline_translation.addIncludePath(.{ .cwd_relative = b.getInstallPath(.prefix, "include") });
    readline_translation.step.dependOn(&lib.step);
    // build readline as module
    const mod_readline = b.addModule("readline", .{
        .root_source_file = readline_translation.getOutput(),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    return .{
        .module = mod_readline,
        .translation = readline_translation,
    };
}

pub fn get_history_module(b: *std.Build, target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode, lib: *std.Build.Step.Compile) struct {
    module: *std.Build.Module,
    translation: *std.Build.Step.TranslateC,
} {
    // Create the history module to be used in zig with `@import("readline")`
    const history_translation = b.addTranslateC(.{
        // readline needs stdio to be included first, that's why this shenanigan
        .root_source_file = b.addWriteFiles().add("history-bundle.h",
            \\#include <stdio.h>
            \\#include <readline/history.h>
        ),
        .target = target,
        .optimize = optimize,
    });
    history_translation.addIncludePath(.{ .cwd_relative = b.getInstallPath(.prefix, "include") });
    history_translation.step.dependOn(&lib.step);
    // build readline as module
    const mod_history = b.addModule("history", .{
        .root_source_file = history_translation.getOutput(),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    return .{
        .module = mod_history,
        .translation = history_translation,
    };
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const single_threaded = b.option(bool, "single-threaded", "Build artifacts that run in single threaded mode");

    const upstream = b.dependency("libreadline", .{});

    const lib_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .single_threaded = single_threaded orelse true,
    });
    lib_mod.addCSourceFiles(.{
        .root = upstream.path("."),
        .files = srcs,
        .flags = &.{
            "-DHAVE_CONFIG_H",
            "-DRL_LIBRARY_VERSION=\"8.3\"",
            "-DBRACKETED_PASTE_DEFAULT=1",
            "-DREADLINE_LIBRARY",
        },
    });
    lib_mod.addIncludePath(upstream.path(""));
    lib_mod.addIncludePath(b.path(""));

    const lib = b.addLibrary(.{
        .name = "lib",
        .linkage = .static,
        .root_module = lib_mod,
    });
    lib.installHeader(b.path("config.h"), "config.h");
    lib.installHeadersDirectory(upstream.path("."), "readline", .{ .include_extensions = &.{
        "chardefs.h",
        "history.h",
        "keymaps.h",
        "readline.h",
        "rlconf.h",
        "rlstdc.h",
        "rltypedefs.h",
        "tilde.h",
    } });
    b.installArtifact(lib);

    const libdyn = b.addLibrary(.{
        .name = "libdyn",
        .linkage = .dynamic,
        .root_module = lib_mod,
    });
    b.installArtifact(libdyn);

    const readline_artefacts = get_readline_module(b, target, optimize, lib);
    const history_artefacts = get_history_module(b, target, optimize, lib);

    // Add a test executable
    const exe = b.addExecutable(.{
        .name = "test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.linkLibrary(lib);
    exe.root_module.linkSystemLibrary("curses", .{});
    exe.root_module.addImport("readline", readline_artefacts.module);
    exe.root_module.addImport("history", history_artefacts.module);
    b.installArtifact(exe);
    // Add a run step
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}

const srcs: []const []const u8 = &.{
    "readline.c",
    "vi_mode.c",
    "funmap.c",
    "keymaps.c",
    "parens.c",
    "search.c",
    "rltty.c",
    "complete.c",
    "bind.c",
    "isearch.c",
    "display.c",
    "signals.c",
    "util.c",
    "kill.c",
    "undo.c",
    "macro.c",
    "input.c",
    "callback.c",
    "terminal.c",
    "text.c",
    "nls.c",
    "misc.c",
    "history.c",
    "histexpand.c",
    "histfile.c",
    "histsearch.c",
    "shell.c",
    "mbutil.c",
    "colors.c",
    "parse-colors.c",
    "xmalloc.c",
    "xfree.c",
    "compat.c",
    "gettimeofday.c",
    "tilde.c",
};
