# Example extensions

Four extensions, one per language the engine supports, all doing the same small
piece of work -- build a perspective `Projection`, read its properties back,
derive a reverse-Z variant -- so the files can be read side by side to see what
each language actually costs you.

| Example | How it is written | How the engine finds it |
| --- | --- | --- |
| `c/c_example.c` | C, against generated C headers | `c/c_example.fext` names the entry point |
| `csharp/CsExample.cs` | C#, NativeAOT native library | `csharp/cs_example.fext` names the entry point |
| `python/projection_demo.py` | Python script, run in-process | `python/py_example.fext` names the script |
| `../src/` | C++, against the engine's own headers | no manifest: probed for `_load_extension` |

## The workflow, and why it looks like this

The C and C# extensions build from **one file: `api/feather_api.json`**, the API
description the engine publishes. The SDK in `sdk/` runs mrbind's generators
over it to produce C headers or C# sources, and that is the whole toolchain --
no FeatherEngine checkout, no engine headers, no Clang, and nothing linked
against the engine at build time. It is the same shape as a GDExtension project
building from `extension_api.json`.

What makes that work at runtime is that the engine *is* the compiled other half:
the generated glue is built into the engine binary, which exports it along with
the rest of its API. A plugin's `feather_*` imports are simply left undefined
and bind to the engine process when it is loaded. Check it yourself:

    readelf -d bin/libc_example.so | grep NEEDED   # nothing feather-related

**Manifests are what let a non-C++ language do this at all.** The older
discovery path asks a library to export `_load_extension` returning a C++
`Extension` object -- which C cannot construct and C# can only reach through
hand-written P/Invoke with delicate ownership rules. A `.fext` manifest names
the entry point instead, so the engine constructs the object and the extension
exports one plain function. The C++ example deliberately stays on the old path,
so this project covers both.

**Python is not compiled at all.** Its manifest is `"type": "python"`, so the
engine hands the script to an interpreter embedded in the engine itself
(`modules/py_host`). The script reaches the engine through the `feather` module
shipped next to the engine binary, which binds to the running process -- so it
works here and *not* from a standalone interpreter. Being inside a live engine
is the point: the singletons it touches are the engine's own, already
initialized.

## Building

The engine must be built first, with its C bindings:

    cd ../FeatherEngine
    xmake f -m debug -y --enable_py_host=y
    xmake build feather py_bindings

`--enable_py_host` and `py_bindings` are only needed for the Python example.
The C bindings need no separate target: they are part of `feather` itself.

Then, from this project:

    xmake f -m debug -y
    xmake build

`c_example` needs only a C compiler. `cs_example` needs the .NET SDK on PATH.
`cpp_example` is the one target that needs the engine checkout, since it
compiles the engine's real headers; it is discovered as a `FeatherEngine*`
sibling, or named with `--feather_sdk_path=/path/to/FeatherEngine` or
`FEATHER_ROOT`. Without one it is skipped and the rest still build.

## Getting `api/`

**`api/` is generated, not committed.** A fresh clone has none, and the C and C#
targets are skipped (with instructions) until you populate it. Everything in it
is machine-specific -- the metadata records the absolute path and git revision
of the engine tree that produced it -- so it is regenerated per checkout rather
than tracked in git.

Populate it, and refresh it after any engine API change, with:

    cd ../FeatherEngine && xmake export-api
    cp build/bindings/dist/* ../feather-example-project/api/

`feather_api.meta.json` records which engine build and mrbind revision produced
the API file, so a mismatch between your generated headers and the engine you
load into is reported rather than discovered as a crash. On Windows the export
also carries the import library the plugin links against; on ELF and Mach-O
there is nothing to link, so the two JSON files are the whole input.

## Testing

`examples/run_examples_test.sh` is the check that all of this actually works. It
builds every extension from a clean `bin/`, asserts each exports the ABI its
discovery path requires, asserts none of them link the engine's build tree, runs
the engine headless, and verifies each was loaded exactly once by the right
loader and ran at the initialization levels it should. It then compares the
values every language computes, scoped per language so one cannot satisfy
another's assertion.

    examples/run_examples_test.sh                 # finds a built sibling engine
    examples/run_examples_test.sh /path/to/engine # or name one explicitly

Exits 0 on success, 1 if a check fails (printing expected vs. actual), 2 if the
engine is missing, naming what to build. The Python checks are skipped when the
engine was built without `--enable_py_host`.

## Running

Everything runs when the engine loads this project. Headless needs no GPU:

    cd /path/to/FeatherEngine/build/bin
    ./feather /path/to/feather-example-project -w headless --dump-db

`--dump-db` makes the engine print its ClassDB and exit instead of entering the
main loop, which is what makes this terminate.

## Things worth knowing

- **Ownership differs sharply.** C hands back heap allocations the caller must
  pair with `feather_*_Destroy`. C# wraps those in `IDisposable`. Python lets the
  interpreter's refcount do it. The same sequence appears under all three.
- **C# needs an explicit `DllImportResolver`.** The generated `[DllImport]`s name
  `feather_c`, which is not a file on disk at all -- the bindings live in the
  engine binary -- and .NET's default probing would look for a library. Worse, an
  exception escaping an `UnmanagedCallersOnly` entry point cannot propagate into
  C, so the failure arrives as a bare `abort()`. `CsExample.cs` resolves the name
  against the main program's handle and guards its entry point.
- **Keep build output out of the project directory.** `index_project()` walks the
  project with a plain recursive iterator and no skip list, not even for
  dot-directories, so every `.so` under it is opened. That is why the C# target
  stages dotnet's output in the system temp directory rather than under `build/`.
- **C# namespaces are one level.** Generated bindings live in `Feather` (helpers
  in `Feather.Misc`). Per-submodule namespaces would need the engine's C++ to use
  nested namespaces; it is flat `feather` today.
- **Extensions are never unloaded.** `exit_init_level()` unregisters built-in
  modules only, so an extension sees enter calls and nothing else.
