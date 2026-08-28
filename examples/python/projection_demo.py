#!/usr/bin/env python3
"""A Feather extension written as a Python script.

The engine finds this through py_example.fext, the manifest next to it. That
manifest is of type "python", so instead of loading a shared library the engine
hands the script to its embedded interpreter (modules/py_host) and runs it.

Python is the one language here that is not compiled into a plugin. The C and C#
examples build native libraries from generated bindings; this script is executed
in-process by an interpreter the engine already owns, and reaches the engine
through the `feather` module the engine ships next to its binary. That module is
built to bind against the running engine, so importing it only works here -- not
from a standalone interpreter.

Being inside a live engine is the point: the singletons this touches are the
engine's own, already initialized.
"""

# No sys.path setup: py_host puts the shipped module on the path before running
# this, and the module only works inside the engine process anyway.
import feather

# Namespaces are preserved by default, so the C++ feather:: namespace shows up
# as a submodule inside the feather module -- hence feather.feather.
fe = feather.feather

TAG = "[py_example]"


def show_projection():
    """The same walk the C and C# examples do, for comparison."""
    proj = fe.Projection.create_perspective_fov(60.0, 16.0 / 9.0, 0.1, 1000.0)

    print(f"{TAG}   projection type   : {proj.get_type().name}")
    print(f"{TAG}   vertical fov      : {proj.get_fov_y():.4f} rad")
    print(f"{TAG}   horizontal fov    : {proj.get_fov_x():.4f} rad")
    print(f"{TAG}   aspect ratio      : {proj.get_aspect_ratio():.4f}")
    print(f"{TAG}   near / far planes : {proj.get_near_plane():.2f} / {proj.get_far_plane():.2f}")
    print(f"{TAG}   reverse-Z         : {'yes' if proj.is_reverse_z() else 'no'}")

    reversed_proj = proj.create_reverse_z()
    print(
        f"{TAG}   reverse-Z variant : near {reversed_proj.get_near_plane():.2f}, "
        f"far {reversed_proj.get_far_plane():.2f}, "
        f"reverse-Z {'yes' if reversed_proj.is_reverse_z() else 'no'}"
    )
    # No Destroy calls anywhere: pybind11 owns these objects and frees them
    # when Python drops the last reference. The C example has to pair every
    # constructor with feather_Projection_Destroy by hand.


def show_transform():
    """Transform's operations are static, so they read as free functions here."""
    a = fe.Transform()
    b = fe.Transform()

    composed = fe.Transform.multiply(a, b)
    relative = fe.Transform.get_relative_transform(a, b)

    print(f"{TAG}   identity rotation normalized : {a.is_rotation_normalized()}")
    print(f"{TAG}   a * b                        : {type(composed).__name__}")
    print(f"{TAG}   a relative to b              : {type(relative).__name__}")
    print(f"{TAG}   inverse(a)                   : {type(fe.Transform.inverse(a)).__name__}")


def show_cow_vector():
    """CowVector is copy-on-write, and Python can watch the sharing directly."""
    mesh = fe.MeshData()

    vertices = mesh.get_vertices()
    print(f"{TAG}   fresh MeshData vertices : size={vertices.size()} empty={vertices.empty()}")

    # reserve/resize go through the same CowVector the engine uses internally.
    vertices.reserve(8)
    print(f"{TAG}   after reserve(8)        : size={vertices.size()} capacity={vertices.capacity()}")
    print(f"{TAG}   shared with the mesh    : {vertices.is_shared()} (use_count={vertices.use_count()})")

    indices = mesh.get_indices()
    print(f"{TAG}   fresh MeshData indices  : size={indices.size()} empty={indices.empty()}")


def show_scalar_helpers():
    """Free functions from math_defs.h and init_level.h."""
    print(f"{TAG}   deg_to_rad(60)            : {fe.deg_to_rad(60.0):.4f}")
    print(f"{TAG}   rad_to_deg(pi)            : {fe.rad_to_deg(3.14159265):.2f}")
    print(f"{TAG}   is_power_of_two(64)       : {fe.is_power_of_two(64)}")
    print(f"{TAG}   round_up_to_next_pow_2(100): {fe.round_up_to_next_pow_2(100)}")

    levels = [fe.InitLevel.Core, fe.InitLevel.Servers, fe.InitLevel.World, fe.InitLevel.Editor]
    print(f"{TAG}   init levels               : {', '.join(fe.to_string(l) for l in levels)}")


def main():
    print(f"{TAG} Projection")
    show_projection()
    print(f"{TAG} Transform")
    show_transform()
    print(f"{TAG} CowVector (copy-on-write storage)")
    show_cow_vector()
    print(f"{TAG} scalar helpers")
    show_scalar_helpers()

    # Running inside the engine, so the reflection registry is the live one --
    # Main::setup_db() populated it long before this script was reached. That
    # was the thing an out-of-process interpreter could never have.
    print(f"{TAG} running inside a live engine process")


# Run unconditionally: py_host executes this file directly, so __name__ is
# "__main__" here, but saying so plainly is clearer about what the engine does.
main()
