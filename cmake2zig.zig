const std = @import("std");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const args = try std.process.argsAlloc(allocator);
    if (args.len < 2) {
        std.debug.print("Usage: cmake2zig <CMakeLists.txt>\n", .{});
        return;
    }

    const cmake_content = try std.fs.cwd().readFileAlloc(allocator, args[1], 8192);

    const project = parseSingle(cmake_content, "project");
    const sources = parseMultiple(cmake_content, "add_executable");
    const includes = parseMultiple(cmake_content, "target_include_directories");
    const compile_opts = parseMultiple(cmake_content, "target_compile_options");
    const libraries = parseMultiple(cmake_content, "target_link_libraries");

    // Generate build.zig
    var file = try std.fs.cwd().createFile("build.zig", .{});
    defer file.close();

    try file.writeAll(generateZigBuild(project, sources, includes, compile_opts, libraries));

    std.debug.print("Generated build.zig successfully.\n", .{});
}

fn parseSingle(text: []const u8, command: []const u8) []const u8 {
    const pattern = std.mem.concat(u8, &.{command, "\\((\\w+)\\)"});
    var regex = std.re.Regex.init(pattern, .{}) catch unreachable;
    if (regex.match(text)) |m| {
        return m.captures[1];
    }
    return "UnnamedProject";
}

fn parseMultiple(text: []const u8, command: []const u8) [][]const u8 {
    var items = std.ArrayList([]const u8).init(std.heap.page_allocator);
    defer items.deinit();

    const pattern = std.mem.concat(u8, &.{command, "\\([^\\)]+\\)"});
    var regex = std.re.Regex.init(pattern, .{}) catch unreachable;

    var iter = regex.findIter(text);
    while (iter.next()) |m| {
        const full = text[m.start..m.end];
        const innerStart = std.mem.indexOfScalar(u8, full, '(') orelse continue;
        const inner = std.mem.trim(u8, full[innerStart+1 .. full.len-1], " \n\t");
        var parts = std.mem.splitAny(u8, inner, " \n\t");
        _ = parts.next(); // Skip target name
        while (parts.next()) |p| {
            items.append(p) catch unreachable;
        }
    }

    return items.toOwnedSlice() catch unreachable;
}

fn generateZigBuild(
    project: []const u8,
    sources: [][]const u8,
    includes: [][]const u8,
    compile_opts: [][]const u8,
    libraries: [][]const u8,
) []const u8 {
    var zig_code = std.ArrayList(u8).init(std.heap.page_allocator);
    defer zig_code.deinit();

    const tmpl =
        \\const std = @import("std");
        \\
        \\pub fn build(b: *std.build.Builder) void {{
        \\    const mode = b.standardOptimizeOption(.{{}});
        \\
        \\    const exe = b.addExecutable(.{{
        \\        .name = "{name}",
        \\        .optimize = mode,
        \\        .target = b.standardTargetOptions(.{{}}),
        \\    }});
        \\
        \\    exe.addCSourceFiles(&.{sources}, &.{compile_opts});
        {includes}{libraries}
        \\    exe.linkLibCpp();
        \\    exe.install();
        \\}}
    ;

    const sources_fmt = arrayFmt(sources);
    const opts_fmt = arrayFmt(compile_opts);
    const includes_fmt = multiLineFmt("exe.addIncludePath", includes);
    const libs_fmt = multiLineFmt("exe.linkSystemLibrary", libraries);

    return std.fmt.allocPrint(std.heap.page_allocator, tmpl, .{
        .name = project,
        .sources = sources_fmt,
        .compile_opts = opts_fmt,
        .includes = includes_fmt,
        .libraries = libs_fmt,
    }) catch unreachable;
}

fn arrayFmt(items: [][]const u8) []const u8 {
    var buf = std.ArrayList(u8).init(std.heap.page_allocator);
    defer buf.deinit();

    buf.appendSlice("{") catch unreachable;
    for (items, 0..) |item, idx| {
        if (idx > 0) buf.appendSlice(", ") catch unreachable;
        buf.appendSlice("\"") catch unreachable;
        buf.appendSlice(item) catch unreachable;
        buf.appendSlice("\"") catch unreachable;
    }
    buf.appendSlice("}") catch unreachable;

    return buf.toOwnedSlice() catch unreachable;
}

fn multiLineFmt(call: []const u8, items: [][]const u8) []const u8 {
    var buf = std.ArrayList(u8).init(std.heap.page_allocator);
    defer buf.deinit();
    for (items) |item| {
        buf.appendSlice("    ") catch unreachable;
        buf.appendSlice(call) catch unreachable;
        buf.appendSlice("(\"") catch unreachable;
        buf.appendSlice(item) catch unreachable;
        buf.appendSlice("\");\n") catch unreachable;
    }
    return buf.toOwnedSlice() catch unreachable;
}

