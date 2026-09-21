t3highlight_include = include_directories('../../deps/t3highlight/src', '.')
t3highlight_data_dir = meson.project_source_root() / 'deps/t3highlight/src/data'

highlight_shared = custom_target(
    'highlight-shared-source',
    input: '../../deps/t3shared/src/shared.c',
    output: 'highlight_shared.c',
    command: [python, codegen, 'shared', 'highlight', '@INPUT@', '@OUTPUT@'],
)

highlight_syntax = custom_target(
    'highlight-syntax-bytes',
    input: '../../deps/t3highlight/src/syntax.schema',
    output: 'syntax.bytes',
    command: [python, codegen, 'bytes', '@INPUT@', '@OUTPUT@'],
)

highlight_syntax_v3 = custom_target(
    'highlight-syntax-v3-bytes',
    input: '../../deps/t3highlight/src/syntax_v3.schema',
    output: 'syntax_v3.bytes',
    command: [python, codegen, 'bytes', '@INPUT@', '@OUTPUT@'],
)

highlight_map = custom_target(
    'highlight-map-bytes',
    input: '../../deps/t3highlight/src/map.schema',
    output: 'map.bytes',
    command: [python, codegen, 'bytes', '@INPUT@', '@OUTPUT@'],
)

t3highlight_lib = shared_library(
    't3highlight',
    files(
        '../../deps/t3highlight/src/highlight.c',
        '../../deps/t3highlight/src/vector.c',
        '../../deps/t3highlight/src/io.c',
        '../../deps/t3highlight/src/utf8.c',
        '../../deps/t3highlight/src/match.c',
        '../../deps/t3highlight/src/analyse.c',
        '../../deps/t3highlight/src/pcre_compat.c',
    ),
    highlight_shared,
    highlight_syntax,
    highlight_syntax_v3,
    highlight_map,
    generated_headers,
    include_directories: [generated_include, t3highlight_include],
    c_args: [
        '-DT3_HIGHLIGHT_BUILD_DSO',
        '-DT3_DONT_CHECK_VERSION',
        '-DPCRE2_CODE_UNIT_WIDTH=8',
        '-DDATADIR="@0@"'.format(t3highlight_data_dir),
    ],
    dependencies: [t3config_dep, pcre2_dep],
    gnu_symbol_visibility: 'hidden',
    install: true,
)

t3highlight_dep = declare_dependency(
    link_with: t3highlight_lib,
    include_directories: [generated_include, t3highlight_include],
    dependencies: [t3config_dep, pcre2_dep],
)
