#include "TestEcsModule.h"

#include <main/world_sim.h>
#include <math/transform.h>
#include <resources/mesh.h>
#include <resources/resource_loader.h>
#include <world/rendering_world_feature.h>

namespace feather {

// Runs via _import_module (WorldSim::init(), after index_project()) --
// not register_project_types, where the world isn't set up yet.
TestEcsModule::TestEcsModule(World world) {
	std::shared_ptr<Mesh> sponza = ResourceLoader::get()->load<Mesh>("res://sponza/Sponza.gltf");

	WorldSim* ws = WorldSim::get();
	auto agadou = ws->create_scene("agadou");
	ws->set_active_scene(agadou);
	auto w = ws->get_world();
	auto sponza_e = w->entity<Transform>("sponza").emplace<MeshInstance>(sponza);

	sponza_e.child_of(agadou);
}

TestEcsModule::~TestEcsModule() = default;

} // namespace feather
