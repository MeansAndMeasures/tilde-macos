t3config_include = include_directories('../../deps/t3config/src', '.')

config_shared = custom_target(
    'config-shared-source',
    input: '../../deps/t3shared/src/shared.c',
    output: 'config_shared.c',
    command: [python, codegen, 'shared', 'config', '@INPUT@', '@OUTPUT@'],
)

config_parser = custom_target(
    'config-parser',
    input: '../../deps/t3config/src/parser.g',
    output: ['parser.c', 'parser.h'],
    command: [llnextgen, '--base-name=@OUTDIR@/parser', '@INPUT@'],
)

config_lexer = custom_target(
    'config-lexer',
    input: '../../deps/t3config/src/lex.l',
    output: 'lex.c',
    command: [flex, '--outfile=@OUTPUT@', '@INPUT@'],
)

config_lex_hide = custom_target(
    'config-lexer-hidden-symbols',
    input: config_lexer,
    output: 'lex_hide.h',
    command: [python, codegen, 'lex-hide', '@INPUT@', '@OUTPUT@'],
)

config_meta_schema = custom_target(
    'config-meta-schema-bytes',
    input: '../../deps/t3config/src/meta_schema.schema',
    output: 'meta_schema.bytes',
    command: [python, codegen, 'bytes', '@INPUT@', '@OUTPUT@'],
)

t3config_lib = shared_library(
    't3config',
    files(
        '../../deps/t3config/src/config.c',
        '../../deps/t3config/src/util.c',
        '../../deps/t3config/src/write.c',
        '../../deps/t3config/src/expression.c',
        '../../deps/t3config/src/schema.c',
        '../../deps/t3config/src/pathsearch.c',
        '../../deps/t3config/src/xdg.c',
    ),
    config_shared,
    config_parser,
    config_lexer,
    config_lex_hide,
    config_meta_schema,
    generated_headers,
    include_directories: [generated_include, t3config_include, intl_inc],
    c_args: [
        '-DT3_CONFIG_BUILD_DSO',
        '-DT3_DONT_CHECK_VERSION',
        '-DHAS_STRDUP',
        '-DHAS_USELOCALE',
        '-DUSE_GETTEXT',
    ],
    dependencies: [intl_dep, m_dep],
    gnu_symbol_visibility: 'hidden',
    install: true,
)

t3config_dep = declare_dependency(
    link_with: t3config_lib,
    include_directories: [generated_include, t3config_include],
    dependencies: [intl_dep],
)
