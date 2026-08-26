-- Discovery order for the FeatherEngine checkout:
--   1. xmake config option:  xmake f --feather_sdk_path=/path/to/FeatherEngine
--   2. FEATHER_ROOT environment variable
--   3. Sibling ../FeatherEngine next to this project (zero-config default)
set_xmakever("2.9.0")
set_project("example")
set_languages("cxx23")
add_rules("mode.debug", "mode.releasedbg", "mode.release")

option("feather_sdk_path")
    set_default("")
    set_showmenu(true)
    set_description("Absolute path to a FeatherEngine checkout")
option_end()

-- Note on the description-scope sandbox: only a restricted set of globals is
-- available here (no io, no os.readfile, no import, no pcall/error/assert --
-- those exist only inside callbacks like on_load/before_build). That is why the
-- root can only come from things readable at this scope: the config option
-- (has_config/get_config), an env var (os.getenv), and on-disk probing
-- (os.isfile). An unresolved root therefore can't hard-fail cleanly; we print
-- guidance and skip includes(), letting a later build fail naturally.
--
-- Also note xmake evaluates this scope several times per `xmake f`; on the
-- first pass or two has_config() is still false because the option value has
-- not been resolved yet. That is fine -- a later pass resolves it and the value
-- persists to subsequent `xmake` invocations via the config cache.
local function feather_root_has_sdk(root)
    return root and root ~= "" and os.isfile(path.join(root, "tools", "SDK", "FeatherSDK.lua"))
end

local function resolve_feather_root()
    if has_config("feather_sdk_path") then
        local p = get_config("feather_sdk_path")
        if p and p ~= "" then return p end
    end
    local env = os.getenv("FEATHER_ROOT")
    if env and env ~= "" then return env end
    local sibling = path.join(os.projectdir(), "..", "FeatherEngine")
    if feather_root_has_sdk(sibling) then return sibling end
    return nil
end

local FEATHER_ROOT = resolve_feather_root()
if FEATHER_ROOT then
    includes(path.join(FEATHER_ROOT, "tools", "SDK", "FeatherSDK.lua"))

    -- "example", not default "src", so the generated entry point can't be
    -- confused with the hand-written register_project_types below.
    feather_sdk_setup("example", {codegen_dirs = {{dir = "src", name = "example"}}})

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
    print("[feather]   export FEATHER_ROOT=/path/to/FeatherEngine")
    print("[feather]   place the engine at ../FeatherEngine next to this project")
end
