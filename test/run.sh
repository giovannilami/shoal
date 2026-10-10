#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
lua_bin=${LUA:-lua}

"$lua_bin" "$project_dir/test/test_core.lua"
"$lua_bin" "$project_dir/test/test_grid.lua"
"$lua_bin" "$project_dir/test/test_mod.lua"
"$lua_bin" "$project_dir/test/test_runtime.lua"
"$lua_bin" "$project_dir/test/test_font.lua"
"$lua_bin" "$project_dir/test/test_ui.lua"
"$lua_bin" "$project_dir/test/test_nb_integration.lua"
"$lua_bin" "$project_dir/test/test_stress.lua"
