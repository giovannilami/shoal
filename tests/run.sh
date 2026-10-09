#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
lua_bin=${LUA:-lua}

"$lua_bin" "$project_dir/tests/test_core.lua"
"$lua_bin" "$project_dir/tests/test_grid.lua"
"$lua_bin" "$project_dir/tests/test_runtime.lua"
"$lua_bin" "$project_dir/tests/test_font.lua"
"$lua_bin" "$project_dir/tests/test_ui.lua"
"$lua_bin" "$project_dir/tests/test_nb_integration.lua"
