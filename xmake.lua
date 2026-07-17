-- Discovery order mirrors the old CMake find_package(Feather) fallback:
--   1. xmake config option:  xmake f --feather_sdk_path=/path/to/FeatherEngine
--   2. feather_dir.txt file in this project's root (gitignored)
--   3. FEATHER_ROOT environment variable
set_xmakever("2.9.0")
set_project("example")
set_languages("cxx23")
add_rules("mode.debug", "mode.releasedbg", "mode.release")

option("feather_sdk_path")
    set_default(nil)
    set_showmenu(true)
    set_description("Absolute path to a FeatherEngine checkout")
option_end()

-- Note: error()/raise()/os.raise()/assert() are all unavailable at this
-- (description) scope -- only usable inside callbacks like on_load/before_build.
-- So an unresolved root can't hard-fail cleanly here; print guidance and skip
-- includes(), letting the later feather_sdk_setup() call fail naturally.
local function resolve_feather_root()
    if has_config("feather_sdk_path") then
        return get_config("feather_sdk_path")
    end
    local dirfile = path.join(os.projectdir(), "feather_dir.txt")
    if os.isfile(dirfile) then
        local p = io.readfile(dirfile):trim()
        if p and p ~= "" then return p end
    end
    local env = os.getenv("FEATHER_ROOT")
    if env and env ~= "" then return env end
    return nil
end

local FEATHER_ROOT = resolve_feather_root()
if FEATHER_ROOT then
    includes(path.join(FEATHER_ROOT, "tools", "FeatherSDK.lua"))

    -- Old CMakeLists.txt linked Feather::Editor specifically.
    feather_sdk_setup("example", "editor")

    -- Separate, reopened block: feather_sdk_setup() opens and closes its own
    -- target scope internally, so this must come after it, not nested inside it.
    target("example")
        set_kind("shared")
        set_targetdir(path.join(os.projectdir(), "bin", "$(mode)"))
        add_files("src/project_main.cpp", "src/extension.cpp", "src/TestEcsModule.cpp")
        add_headerfiles("src/defs.h", "src/TestEcsModule.h")
    target_end()
else
    -- Don't crash: an unresolved root must still let this script finish
    -- cleanly (e.g. so `xmake f --feather_sdk_path=...` can register the
    -- option above in the first place -- a hard failure here would abort
    -- before that registration completes).
    print("[feather] Could not locate a FeatherEngine checkout. Set one of:")
    print("[feather]   xmake f --feather_sdk_path=/path/to/FeatherEngine")
    print("[feather]   echo /path/to/FeatherEngine > feather_dir.txt   (gitignored)")
    print("[feather]   export FEATHER_ROOT=/path/to/FeatherEngine")
end
