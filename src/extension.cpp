#include "defs.h"

#include <core/resources/extension.h>

using namespace feather;

extern "C" EXPORT Extension* _load_extension() {
	return new Extension("example", "register_project_types");
}

// Must run in this DLL's own CRT/heap, matching _load_extension's `new` above --
// the engine cannot `delete` this object itself on Windows (each binary has its
// own private static-CRT heap under /MT; freeing across that boundary corrupts it).
extern "C" EXPORT void _destroy_extension(Extension* ext) {
	delete ext;
}