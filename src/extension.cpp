#include "defs.h"

#include <core/resources/extension.h>

using namespace feather;

extern "C" EXPORT Extension* _load_extension() {
	return new Extension("example", "register_project_types");
}