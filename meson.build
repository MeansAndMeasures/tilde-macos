project(
    'tilde-macos',
    ['c', 'cpp'],
    version: '0.1.0',
    meson_version: '>=1.3.0',
    default_options: [
        'c_std=c23',
        'cpp_std=c++23',
        'warning_level=2',
        'buildtype=debugoptimized',
    ],
)

if host_machine.system() != 'darwin'
    error('Tilde for macOS supports Darwin only')
endif

if host_machine.cpu_family() != 'aarch64'
    error('Tilde for macOS supports Apple Silicon ARM64 only')
endif

cc = meson.get_compiler('c')
cpp = meson.get_compiler('cpp')
python = import('python').find_installation(required: true)
flex = find_program('flex', required: true)
llnextgen = find_program('LLnextgen', required: true)

pcre2_dep = dependency('libpcre2-8', required: true)
ncurses_dep = dependency('ncursesw', required: true)
threads_dep = dependency('threads')
m_dep = cc.find_library('m', required: false)

brew = find_program('brew', required: true)
brew_prefix = run_command(brew, '--prefix', check: true).stdout().strip()
unistring_prefix = run_command(brew, '--prefix', 'libunistring', check: true).stdout().strip()
gettext_prefix = run_command(brew, '--prefix', 'gettext', check: true).stdout().strip()

unistring_inc = include_directories(unistring_prefix / 'include')
intl_inc = include_directories(gettext_prefix / 'include')

unistring_dep = cc.find_library(
    'unistring',
    dirs: [unistring_prefix / 'lib'],
    required: true,
)

intl_dep = cc.find_library(
    'intl',
    dirs: [gettext_prefix / 'lib'],
    required: true,
)

codegen = files('tools/meson_codegen.py')
generated_include = include_directories('meson')

generated_headers = custom_target(
    'generated-header-tree',
    output: 'generated-header-tree.h',
    command: [
        python,
        codegen,
        'headers',
        meson.current_source_dir(),
        meson.current_build_dir() / 'meson',
        '@OUTPUT@',
    ],
    build_always_stale: true,
)

message('C compiler: ' + cc.get_id())
message('C++ compiler: ' + cpp.get_id())
message('Architecture: ' + host_machine.cpu_family())
message('Platform: ' + host_machine.system())
message('Homebrew prefix: ' + brew_prefix)

subdir('meson/transcript')
subdir('meson/t3config')
subdir('meson/t3key')
subdir('meson/t3highlight')
subdir('meson/t3window')
subdir('meson/t3widget')
subdir('meson/tilde')

summary(
    {
        'Libraries': 'transcript, t3config, t3key, t3highlight, t3window, t3widget',
        'Executable': 'tilde',
        'Transcript modules': 'ascii, unicode, iso2022, euctw',
    },
    section: 'Build targets',
)
