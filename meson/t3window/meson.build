t3window_include = include_directories('../../deps/t3window/src', '.')

window_shared = custom_target(
    'window-shared-source',
    input: '../../deps/t3shared/src/shared.c',
    output: 'window_shared.c',
    command: [python, codegen, 'shared', 'window', '@INPUT@', '@OUTPUT@'],
)

t3window_lib = shared_library(
    't3window',
    files(
        '../../deps/t3window/src/window.c',
        '../../deps/t3window/src/terminal.c',
        '../../deps/t3window/src/curses_interface.c',
        '../../deps/t3window/src/convert_output.c',
        '../../deps/t3window/src/misc.c',
        '../../deps/t3window/src/input.c',
        '../../deps/t3window/src/terminal_init.c',
        '../../deps/t3window/src/window_paint.c',
        '../../deps/t3window/src/utf8.c',
        '../../deps/t3window/src/generated/chardata.c',
        '../../deps/t3window/src/log.c',
    ),
    window_shared,
    generated_headers,
    include_directories: [
        generated_include,
        t3window_include,
        unistring_inc,
        intl_inc,
    ],
    c_args: [
        '-DT3_WINDOW_BUILD_DSO',
        '-DT3_DONT_CHECK_VERSION',
        '-D_T3_WINDOW_INTERNAL',
        '-DHAS_WINSIZE_IOCTL',
        '-DHAS_SELECT_H',
        '-DHAS_STRDUP',
        '-DUSE_GETTEXT',
    ],
    dependencies: [transcript_dep, ncurses_dep, unistring_dep, intl_dep],
    gnu_symbol_visibility: 'hidden',
    install: true,
)

t3window_dep = declare_dependency(
    link_with: t3window_lib,
    include_directories: [generated_include, t3window_include],
    dependencies: [transcript_dep, ncurses_dep, unistring_dep],
)
