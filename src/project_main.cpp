#include "defs.h"
#include "TestEcsModule.h"
#include "register_example_types.gen.h"

#include <main/class_db.h>

#include <iostream>
using namespace feather;

extern "C" EXPORT void register_project_types() {
	std::cout << "Hello from example project DLL! This is dynamically loaded by "
				 "the engine."
			  << std::endl;
	// Here we can use ClassDB to register types using engine headers,
	// since the DLL is linked against the engine's import lib.
	// World/scene setup happens later, in TestEcsModule's _import_module hook
	// (FCLASS(EcsModule)) -- WorldSim isn't initialized yet at this point.
	register_example_types();
}
