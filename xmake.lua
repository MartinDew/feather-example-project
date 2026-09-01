-- Example Feather extensions, one per supported language. See examples/README.md.
--
-- The C and C# examples build against api/feather_api.json -- the API
-- description the engine publishes with `xmake export-api` -- through the
-- vendored SDK in sdk/. They need no FeatherEngine checkout, no engine
-- headers, and no C++ compiler for the engine's code: generating bindings from
-- that one file is the whole toolchain, the way a GDExtension project works
-- from extension_api.json.
--
-- The C++ example is different in kind and still needs the engine tree, since
-- it compiles against the engine's real headers with its exact flags. Point at
-- a checkout with, in order of precedence:
--   1. xmake f --feather_sdk_path=/path/to/FeatherEngine
--   2. FEATHER_ROOT in the environment
--   3. a sibling ../FeatherEngine
-- Without one, the C++ target is skipped and the others still build.
set_xmakever("2.9.0")
set_project("feather-example-project")
-- The C++ example compiles the engine's headers, which are C++23. "clatest"
-- keeps the C example on a modern C standard rather than the toolchain default.
set_languages("cxx23", "clatest")
add_rules("mode.debug", "mode.releasedbg", "mode.release")

option("feather_sdk_path")
    set_default("")
    set_showmenu(true)
    set_description("Absolute path to a FeatherEngine checkout (only needed for the C++ example)")
option_end()

-- ---- Locating a FeatherEngine checkout ------------------------------------

-- Resolved up here because two separate things need it: the published-API
-- check below (to tell you where to regenerate api/ from) and the C++ example
-- further down (which compiles against the engine's headers).
--
-- The description scope has no io/import/assert, so an unresolved engine root
-- can't fail cleanly here -- print guidance and skip the affected targets
-- instead. Every candidate is checked for the SDK file rather than taken on
-- trust: the configured path in particular is cached by `xmake f` and outlives
-- the checkout it names, and includes()'ing a path that no longer exists fails
-- later and much less clearly.
local function is_feather_root(candidate)
    return candidate and candidate ~= ""
        and os.isfile(path.join(candidate, "tools", "SDK", "FeatherSDK.lua"))
end

local function resolve_feather_root()
    local configured = has_config("feather_sdk_path") and get_config("feather_sdk_path")
    if configured and configured ~= "" then
        if is_feather_root(configured) then
            return configured
        end
        print("[feather] --feather_sdk_path points at no FeatherEngine checkout: " .. configured)
    end

    local env = os.getenv("FEATHER_ROOT")
    if env and env ~= "" then
        if is_feather_root(env) then
            return env
        end
        print("[feather] FEATHER_ROOT points at no FeatherEngine checkout: " .. env)
    end

    for _, candidate in ipairs(os.dirs(path.join(os.projectdir(), "..", "FeatherEngine*"))) do
        if is_feather_root(candidate) then
            -- Collapse the ".." segment: this path is printed as copy-pasteable
            -- guidance below, and is what includes() resolves against.
            return path.normalize(candidate)
        end
    end

    return nil
end

local FEATHER_ROOT = resolve_feather_root()

-- ---- Language examples, built from the published API ----------------------

includes("sdk/FeatherPluginSDK.lua")
feather_plugin_sdk_init()

local API_JSON = "api/feather_api.json"

-- api/ is generated, not committed (see .gitignore and examples/README.md), so
-- a fresh clone has none until someone exports it from an engine checkout.
-- Skip with guidance rather than failing deep inside the SDK's generator step.
if os.isfile(path.join(os.projectdir(), API_JSON)) then

    -- examples/c -- a Feather extension in plain C.
    feather_c_plugin("c_example", {
        files = "examples/c/c_example.c",
        api_json = API_JSON,
    })

    -- examples/csharp -- the same extension in C#, published with NativeAOT so
    -- the result is an ordinary native shared library.
    feather_cs_plugin("cs_example", {
        csproj = "examples/csharp/CsExample.csproj",
        api_json = API_JSON,
        -- dotnet names the output after the assembly; the manifest names the
        -- file the engine loads. Both are left at the SDK's defaults, which
        -- already vary by host OS to match cs_example.fext's "libraries" table:
        -- the published assembly is CsExample.{dll,so,dylib}, staged into bin/
        -- as cs_example.dll on Windows or libcs_example.{so,dylib} elsewhere.
    })

else
    print("[feather] No " .. API_JSON .. "; skipping the C and C# examples.")
    if FEATHER_ROOT then
        print("[feather] Generate it from the engine checkout found at " .. FEATHER_ROOT .. ":")
        print("[feather]   cd " .. FEATHER_ROOT .. " && xmake export-api")
        print("[feather]   cp " .. path.join(FEATHER_ROOT, "build", "bindings", "dist", "*")
            .. " " .. path.join(os.projectdir(), "api") .. "/")
    else
        print("[feather] Run `xmake export-api` in a FeatherEngine checkout and copy")
        print("[feather] its build/bindings/dist/ contents into " .. path.join(os.projectdir(), "api") .. "/")
    end
end

-- ---- C++ example, built against the engine itself -------------------------

if FEATHER_ROOT then
    includes(path.join(FEATHER_ROOT, "tools", "SDK", "FeatherSDK.lua"))

    -- Must be built with the same FeatherEngine configuration as the engine
    -- binary this DLL loads into.
    feather_sdk_setup("cpp_example", {
        codegen_dirs = {{dir = "src", name = "cpp_example"}},
    })

    -- Reopened: feather_sdk_setup() opens and closes its own target scope, and
    -- leaves the kind, sources and output directory to the consumer.
    target("cpp_example")
        set_kind("shared")
        -- Flat, not bin/$(mode): the engine finds this DLL by scanning the
        -- project directory, so a per-mode subdir would leave stale copies.
        set_targetdir(path.join(os.projectdir(), "bin"))
        add_files("src/*.cpp")
    target_end()
else
    print("[feather] No FeatherEngine checkout found; skipping the C++ example.")
    print("[feather] The C and C# examples do not need one and still build.")
    print("[feather] To build it too:  xmake f --feather_sdk_path=/path/to/FeatherEngine")
end
