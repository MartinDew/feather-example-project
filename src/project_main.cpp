#include "defs.h"

#include <core/main/init_level.h>

#include <iostream>

using namespace feather;

// Called once per initialization level the engine enters, ascending. The name
// is the one passed to Extension() in extension.cpp.
extern "C" EXPORT void register_project_types(InitLevel level) {
	if (level != InitLevel::Core) {
		return;
	}

	std::cout << "[cpp_example] Hello from the example project's C++ extension." << std::endl;
	// ClassDB registration goes here: this DLL sees the engine's real headers
	// and binds to its symbols, so anything the engine can do, it can do.
}
