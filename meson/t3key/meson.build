t3key_include = include_directories('../../deps/t3key/src', '.')
t3key_database_dir = meson.project_source_root() / 'deps/t3key/src/database'

key_shared = custom_target(
    'key-shared-source',
    input: '../../deps/t3shared/src/shared.c',
    output: 'key_shared.c',
    command: [python, codegen, 'shared', 'key', '@INPUT@', '@OUTPUT@'],
)

key_map = custom_target(
    'key-map-bytes',
    input: '../../deps/t3key/src/map.schema',
    output: 'map.bytes',
    command: [python, codegen, 'bytes', '@INPUT@', '@OUTPUT@'],
)

t3key_lib = shared_library(
    't3key',
    files('../../deps/t3key/src/key.c'),
    key_shared,
    key_map,
    generated_headers,
    include_directories: [generated_include, t3key_include],
    c_args: [
        '-DT3_KEY_BUILD_DSO',
        '-DT3_DONT_CHECK_VERSION',
        '-DHAS_STRDUP',
        '-DDB_DIRECTORY="@0@"'.format(t3key_database_dir),
    ],
    dependencies: [t3config_dep, ncurses_dep],
    gnu_symbol_visibility: 'hidden',
    install: true,
)

t3key_dep = declare_dependency(
    link_with: t3key_lib,
    include_directories: [generated_include, t3key_include],
    dependencies: [t3config_dep, ncurses_dep],
)
