transcript_build_dir = meson.current_build_dir()
transcript_include = include_directories(
    '../../deps/transcript/src',
    '../../deps/transcript/src/pregen',
)

transcript_args = [
    '-DTRANSCRIPT_BUILD_DSO',
    '-DUSE_ENDIAN',
    '-DHAS_INLINE',
    '-DHAS_NL_LANGINFO',
    '-DHAS_STRDUP',
    '-DTRANSCRIPT_DEBUG',
    '-DHAS_DLFCN',
    '-DDB_DIRECTORY="@0@"'.format(transcript_build_dir),
]

transcript_lib = shared_library(
    'transcript',
    files(
        '../../deps/transcript/src/transcript.c',
        '../../deps/transcript/src/transcript_io.c',
        '../../deps/transcript/src/utf.c',
        '../../deps/transcript/src/transcript_iconv.c',
        '../../deps/transcript/src/state_table_converter.c',
        '../../deps/transcript/src/aliases.c',
        '../../deps/transcript/src/pregen/generic_fallbacks.c',
        '../../deps/transcript/src/sbcs_table_converter.c',
    ),
    generated_headers,
    include_directories: [generated_include, transcript_include],
    c_args: transcript_args,
    dependencies: [threads_dep],
    gnu_symbol_visibility: 'hidden',
    install: true,
)

transcript_dep = declare_dependency(
    link_with: transcript_lib,
    include_directories: [generated_include, transcript_include],
    dependencies: [threads_dep],
)

transcript_module_args = ['-DTRANSCRIPT_BUILD_DSO']

ascii_module = shared_module(
    'ascii',
    files('../../deps/transcript/src/modules/ascii.c'),
    include_directories: [generated_include, transcript_include],
    c_args: transcript_module_args,
    link_with: transcript_lib,
    name_prefix: '',
    name_suffix: 'ltc',
)

unicode_module = shared_module(
    'unicode',
    files(
        '../../deps/transcript/src/modules/unicode.c',
        '../../deps/transcript/src/modules/unicode_gb18030.c',
        '../../deps/transcript/src/modules/unicode_utf7.c',
    ),
    include_directories: [generated_include, transcript_include],
    c_args: transcript_module_args,
    link_with: transcript_lib,
    name_prefix: '',
    name_suffix: 'ltc',
)

iso2022_module = shared_module(
    'iso2022',
    files('../../deps/transcript/src/modules/iso2022.c'),
    include_directories: [generated_include, transcript_include],
    c_args: transcript_module_args,
    link_with: transcript_lib,
    name_prefix: '',
    name_suffix: 'ltc',
)

euctw_module = shared_module(
    'euctw',
    files('../../deps/transcript/src/modules/euctw.c'),
    include_directories: [generated_include, transcript_include],
    c_args: transcript_module_args,
    link_with: transcript_lib,
    name_prefix: '',
    name_suffix: 'ltc',
)

linkltc = executable(
    'linkltc',
    files('../../deps/transcript/src.util/linkltc/linkltc.c'),
    include_directories: [
        generated_include,
        transcript_include,
        include_directories('../../deps/transcript/src.util/linkltc'),
    ],
    c_args: ['-DHAS_STRDUP', '-DHAS_DLFCN'],
    link_with: transcript_lib,
)

transcript_converter_links = custom_target(
    'transcript-converter-links',
    input: [ascii_module, unicode_module, iso2022_module, euctw_module],
    output: 'converter-links.stamp',
    command: [
        python,
        codegen,
        'transcript-links',
        linkltc,
        '@OUTPUT@',
        '@INPUT@',
    ],
    build_by_default: true,
)
