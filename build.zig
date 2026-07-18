const std = @import("std");

const major = 2;
const minor = 0;
const patch = 2;
const version = std.fmt.comptimePrint("{}.{}.{}", .{ major, minor, patch });

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const build_shared = b.option(bool, "shared", "Build shared library") orelse false;

    const c_cmocka = b.dependency("cmocka", .{});
    const root = c_cmocka.path("");

    const version_header = b.addConfigHeader(.{
        .style = .{
            .cmake = root.path(b, "include/cmocka_version.h.cmake"),
        },
        .include_path = "cmocka_version.h",
    }, .{
        .cmocka_VERSION_MAJOR = major,
        .cmocka_VERSION_MINOR = minor,
        .cmocka_VERSION_PATCH = patch,
    });

    const is_windows = target.result.os.tag == .windows;
    const is_unix = target.result.os.tag == .linux or target.result.os.tag == .macos;
    const is_linux = target.result.os.tag == .linux;
    const is_msvc = target.result.os.tag == .windows and target.result.abi == .msvc;
    const is_big_endian = target.result.cpu.arch.endian() == .big;
    const ptr_size = target.result.ptrBitWidth() / 8;

    const config = .{
        .PACKAGE = "cmocka",
        .PROJECT_NAME = "cmocka",
        .VERSION = version,
        .PROJECT_VERSION = version,
        .LOCALE_INSTALL_DIR = false,
        .LOCALEDIR = false,
        .DATADIR = false,
        .LIBDIR = false,
        .PLUGINDIR = false,
        .SYSCONFDIR = false,
        .BINARYDIR = false,
        .SOURCEDIR = root.getPath(b),

        .HAVE_ASSERT_H = true,
        .HAVE_DLFCN_H = is_unix,
        .HAVE_INTTYPES_H = true,
        .HAVE_IO_H = is_windows,
        .HAVE_MALLOC_H = is_linux,
        .HAVE_MEMORY_H = true,
        .HAVE_SETJMP_H = true,
        .HAVE_SIGNAL_H = true,
        .HAVE_STDARG_H = true,
        .HAVE_STDDEF_H = true,
        .HAVE_STDINT_H = true,
        .HAVE_STDIO_H = true,
        .HAVE_STDLIB_H = true,
        .HAVE_STRINGS_H = is_unix,
        .HAVE_STRING_H = true,
        .HAVE_SYS_STAT_H = true,
        .HAVE_SYS_TYPES_H = true,
        .HAVE_TIME_H = true,
        .HAVE_UNISTD_H = is_unix,

        .HAVE_STRUCT_TIMESPEC = is_unix,
        .HAVE_UINTPTR_T = true,

        .HAVE_CALLOC = true,
        .HAVE_EXIT = true,
        .HAVE_FPRINTF = true,
        .HAVE_SNPRINTF = true,
        .HAVE__SNPRINTF = is_windows,
        .HAVE__SNPRINTF_S = is_windows,
        .HAVE_VSNPRINTF = true,
        .HAVE__VSNPRINTF = is_windows,
        .HAVE__VSNPRINTF_S = is_windows,
        .HAVE_FREE = true,
        .HAVE_LONGJMP = true,
        .HAVE_SIGLONGJMP = is_unix,
        .HAVE_MALLOC = true,
        .HAVE_MEMCPY = true,
        .HAVE_MEMSET = true,
        .HAVE_PRINTF = true,
        .HAVE_SETJMP = true,
        .HAVE_SIGNAL = true,
        .HAVE_STRCMP = true,
        .HAVE_STRCPY = true,
        .HAVE_STRSIGNAL = is_unix,
        .HAVE_CLOCK_GETTIME = is_unix,

        .HAVE_GCC_THREAD_LOCAL_STORAGE = !is_msvc,
        .HAVE_MSVC_THREAD_LOCAL_STORAGE = is_msvc,
        .HAVE_CLOCK_REALTIME = is_unix,

        .WORDS_SIZEOF_VOID_P = ptr_size,
        .WORDS_BIGENDIAN = if (is_big_endian) @as(u32, 1) else @as(u32, 0),
    };

    const config_header = b.addConfigHeader(.{
        .style = .{
            .cmake = root.path(b, "config.h.cmake"),
        },
        .include_path = "config.h",
    }, config);

    const cmocka = b.addLibrary(.{
        .name = "cmocka",
        .version = .{
            .major = major,
            .minor = minor,
            .patch = patch,
        },
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
        .linkage = if (build_shared) .dynamic else .static,
    });

    cmocka.root_module.link_libc = true;

    if (is_windows) {
        cmocka.root_module.addCMacro("_WIN32", "1");
    }

    if (!build_shared) {
        cmocka.root_module.addCMacro("CMOCKA_STATIC", "1");
    }

    cmocka.root_module.addCMacro("HAVE_CONFIG_H", "1");
    cmocka.root_module.addCMacro("_GNU_SOURCE", "1");
    cmocka.root_module.addCMacro("_XOPEN_SOURCE", "700");

    cmocka.root_module.addConfigHeader(version_header);
    cmocka.root_module.addConfigHeader(config_header);

    cmocka.root_module.addIncludePath(root.path(b, "include"));

    cmocka.installHeadersDirectory(root.path(b, "include"), ".", .{ .include_extensions = &.{".h"} });
    cmocka.installConfigHeader(config_header);
    cmocka.installConfigHeader(version_header);

    cmocka.root_module.addCSourceFiles(.{
        .root = root.path(b, "src"),
        .files = &.{
            "cmocka.c",
        },
    });

    b.installArtifact(cmocka);

    // Add testing step
    const test_step = b.step("test", "Run library tests");

    const passing_tests = &.{
        "test_alloc",
        "test_buffer",
        "test_expect_check",
        "test_expect_check_old_api",
        "test_expect_check_new_api",
        "test_expect_u_int_in_set",
        "test_expect_u_int_not_in_set",
        "test_expect_value",
        "test_expect_in_range",
        "test_fixtures",
        "test_group_fixtures",
        "test_groups",
        "test_float_macros",
        "test_double_macros",
        "test_assert_double_float",
        "test_assert_true",
        "test_assert_false",
        "test_assert_macros",
        "test_assert_memory",
        "test_assert_ptr",
        "test_assert_ptr_msg",
        "test_assert_funcptr",
        "test_assert_u_int",
        "test_assert_range",
        "test_assert_set",
        "test_basics",
        "test_has_mock",
        "test_log",
        "test_skip",
        "test_stop",
        "test_strmatch",
        "test_strreplace",
        "test_ordering",
        "test_returns",
        "test_set_parameter",
        "test_set_errno",
        "test_string",
        "test_wildcard",
        "test_skip_filter",
        "test_skip_filter_env",
    };

    inline for (passing_tests) |test_name| {
        const exe = b.addExecutable(.{
            .name = test_name,
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
            }),
        });

        exe.root_module.link_libc = true;
        exe.root_module.linkLibrary(cmocka);
        exe.root_module.addConfigHeader(version_header);
        exe.root_module.addConfigHeader(config_header);
        exe.root_module.addIncludePath(root.path(b, "include"));

        exe.root_module.addCSourceFile(.{
            .file = root.path(b, "tests/" ++ test_name ++ ".c"),
        });

        const run_cmd = b.addRunArtifact(exe);
        if (comptime std.mem.eql(u8, test_name, "test_skip_filter_env")) {
            run_cmd.setEnvironmentVariable("CMOCKA_TEST_FILTER", "test_skip*");
            run_cmd.setEnvironmentVariable("CMOCKA_SKIP_FILTER", "test_skip2");
        }
        test_step.dependOn(&run_cmd.step);
    }

    const FailingTest = struct {
        name: []const u8,
        expected_exit_code: u8,
    };

    const failing_tests_config = &[_]FailingTest{
        .{ .name = "test_expect_check_old_api_fail", .expected_exit_code = 5 },
        .{ .name = "test_expect_check_new_api_fail", .expected_exit_code = 8 },
        .{ .name = "test_expect_check_fail", .expected_exit_code = 3 },
        .{ .name = "test_group_setup_assert", .expected_exit_code = 1 },
        .{ .name = "test_group_setup_fail", .expected_exit_code = 1 },
        .{ .name = "test_assert_double_float_fail", .expected_exit_code = 4 },
        .{ .name = "test_assert_true_fail", .expected_exit_code = 1 },
        .{ .name = "test_assert_false_fail", .expected_exit_code = 1 },
        .{ .name = "test_assert_macros_fail", .expected_exit_code = 1 },
        .{ .name = "test_assert_memory_fail", .expected_exit_code = 1 },
        .{ .name = "test_assert_ptr_fail", .expected_exit_code = 4 },
        .{ .name = "test_assert_ptr_msg_fail", .expected_exit_code = 4 },
        .{ .name = "test_assert_u_int_fail", .expected_exit_code = 4 },
        .{ .name = "test_assert_range_fail", .expected_exit_code = 12 },
        .{ .name = "test_assert_set_fail", .expected_exit_code = 7 },
        .{ .name = "test_stop_fail", .expected_exit_code = 3 },
        .{ .name = "test_ordering_fail", .expected_exit_code = 8 },
        .{ .name = "test_returns_fail", .expected_exit_code = 6 },
        .{ .name = "test_set_parameter_fail", .expected_exit_code = 6 },
        .{ .name = "test_set_errno_fail", .expected_exit_code = 3 },
        .{ .name = "test_setup_fail", .expected_exit_code = 1 },
        .{ .name = "test_mock_exit", .expected_exit_code = 1 },
    };

    if (!is_windows) {
        inline for (failing_tests_config) |failing_test| {
            const exe = b.addExecutable(.{
                .name = failing_test.name,
                .root_module = b.createModule(.{
                    .target = target,
                    .optimize = optimize,
                }),
            });

            exe.root_module.link_libc = true;
            exe.root_module.linkLibrary(cmocka);
            exe.root_module.addConfigHeader(version_header);
            exe.root_module.addConfigHeader(config_header);
            exe.root_module.addIncludePath(root.path(b, "include"));

            exe.root_module.addCSourceFile(.{
                .file = root.path(b, "tests/" ++ failing_test.name ++ ".c"),
            });

            const run_cmd = b.addRunArtifact(exe);
            run_cmd.expectExitCode(failing_test.expected_exit_code);
            test_step.dependOn(&run_cmd.step);
        }
    }
}
