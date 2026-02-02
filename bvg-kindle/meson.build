project('bvg-kindle', 'cpp', version: 'v1.0.0',
        default_options: ['cpp_std=c++17'], meson_version: '>=1.1')

gtk_dep = dependency('gtk+-2.0')
curl_dep = dependency('libcurl')
json_dep = dependency('json-c', fallback: ['json-c', 'json_c_dep'])

sources = files(
    'src/main.cpp',
    'src/bvg_api.cpp',
    'src/display.cpp',
    'src/config.cpp',
    'src/kindle.cpp'
)

executable('bvg-kindle', sources,
    dependencies: [gtk_dep, curl_dep, json_dep],
    cpp_args: '-static-libstdc++',
    link_args: '-static-libstdc++')
