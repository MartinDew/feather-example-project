cmake_minimum_required(VERSION 3.15)
project(example)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Map our custom 'Development' config onto the engine's RelWithDebInfo export
set(CMAKE_MAP_IMPORTED_CONFIG_Development RelWithDebInfo Release "" CACHE STRING "" FORCE)

# ---------------------------------------------------------------------------
# Locate the Feather engine SDK.
#
# Priority:
#   1. CMake user package registry (set automatically when engine is built)
#   2. FEATHER_SDK_PATH CMake variable (passed via -D)
#   3. feather_dir.txt file (legacy fallback)
#   4. FEATHER_ROOT environment variable
# ---------------------------------------------------------------------------

# First, try to find Feather via CMake's package registry (auto-registered by engine)
find_package(Feather QUIET)

if(NOT Feather_FOUND)
    # Try explicit path from CMake variable
    if(DEFINED FEATHER_SDK_PATH)
        list(APPEND CMAKE_PREFIX_PATH "${FEATHER_SDK_PATH}")
    # Try feather_dir.txt file (legacy fallback)
    elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/feather_dir.txt")
        file(READ "${CMAKE_CURRENT_SOURCE_DIR}/feather_dir.txt" _feather_path)
        string(STRIP "${_feather_path}" _feather_path)
        list(APPEND CMAKE_PREFIX_PATH "${_feather_path}")
    # Try environment variable
    elseif(DEFINED ENV{FEATHER_ROOT})
        list(APPEND CMAKE_PREFIX_PATH "$ENV{FEATHER_ROOT}")
    endif()

    find_package(Feather REQUIRED)
endif()

message(STATUS "Found Feather SDK: ${Feather_VERSION}")
message(STATUS "  Engine directory: ${FEATHER_ENGINE_DIR}")
message(STATUS "  Build directory: ${FEATHER_BUILD_DIR}")

# ---------------------------------------------------------------------------
# Project shared library
# ---------------------------------------------------------------------------
add_library(example SHARED src/project_main.cpp
        src/extension.cpp
        src/defs.h)

target_link_libraries(example PRIVATE Feather::Editor)

# ---------------------------------------------------------------------------
# Output into the project's own bin/<Config> folder.
# The engine searches there by project name when loading the DLL.
# ---------------------------------------------------------------------------
set_target_properties(example PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/bin/$<CONFIG>"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/bin/$<CONFIG>"
)

# Single-config generators: fall back to CMAKE_BUILD_TYPE
if(NOT CMAKE_GENERATOR MATCHES "Visual Studio|Ninja Multi-Config")
    set_target_properties(example PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/bin/${CMAKE_BUILD_TYPE}"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/bin/${CMAKE_BUILD_TYPE}"
    )
endif()
