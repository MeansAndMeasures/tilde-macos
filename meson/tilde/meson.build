tilde_include = include_directories('../../src', '../../src/dialogs', '.')
tilde_data_dir = meson.project_source_root() / 'src'

tilde_config_schema = custom_target(
    'tilde-config-schema-bytes',
    input: '../../src/config.schema',
    output: 'config.bytes',
    command: [python, codegen, 'bytes', '@INPUT@', '@OUTPUT@'],
)

tilde_recent_files_schema = custom_target(
    'tilde-recent-files-schema-bytes',
    input: '../../src/recent_files.schema',
    output: 'recent_files.bytes',
    command: [python, codegen, 'bytes', '@INPUT@', '@OUTPUT@'],
)

tilde_exe = executable(
    'tilde',
    files(
        '../../src/attributemap.cc',
        '../../src/copy_file.cc',
        '../../src/fileautocompleter.cc',
        '../../src/filebuffer.cc',
        '../../src/fileeditwindow.cc',
        '../../src/fileline.cc',
        '../../src/filestate.cc',
        '../../src/filewrapper.cc',
        '../../src/log.cc',
        '../../src/main.cc',
        '../../src/openfiles.cc',
        '../../src/option.cc',
        '../../src/option_access.cc',
        '../../src/util.cc',
        '../../src/dialogs/attributesdialog.cc',
        '../../src/dialogs/characterdetailsdialog.cc',
        '../../src/dialogs/encodingdialog.cc',
        '../../src/dialogs/highlightdialog.cc',
        '../../src/dialogs/openrecentdialog.cc',
        '../../src/dialogs/selectbufferdialog.cc',
        '../../src/dialogs/optionsdialog.cc',
    ),
    tilde_config_schema,
    tilde_recent_files_schema,
    generated_headers,
    include_directories: [generated_include, tilde_include, unistring_inc],
    cpp_args: [
        '-DTILDE_DEBUG',
        '-DHAS_STRDUP',
        '-DCXX11SWITCH=1',
        '-DTILDE_VERSION="@0@"'.format(meson.project_version()),
        '-DDATADIR="@0@"'.format(tilde_data_dir),
    ],
    dependencies: [
        t3widget_dep,
        t3window_dep,
        transcript_dep,
        t3config_dep,
        t3highlight_dep,
        unistring_dep,
    ],
    install: true,
)

test(
    'tilde-version',
    tilde_exe,
    args: ['--version'],
    timeout: 30,
)
