const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const mod = b.addModule("libpcre", .{
        .root_source_file = b.path("src/main.zig"),
        .optimize = optimize,
        .target = target,
    });
    try linkPcre(b, mod);

    const lib = b.addStaticLibrary(.{
        .name = "libpcre.zig",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    try linkPcre(b, &lib.root_module);
    b.installArtifact(lib);

    const main_tests = b.addTest(.{
        .name = "main_tests",
        .root_source_file = b.path("src/main.zig"),
        .optimize = optimize,
        .target = target,
    });
    main_tests.linkLibC();
    try linkPcre(b, &main_tests.root_module);

    const main_tests_run = b.addRunArtifact(main_tests);
    main_tests_run.step.dependOn(&main_tests.step);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests_run.step);
}

pub fn linkPcre(b: *std.Build, mod: *std.Build.Module) !void {
    if (builtin.os.tag == .macos) {
        // If `pkg-config libpcre` doesn't error, linkSystemLibrary("libpcre") will succeed.
        // If it errors, try "pcre", as either it will hit a .pc by that name, or the fallthru
        // `-lpcre` and standard includes will work.  (Or it's not installed.)
        var code: u8 = undefined;
        if (b.runAllowFail(&[_][]const u8{ "pkg-config", "libpcre" }, &code, .Inherit)) |_| {
            mod.linkSystemLibrary("libpcre", .{});
        } else |_| {
            mod.linkSystemLibrary("pcre", .{});
        }
    } else {
        mod.linkSystemLibrary("pcre", .{});
    }
}
