#include <iostream>
#include <core/math/transform.h>

extern "C" EXPORT void register_project_types() {
  std::cout << "Hello from example project DLL! This is dynamically loaded by "
               "the engine."
            << std::endl;
  // Here we can use ClassDB to register types using engine headers,
  // since the DLL is linked against the engine's import lib.
}
