#include "TestEcsModule.h"
//
// // #include <input/inputs.h>
// #include <math/transform.h>
// // #include <world/world.h>
//
// namespace feather {
//     struct Move {};
//
//     void TestEcsModule::_bind_members() {
//         FBIND_MODULE();
//     }
//
//     TestEcsModule::TestEcsModule(World world) {
//         world.component<Move>("Move");
//         world.system<Transform>().with<Move>().kind(flecs::OnUpdate)
//             .each(
//             [](Ecs::iter& it, size_t i, Transform& t) {
//                     Entity e = it.entity(i);
//                     std::cout << "Entity " << e.name() << " has a Move component!" << std::endl;
//
//                     // Do something with the Move component
//                     Input &inp = Input::get();
//                     if (inp.is_key_pressed(Key::W)) {
//                         std::cout << "Entity " << e.name() << " is moving forward!" << std::endl;
//                         t.translate(Vector3(0, 0, -1) * it.delta_system_time());
//                     }
//                     if (inp.is_key_pressed(Key::S)) {
//                         std::cout << "Entity " << e.name() << " is moving backward!" << std::endl;
//                         t.translate(Vector3(0, 0, 1) * it.delta_system_time());
//
//                     }
//                     if (inp.is_key_pressed(Key::D)) {
//                         std::cout << "Entity " << e.name() << " is moving right!" << std::endl;
//                         t.translate(Vector3(1, 0, 0) * it.delta_system_time());
//                     }
//                     if (inp.is_key_pressed(Key::A)) {
//                         std::cout << "Entity " << e.name() << " is moving left!" << std::endl;
//                         t.translate(Vector3(-1, 0, 0) * it.delta_system_time());
//                     }
//             }
//             );
//     }
//
//     TestEcsModule::~TestEcsModule() = default;
// } // feather