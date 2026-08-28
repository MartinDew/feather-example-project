// A Feather extension written in plain C, against bindings generated from the
// engine's published API description (api/feather_api.json). Nothing here
// includes an engine C++ header, and nothing links the engine: the whole engine
// surface this file touches arrives through generated declarations and resolves
// at load time against libfeather_c, which the engine loads at startup.
//
// The engine finds this extension through c_example.fext, the manifest sitting
// next to this file. That is what makes a C extension possible at all: the
// older discovery path asks a library to hand back a C++ Extension object,
// which C has no way to construct. The manifest names the entry point instead,
// so all this file has to export is one plain C function.

#include <feather_c/main/init_level.h>
#include <feather_c/math/projection.h>

#include <stdio.h>

#if defined(_WIN32) || defined(_WIN64)
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default")))
#endif

static void report_projection(void) {
	// create_perspective_fov takes degrees; the getters below return radians
	// or a ratio, so this doubles as a check that values survive the boundary.
	feather_Projection *proj = feather_Projection_create_perspective_fov(60.0f, 16.0f / 9.0f, 0.1f, 1000.0f);

	printf("[c_example]   projection type   : %s\n",
			feather_Projection_get_type(proj) == feather_ProjectionType_Perspective ? "Perspective" : "Orthographic");
	printf("[c_example]   vertical fov      : %.4f rad\n", feather_Projection_get_fov_y(proj));
	printf("[c_example]   horizontal fov    : %.4f rad\n", feather_Projection_get_fov_x(proj));
	printf("[c_example]   aspect ratio      : %.4f\n", feather_Projection_get_aspect_ratio(proj));
	printf("[c_example]   near / far planes : %.2f / %.2f\n",
			feather_Projection_get_near_plane(proj), feather_Projection_get_far_plane(proj));
	printf("[c_example]   reverse-Z         : %s\n", feather_Projection_is_reverse_z(proj) ? "yes" : "no");

	// Every generated function returning a class type hands back a heap
	// allocation the caller owns, so the derived projection needs its own
	// Destroy call just like the one above.
	feather_Projection *reversed = feather_Projection_create_reverse_z(proj);
	printf("[c_example]   reverse-Z variant : near %.2f, far %.2f, reverse-Z %s\n",
			feather_Projection_get_near_plane(reversed), feather_Projection_get_far_plane(reversed),
			feather_Projection_is_reverse_z(reversed) ? "yes" : "no");

	feather_Projection_Destroy(reversed);
	feather_Projection_Destroy(proj);
}

// The entry point named by c_example.fext. Called once per initialization
// level the engine enters, ascending. There is no matching call on the way out:
// exit_init_level() unregisters built-in modules only, so an extension sees
// enter calls and nothing else.
EXPORT void register_c_example(feather_InitLevel level) {
	printf("[c_example] init level '%s' entered\n", feather_to_string(level));

	// Core is the first level, and the only one this example needs -- a
	// Projection is a plain value type with no engine services behind it.
	if (level == feather_InitLevel_Core) {
		report_projection();
	}
}
