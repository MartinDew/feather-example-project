-- MRBind's binding generators, without its parser.
--
-- This is the plugin-side counterpart to thirdparty/packages/mrbind.lua. A
-- plugin project never parses C++: the engine did that once and shipped the
-- result as feather_api.json, and turning that JSON into C headers or C#
-- sources is all a plugin build has to do.
--
-- That distinction is what makes this package cheap. mrbind_gen_c and
-- mrbind_gen_csharp link no Clang and no LLVM -- only the parser does -- so
-- with MRBIND_BUILD_PARSER=OFF this builds with a plain host compiler in a
-- couple of minutes, instead of potentially building LLVM from source. It also
-- means a plugin author needs no Clang installation, and no engine checkout.
--
-- Keep the git revision in sync with thirdparty/packages/mrbind.lua: the
-- parser's JSON schema is undocumented and unversioned upstream, so a
-- generator from a different revision may not read the engine's api.json.
package("mrbind_generators")
    set_kind("binary")
    set_homepage("https://github.com/MeshInspector/mrbind")
    set_description("MRBind's C and C# binding generators (no parser, no LLVM)")
    set_license("MIT")

    -- KEEP IN SYNC with thirdparty/packages/mrbind.lua's pin: a generator has
    -- to be able to read the api.json the engine's parser produced.
    add_urls("https://github.com/MeshInspector/mrbind.git", {commit = "232ff33159d5e76e57b11669453d7d25ad22a14d"})
    set_policy("platform.longpaths", true)

    add_deps("cmake", "ninja")

    on_install(function (package)
        import("package.tools.cmake")

        local configs = {
            "-DCMAKE_BUILD_TYPE=" .. (package:is_debug() and "Debug" or "RelWithDebInfo"),
            -- The whole point of this package: no parser, so no
            -- find_package(Clang), so no LLVM anywhere in the build.
            "-DMRBIND_BUILD_PARSER=OFF",
            "-DMRBIND_BUILD_GENERATOR_C=ON",
            "-DMRBIND_BUILD_GENERATOR_CSHARP=ON",
        }

        -- os.host(), not package:is_plat("windows"): this is a host = true
        -- package (tools/SDK/FeatherPluginSDK.lua), meaning it always builds
        -- for whichever machine is running the build, never for the
        -- consuming project's configured target. is_plat() answers a
        -- different question -- what the project's target platform is -- and
        -- was observed disagreeing with reality here on CI specifically:
        -- xmake itself logged "checking for platform ... windows (x64)" in
        -- the same run where is_plat("windows") read false throughout this
        -- whole on_install, silently skipping every fixup below and then
        -- failing the assert further down expecting an unsuffixed binary
        -- name that Windows never produces. os.host() asks the one question
        -- that actually matters for a host tool and has no such ambiguity --
        -- the same reasoning tools/SDK/modules/feather_plugin_bindings.lua's
        -- host_dotnet_rid() already applies to picking a NativeAOT RID.
        if os.host() == "windows" then
            -- mrbind's own CMakeLists.txt only requests a C++ standard on
            -- `if(NOT MSVC)` -- its Windows docs assume Clang built against
            -- MSVC's libraries, not real cl.exe, so the MSVC branch gets no
            -- flag at all. This package deliberately uses the default (real
            -- MSVC) toolchain instead, since the generators link neither Clang
            -- nor LLVM and have no reason to need either. Left unset, cl.exe
            -- silently compiles in a pre-C++17 mode and <filesystem> in
            -- src/common/filesystem.h fails to find std::filesystem at all.
            --
            -- CMAKE_CXX_STANDARD, not a raw /std: flag: CMakeLists.txt never
            -- sets it itself (the assignment is commented out, "old CMake
            -- doesn't understand it"), so a target's CXX_STANDARD property
            -- defaults to whatever the command line supplied -- this is the
            -- one case where setting the CMake variable from outside actually
            -- takes effect, rather than being shadowed by the project's own
            -- assignment the way CMAKE_CXX_FLAGS is below.
            table.insert(configs, "-DCMAKE_CXX_STANDARD=23")
            table.insert(configs, "-DCMAKE_CXX_STANDARD_REQUIRED=ON")

            local buildtype_map = {debug = "DEBUG", release = "RELEASE", releasedbg = "RELWITHDEBINFO"}
            local buildtype = buildtype_map[package:mode()] or "RELEASE"
            for _, key in ipairs({
                "CMAKE_C_FLAGS", "CMAKE_C_FLAGS_" .. buildtype,
                "CMAKE_CXX_FLAGS_" .. buildtype,
                "CMAKE_EXE_LINKER_FLAGS_" .. buildtype,
            }) do
                table.insert(configs, "-D" .. key .. "=")
            end

            -- MSVC's traditional preprocessor does not implement __VA_OPT__,
            -- and /std:c++latest does not switch preprocessors -- for C++ that
            -- needs /Zc:preprocessor explicitly (unlike C, where /std:c11 and
            -- later imply it).
            --
            -- src/common/reflection.h leans on __VA_OPT__ heavily: MBREFL_STRUCT
            -- pastes DETAIL_MBREFL_STRUCT_INIT_ onto the result of a macro whose
            -- whole body is `__VA_OPT__(1)`. Without the conforming preprocessor
            -- that token survives literally and the paste yields the identifier
            -- DETAIL_MBREFL_STRUCT_INIT___VA_OPT__, which is the error actually
            -- reported; every "undefined type mrbind::Entity" after it is
            -- fallout from the struct never being declared.
            --
            -- Set as CMAKE_CXX_FLAGS rather than added to the cleared list
            -- above, since the project appends its own -D_ITERATOR_DEBUG_LEVEL=0
            -- to this same variable and both have to survive.
            --
            -- Passed unconditionally: which compiler builds this package is not
            -- ours to choose (a host package takes the default host toolchain,
            -- which is cl.exe even when the consuming project is configured for
            -- clang-cl), and clang-cl accepts the flag as a no-op -- its own
            -- preprocessor already conforms -- warning only that the argument
            -- went unused.
            table.insert(configs, "-DCMAKE_CXX_FLAGS=/Zc:preprocessor")
        end

        local builddir = path.join(package:builddir(), ".cmake_build")
        cmake.build(package, configs, {builddir = builddir, cmake_generator = "Ninja"})

        -- No install() rules upstream; copy the generators out by hand.
        --
        -- Tried without an .exe suffix first when os.host() isn't "windows"
        -- and with one otherwise, but a mismatch between the two isn't fatal
        -- on its own: whichever spelling the build actually produced is
        -- accepted, since a Windows PE binary carries .exe regardless of
        -- which compiler built it, and the point of the os.host() switch
        -- above is precisely that this package's own view of "is this
        -- Windows" cannot always be trusted for that decision either.
        local bindir = package:installdir("bin")
        for _, name in ipairs({"mrbind_gen_c", "mrbind_gen_csharp"}) do
            local preferred = os.host() == "windows" and (name .. ".exe") or name
            local fallback = os.host() == "windows" and name or (name .. ".exe")
            local built = path.join(builddir, preferred)
            if not os.isfile(built) then
                built = path.join(builddir, fallback)
            end
            assert(os.isfile(built), "mrbind_generators: expected build output missing: "
                .. path.join(builddir, preferred) .. " (also checked " .. fallback .. ")")
            os.cp(built, bindir)
        end
    end)

    on_test(function (package)
        os.vrun(path.join(package:installdir("bin"),
            "mrbind_gen_c" .. (os.host() == "windows" and ".exe" or "")) .. " --help")
    end)
package_end()
