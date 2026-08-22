#include "defs.h"

#include <iostream>

#include "TestEcsModule.h"
#include "main/class_db.h"
#include "register_example_types.gen.h"

using namespace feather;

extern "C" EXPORT void register_project_types() {
  std::cout << "Hello from example project DLL! This is dynamically loaded by "
               "the engine."
            << std::endl;
  // Here we can use ClassDB to register types using engine headers,
  // since the DLL is linked against the engine's import lib.
  register_example_types();

    std::cout << "Registering TestModule!\n";
}
