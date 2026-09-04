-- Example Feather extensions, one per supported language. See examples/README.md.
--
-- Every example builds against api/feather_api.json -- the API description the
-- engine publishes with `xmake export-api` -- through the SDK vendored via the
-- vendor/FeatherEngine submodule (sparse-checked-out to tools/SDK; run
-- `git submodule update --init` after cloning). None of them needs a
-- FeatherEngine checkout or the engine's headers:
-- generating bindings from that one file is the whole toolchain, the way a
-- GDExtension project works from extension_api.json.
--
-- The C++ example is no exception. It calls the same flat C entry points the C
-- one does, behind generated C++ classes.
set_xmakever("2.9.0")
set_project("feather-example-project")
-- "clatest" keeps the C example on a modern C standard rather than the
-- toolchain default; the C++ example needs C++23 for the generated wrappers.
set_languages("cxx23", "clatest")
add_rules("mode.debug", "mode.releasedbg", "mode.release")

-- ---- Language examples, built from the published API ----------------------

includes("vendor/FeatherEngine/tools/SDK/FeatherPluginSDK.lua")
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

    -- examples/cpp -- the same extension in C++, through the generated
    -- wrappers. No engine checkout: it resolves the same feather_* C symbols
    -- the C example does.
    feather_cpp_plugin("cpp_example", {
        files = "examples/cpp/cpp_example.cpp",
        api_json = API_JSON,
    })

else
    print("[feather] No " .. API_JSON .. "; skipping the examples.")
    print("[feather] Run `xmake export-api` in a FeatherEngine checkout and copy")
    print("[feather] its build/bindings/dist/feather_api.json into " .. path.join(os.projectdir(), "api") .. "/")
end
