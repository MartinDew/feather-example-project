// The C++ extension, discovered the way C++ extensions always have been: the
// engine dlopens every shared library under the project and keeps the ones
// exporting _load_extension.
//
// The other examples declare themselves with a .fext manifest instead, which
// is what lets them be written in a language that cannot hand back a C++
// object. This one deliberately stays on the older path, so the project covers
// both: an existing C++ extension keeps working untouched.

#include "defs.h"

#include <core/main/init_level.h>
#include <core/resources/extension.h>

using namespace feather;

extern "C" EXPORT Extension* _load_extension() {
	return new Extension("example", "register_project_types");
}

// Freed where it was allocated: with a statically linked CRT on Windows each
// binary has its own heap, and crossing that boundary corrupts it.
extern "C" EXPORT void _destroy_extension(Extension* extension) {
	delete extension;
}
