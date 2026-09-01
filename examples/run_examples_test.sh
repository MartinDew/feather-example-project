#!/usr/bin/env bash
#
# Builds the example extensions and asserts they actually work: that the engine
# loads each one, that each runs at the init levels it should, and that every
# language agrees on the values it computes.
#
# The C and C# extensions are declared by .fext manifests and build from
# api/feather_api.json alone. The C++ one is discovered the old way, by probing
# shared libraries for _load_extension, and is here to prove that path still
# works untouched.
#
# Usage: examples/run_examples_test.sh [path/to/FeatherEngine]
# The engine may also come from $FEATHER_ROOT. It must be built, with its C
# bindings (xmake build feather).

set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILURES=0
PASSES=0

pass() { printf '  \033[32mPASS\033[0m %s\n' "$1"; PASSES=$((PASSES + 1)); }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILURES=$((FAILURES + 1)); }

# assert_contains <description> <file> <literal string>
assert_contains() {
    if grep -qF -- "$3" "$2"; then pass "$1"; else fail "$1 (expected to find: $3)"; fi
}

# assert_field <description> <file> <tag> <field label> <value>
# Scoped to one plugin's own output lines. A bare grep of the whole log would
# let one language satisfy another's assertion, since all three print the same
# values -- which is exactly what this test exists to distinguish.
assert_field() {
    local desc="$1" file="$2" tag="$3" field="$4" want="$5" line
    # An empty tag means the whole file is the scope (the Python example prints
    # no prefix); grepping for a literal "[]" would match nothing.
    if [ -n "$tag" ]; then
        line=$(grep -F -- "[$tag]" "$file" | grep -F -- "$field" | head -1)
    else
        line=$(grep -F -- "$field" "$file" | head -1)
    fi

    if [ -n "$line" ] && printf '%s' "$line" | grep -qF -- "$want"; then
        pass "$desc"
    else
        fail "$desc (expected $want; got: ${line:-<no matching line>})"
    fi
}

# assert_absent <description> <file> <literal string>
assert_absent() {
    if grep -qF -- "$3" "$2"; then
        fail "$1 (unexpectedly found: $3)"
        grep -F -- "$3" "$2" | head -3 | sed 's/^/       /'
    else
        pass "$1"
    fi
}

# ── Locate an engine with generated bindings ─────────────────────────────────
ENGINE_ROOT="${1:-${FEATHER_ROOT:-}}"
if [ -z "$ENGINE_ROOT" ]; then
    for candidate in "$PROJECT_DIR"/../FeatherEngine*; do
        # A built engine binary, not just a checkout: the C bindings are
        # compiled into it, so it is what the C and C# extensions resolve
        # their imports against.
        if [ -x "$candidate/build/bin/feather" ]; then
            ENGINE_ROOT="$(cd "$candidate" && pwd)"
            break
        fi
    done
fi

if [ -z "$ENGINE_ROOT" ]; then
    echo "error: no built FeatherEngine checkout found." >&2
    echo "       Pass one as an argument, or set FEATHER_ROOT." >&2
    exit 2
fi

ENGINE_BIN="$ENGINE_ROOT/build/bin/feather"
echo "engine: $ENGINE_ROOT"

if [ ! -e "$ENGINE_BIN" ]; then
    echo "error: missing $ENGINE_BIN" >&2
    echo "       Build the engine first:" >&2
    echo "         cd $ENGINE_ROOT && xmake build feather" >&2
    exit 2
fi

# The bindings are compiled into the engine rather than shipped beside it, so
# their absence looks like a normal engine binary until a plugin fails to
# resolve. Check up front, where the message can say what to rebuild.
# Matched with bash's own pattern operator rather than a pipe into grep -q:
# under `set -o pipefail` a grep that exits at its first match closes the pipe,
# the writer dies of SIGPIPE, and the pipeline reports failure even though the
# symbol was found. The engine's symbol table is several megabytes, so that is
# not a rare race here -- it happens every run.
engine_exports="$(nm -D --defined-only "$ENGINE_BIN" 2>/dev/null || true)"
if [[ "$engine_exports" != *" T Feather_"* ]]; then
    echo "error: $ENGINE_BIN exports no Feather_* symbols." >&2
    echo "       It was built without the C bindings; the C and C# examples cannot load." >&2
    echo "         cd $ENGINE_ROOT && xmake f --enable_c_bindings=y -y && xmake build feather" >&2
    exit 2
fi

# The Python example needs the embedded interpreter (--enable_py_host) and the
# shipped module; both are optional, so its checks are skipped without them.
PY_MODULE="$ENGINE_ROOT/build/bin/python/feather.so"
RUN_PYTHON=0
if [ -f "$PY_MODULE" ] && [ -f "$PROJECT_DIR/examples/python/py_example.fext" ]; then
    RUN_PYTHON=1
fi

# ── Build the plugins ────────────────────────────────────────────────────────
echo
echo "building plugins..."
cd "$PROJECT_DIR" || exit 2
# Start from a clean bin/, so a stale plugin from an earlier run cannot pass
# the test on behalf of one that failed to build this time.
rm -rf bin
if ! xmake f -m debug -y --feather_sdk_path="$ENGINE_ROOT" >/dev/null 2>&1 \
   || ! xmake build -y >/dev/null 2>&1; then
    echo "error: plugin build failed; re-run 'xmake build' here to see why" >&2
    exit 2
fi

echo
echo "plugin artifacts:"
for lib in bin/libc_example.so bin/libcs_example.so bin/libcpp_example.so; do
    if [ -f "$lib" ]; then pass "$lib built"; else fail "$lib was not produced"; fi
done

# A manifest extension exports only its named entry point. Not exporting
# _load_extension is the point: it is what a language with no way to construct a
# C++ object can manage, and the manifest supplies the name instead.
check_export() {
    local lib="$1" sym="$2" symbols
    [ -f "$lib" ] || return
    # nm's output is captured before matching rather than piped into `grep -q`.
    # Under `set -o pipefail`, grep -q exits at the first match and closes the
    # pipe, so nm dies of SIGPIPE and the pipeline reports failure even though
    # the symbol was found. It only bites on libraries big enough that nm is
    # still writing when grep leaves -- which made this look like a flaky
    # missing export on the largest plugin alone.
    symbols=$(nm -D --defined-only "$lib" 2>/dev/null)
    # ... and fed to grep from a here-string rather than a pipe, because a
    # capture alone does not close the hole: `grep -q` still exits early and
    # SIGPIPEs whatever is writing into it. A here-string is a file, not a pipe.
    # Not anchored at the end: NativeAOT decorates its exports with a version
    # suffix (register_cs_example@@V1.0), which the dynamic linker resolves by
    # the base name the manifest gives it.
    if grep -qE " $sym(@|\$)" <<< "$symbols"; then
        pass "$(basename "$lib") exports $sym"
    else
        fail "$(basename "$lib") does not export $sym"
    fi
}
check_export bin/libc_example.so register_c_example
check_export bin/libcs_example.so register_cs_example
# The C++ example stays on the probing path, so it keeps the older ABI.
check_export bin/libcpp_example.so _load_extension
check_export bin/libcpp_example.so _destroy_extension

# Nothing built here may link the engine's build tree: that is what makes these
# plugins redistributable, and an accidental rpath or DT_NEEDED would silently
# tie them to one machine.
for lib in bin/libc_example.so bin/libcs_example.so; do
    [ -f "$lib" ] || continue
    dyn=$(readelf -d "$lib" 2>/dev/null)
    if printf '%s\n' "$dyn" | grep -qE "NEEDED.*feather|RUNPATH.*FeatherEngine|RPATH.*FeatherEngine"; then
        fail "$(basename "$lib") links or points into an engine build tree"
        readelf -d "$lib" | grep -E "NEEDED.*feather|PATH.*Feather" | sed 's/^/       /'
    else
        pass "$(basename "$lib") does not link the engine"
    fi
done

# ── Run the engine and check both plugins loaded ─────────────────────────────
echo
echo "running engine headless..."
ENGINE_LOG="$(mktemp)"
trap 'rm -f "$ENGINE_LOG"' EXIT

# --dump-db makes the engine print its ClassDB and exit rather than entering
# the main loop, so this terminates on its own. Headless needs no GPU.
( cd "$ENGINE_ROOT/build/bin" && timeout 120 stdbuf -oL -eL ./feather "$PROJECT_DIR" -w headless --dump-db ) \
    > "$ENGINE_LOG" 2>&1
ENGINE_STATUS=$?

if [ $ENGINE_STATUS -eq 0 ]; then
    pass "engine exited cleanly"
else
    fail "engine exited with status $ENGINE_STATUS"
    tail -15 "$ENGINE_LOG" | sed 's/^/       /'
fi

# Which loader claimed each extension matters as much as that it loaded: the
# manifests must go through FextFormatLoader and the C++ library through the
# probing path, or the test would still pass with the manifests ignored.
assert_contains "C plugin loaded from its manifest" "$ENGINE_LOG" \
    "FextFormatLoader: Loaded extension 'c_example'"
assert_contains "C# plugin loaded from its manifest" "$ENGINE_LOG" \
    "FextFormatLoader: Loaded extension 'cs_example'"
assert_contains "C++ plugin loaded by symbol probing" "$ENGINE_LOG" \
    "ExtensionFormatLoader: Loaded extension 'example'"
# The bindings are part of the engine binary, so there is nothing to load at
# startup and no separate library to ship. A stray one next to the engine would
# mean the old split build came back -- and would be silently preferred by
# anything still looking for it by name.
if [ -e "$ENGINE_ROOT/build/bin/libfeather_c.so" ] || [ -e "$ENGINE_ROOT/build/bin/feather_c.dll" ]; then
    fail "no separate bindings library beside the engine (found one in $ENGINE_ROOT/build/bin)"
else
    pass "no separate bindings library beside the engine"
fi

# The loader is quiet about libraries it rejects, so absence of these is the
# only signal that nothing was silently skipped.
assert_absent "no extension failed to load" "$ENGINE_LOG" "Failed to load library"
assert_absent "no non-ELF file was opened as a plugin" "$ENGINE_LOG" "invalid ELF header"

assert_contains "C++ plugin ran" "$ENGINE_LOG" "[cpp_example] Hello"

# Each plugin must actually run, at the first init level and the next one.
for tag in c_example cs_example; do
    assert_contains "$tag ran at init level Core"    "$ENGINE_LOG" "[$tag] init level 'Core' entered"
    assert_contains "$tag ran at init level Servers" "$ENGINE_LOG" "[$tag] init level 'Servers' entered"
done

# A plugin loaded twice means build output leaked into the scanned project
# directory -- index_project() has no skip list, so this is easy to reintroduce.
for tag in c_example cs_example; do
    count=$(grep -cF "[$tag] init level 'Core' entered" "$ENGINE_LOG")
    if [ "$count" -eq 1 ]; then
        pass "$tag loaded exactly once"
    else
        fail "$tag ran $count times at Core (expected 1; stray copy under the project dir?)"
    fi
done

# ── Cross-language agreement ─────────────────────────────────────────────────
# The three examples compute the same projection. If a binding marshals floats
# wrongly these diverge, which a per-language smoke test would not catch.
echo
echo "cross-language agreement:"
EXPECTED_FOV="1.0472"
EXPECTED_ASPECT="1.7778"
EXPECTED_FOV_X="1.5969"
TAGS="c_example cs_example"
if [ "$RUN_PYTHON" -eq 1 ]; then
    TAGS="$TAGS py_example"
    assert_contains "python script ran inside the engine" "$ENGINE_LOG" "[py_example]"

    # The .fpy path: no manifest, claimed by extension, and able to define ECS
    # types rather than only call the engine.
    assert_contains "bare .fpy script was found and run" "$ENGINE_LOG" \
        "ScriptFormatLoader: Ran python script"
    assert_contains "script defined an ECS component" "$ENGINE_LOG" \
        "[ecs_demo] component Drift registered"
    assert_contains "script defined a system over its own component" "$ENGINE_LOG" \
        "[ecs_demo] system advance registered"
    assert_contains "script defined a system over an engine component" "$ENGINE_LOG" \
        "[ecs_demo] system over engine Transform registered"
    # Storage really is the ECS's: zero-initialized on add, and readable back
    # through the same accessors a system uses.
    assert_contains "scripted component starts zero-initialized" "$ENGINE_LOG" \
        "[ecs_demo] initial speed 0.0 steps 0 offset (0.0, 0.0, 0.0)"
    assert_contains "scripted component round-trips writes" "$ENGINE_LOG" \
        "[ecs_demo] seeded speed 1.0 offset (10.0, 20.0, 30.0)"
    # A field type with no fixed layout is refused by name, not mislaid.
    assert_contains "unstorable field type is refused" "$ENGINE_LOG" \
        "[ecs_demo] string field refused:"
else
    echo "  (python example skipped: no $PY_MODULE)"
fi

for tag in $TAGS; do
    assert_field "$tag vertical fov is $EXPECTED_FOV rad" "$ENGINE_LOG" "$tag" "vertical fov" "$EXPECTED_FOV"
    assert_field "$tag horizontal fov is $EXPECTED_FOV_X rad" "$ENGINE_LOG" "$tag" "horizontal fov" "$EXPECTED_FOV_X"
    assert_field "$tag aspect ratio is $EXPECTED_ASPECT" "$ENGINE_LOG" "$tag" "aspect ratio" "$EXPECTED_ASPECT"
    assert_field "$tag near/far planes are 0.10/1000.00" "$ENGINE_LOG" "$tag" "near / far planes" "0.10 / 1000.00"
    assert_field "$tag reverse-Z swapped the planes" "$ENGINE_LOG" "$tag" "reverse-Z variant" "near 1000.00, far 0.10"
done

# ── Summary ──────────────────────────────────────────────────────────────────
echo
if [ $FAILURES -eq 0 ]; then
    printf '\033[32m%d checks passed, 0 failed\033[0m\n' "$PASSES"
    exit 0
fi
printf '\033[31m%d checks passed, %d FAILED\033[0m\n' "$PASSES" "$FAILURES"
echo "engine output: $ENGINE_LOG" >&2
trap - EXIT
exit 1
