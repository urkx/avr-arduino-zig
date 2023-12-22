const std = @import("std");
const Builder = std.Build.Builder;

pub fn build(b: *Builder) !void {
    const uno = std.zig.CrossTarget{
        .cpu_arch = .avr,
        .cpu_model = .{ .explicit = &std.Target.avr.cpu.atmega2560 },
        .os_tag = .freestanding,
        .abi = .none,
    };

    const exe = b.addExecutable(.{
        .name = "avr-arduino-zig", 
        .root_source_file = .{ .path = "src/start.zig"},
        .target = uno,
        .optimize = b.standardOptimizeOption(.{})});
    exe.setLinkerScriptPath(std.build.FileSource{ .path = "src/linker.ld" });
    b.installArtifact(exe);

    const tty = b.option(
        []const u8,
        "tty",
        "Specify the port to which the Arduino is connected (defaults to /dev/ttyACM0)",
    ) orelse "/dev/ttyACM0";

    const pt = exe.installed_path orelse ".";

    const bin_path = b.getInstallPath(.{.custom = pt}, exe.out_filename);

    const flash_command = blk: {
        var tmp = std.ArrayList(u8).init(b.allocator);
        try tmp.appendSlice("-Uflash:w:");
        try tmp.appendSlice(bin_path);
        try tmp.appendSlice(":e");
        break :blk try tmp.toOwnedSlice();
    };

    const upload = b.step("upload", "Upload the code to an Arduino device using avrdude");
    const cmd = &[_][]const u8{"avrdude",
        "-cstk500v2",
        "-pm2560",
        "-D",
        "-P",
        tty,
        flash_command,};
    const avrdude = b.addSystemCommand(cmd);
    upload.dependOn(&avrdude.step);
    avrdude.step.dependOn(&exe.step);

    const objdump = b.step("objdump", "Show dissassembly of the code using avr-objdump");
    const avr_objdump = b.addSystemCommand(&.{
        "avr-objdump",
        "-dh",
        bin_path,
    });
    objdump.dependOn(&avr_objdump.step);
    avr_objdump.step.dependOn(&exe.step);

    const monitor = b.step("monitor", "Opens a monitor to the serial output");
    const screen = b.addSystemCommand(&.{
        "screen",
        tty,
        "115200",
    });
    monitor.dependOn(&screen.step);

    b.default_step.dependOn(&exe.step);
}
