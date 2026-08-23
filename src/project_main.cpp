#include "defs.h"
#include "TestEcsModule.h"
#include "register_example_types.gen.h"

#include <main/class_db.h>
#include <math/transform.h>
#include <resources/resource_loader.h>
#include <main/world_sim.h>
#include <world/rendering_world_feature.h>
#include <resources/mesh.h>

#include <iostream>
using namespace feather;

void load_sponza_scene() {
	std::shared_ptr<Mesh> sponza = ResourceLoader::get()->load<feather::Mesh>("res://sponza/Sponza.gltf");

	auto* ws = WorldSim::get();
	auto agadou = WorldSim::get()->create_scene("agadou");
	ws->set_active_scene(agadou);
	auto w = WorldSim::get()->get_world();
	auto sponza_e = w->entity<Transform>("sponza").emplace<MeshInstance>(sponza);

	sponza_e.child_of(agadou);
}

extern "C" EXPORT void register_project_types() {
	std::cout << "Hello from example project DLL! This is dynamically loaded by "
				 "the engine."
			  << std::endl;
	// Here we can use ClassDB to register types using engine headers,
	// since the DLL is linked against the engine's import lib.
	register_example_types();

	// std::cout << "Registering TestModule!\n";
	load_sponza_scene();
}
