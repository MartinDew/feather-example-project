#include "defs.h"

#include <core/resources/native_extension.h>

using namespace feather;

extern "C" EXPORT NativeExtension* _load_extension() {
	return new NativeExtension("example", "register_project_types");
}