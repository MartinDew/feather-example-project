// A Feather extension written in C++, against wrappers generated from the
// engine's published API description (api/feather_api.json).
//
// Nothing here includes an engine header, and nothing links the engine. The
// classes below are generated over the same flat C entry points the C example
// calls by hand -- so this shares no C++ ABI with the engine, and needs no
// FeatherEngine checkout to build. What it gains over the C example is
// ownership that manages itself and math types that are the engine's own.

#include <feather_cpp/feather.hpp>
#include <feather_cpp/plugin.hpp>
#include <feather_cpp/scripted_abi.hpp>

#include <cstdio>
#include <string>

namespace
{
    void report_projection()
    {
        // create_perspective_fov takes degrees; the getters below return radians
        // or a ratio, so this doubles as a check that values survive the boundary.
        feather::Projection proj = feather::Projection::create_perspective_fov(60.0f, 16.0f / 9.0f, 0.1f, 1000.0f);

        std::printf("[cpp_example]   projection type   : %s\n",
            proj.get_type() == feather::ProjectionType::Perspective ? "Perspective" : "Orthographic");
        std::printf("[cpp_example]   vertical fov      : %.4f rad\n", proj.get_fov_y());
        std::printf("[cpp_example]   horizontal fov    : %.4f rad\n", proj.get_fov_x());
        std::printf("[cpp_example]   aspect ratio      : %.4f\n", proj.get_aspect_ratio());
        std::printf("[cpp_example]   near / far planes : %.2f / %.2f\n",
            proj.get_near_plane(), proj.get_far_plane());
        std::printf("[cpp_example]   reverse-Z         : %s\n", proj.is_reverse_z() ? "yes" : "no");

        // The C example destroys each returned projection by hand. Here the
        // wrapper owns the heap allocation and releases it at scope exit.
        feather::Projection reversed = proj.create_reverse_z();
        std::printf("[cpp_example]   reverse-Z variant : near %.2f, far %.2f, reverse-Z %s\n",
            reversed.get_near_plane(), reversed.get_far_plane(), reversed.is_reverse_z() ? "yes" : "no");
    }

    // The math types are the engine's own, compiled from the SimpleMath sources
    // the SDK vendors, so they cross the boundary by value rather than as
    // opaque handles.
    void report_transform()
    {
        feather::Transform transform = feather::Transform::create();
        transform.set_position(feather::Vector3(1.0f, 2.0f, 3.0f));
        transform.translate(feather::Vector3(1.0f, 1.0f, 1.0f));

        const feather::Vector3 position = transform.get_position();
        const feather::Vector3 forward = transform.get_forward_vector();
        std::printf("[cpp_example]   position          : (%.4f, %.4f, %.4f)\n",
            position.x, position.y, position.z);
        std::printf("[cpp_example]   forward           : (%.4f, %.4f, %.4f)\n",
            forward.x, forward.y, forward.z);

        // Matrix is the one math type that stays opaque in C -- its base holds
        // an anonymous union -- so it crosses through a pointer and is copied.
        const feather::Matrix matrix = transform.to_matrix_with_scale();
        std::printf("[cpp_example]   matrix translation: (%.4f, %.4f, %.4f)\n",
            matrix._41, matrix._42, matrix._43);
    }

    // A component and a system defined at runtime, through the same flat ABI
    // the C# and Python examples use. Mirrors their Spin/Drift components so
    // the three can be compared against each other.
    void register_ecs()
    {
        const feather::ecs::Field fields[] = {
            {.name = "speed", .type = feather::ecs::FieldType::Float},
            {.name = "ticks", .type = feather::ecs::FieldType::Int},
            {.name = "axis", .type = feather::ecs::FieldType::Vec3},
        };
        feather::ecs::define_component("Whirl", fields);
        std::printf("[cpp_example] component Whirl registered\n");

        const std::string components[] = {"Whirl"};
        feather::ecs::define_system("whirl_advance", components, feather::ecs::Phase::OnUpdate,
            [](const feather::ecs::Invocation &invocation)
            {
                const feather::ecs::ComponentView &whirl = invocation.components[0];
                const std::int32_t ticks = whirl.get_int("ticks") + 1;
                whirl.set("ticks", ticks);
                whirl.set("speed", whirl.get_float("speed") + 2.5f);
                whirl.set("axis", whirl.get_vec3("axis") + feather::Vector3(1.0f, 2.0f, 3.0f));
                std::printf("[cpp_example] tick %d: speed %.1f axis (%.0f, %.0f, %.0f)\n",
                    ticks, whirl.get_float("speed"),
                    whirl.get_vec3("axis").x, whirl.get_vec3("axis").y, whirl.get_vec3("axis").z);
            });
        std::printf("[cpp_example] system whirl_advance registered\n");

        const std::uint64_t entity = feather::ecs::create_entity("WhirlDemo");
        feather::ecs::add_component(entity, "Whirl");

        auto whirl = feather::ecs::view(entity, "Whirl");
        std::printf("[cpp_example] whirl initial speed %.1f ticks %d axis (%.0f, %.0f, %.0f)\n",
            whirl.get_float("speed"), whirl.get_int("ticks"),
            whirl.get_vec3("axis").x, whirl.get_vec3("axis").y, whirl.get_vec3("axis").z);

        whirl.set("speed", 1.0f);
        whirl.set("axis", feather::Vector3(10.0f, 20.0f, 30.0f));
        std::printf("[cpp_example] whirl seeded speed %.1f axis (%.0f, %.0f, %.0f)\n",
            whirl.get_float("speed"),
            whirl.get_vec3("axis").x, whirl.get_vec3("axis").y, whirl.get_vec3("axis").z);
    }

    // Called once per initialization level the engine enters, ascending. There
    // is no matching call on the way out: exit_init_level() unregisters
    // built-in modules only, so an extension sees enter calls and nothing else.
    void on_init_level(feather::InitLevel level)
    {
        std::printf("[cpp_example] init level '%s' entered\n", feather::to_string(level));

        if (level == feather::InitLevel::Core)
        {
            report_projection();
            report_transform();
        }
        else if (level == feather::InitLevel::World)
        {
            // The ECS world does not exist before this level.
            register_ecs();
        }
    }
}

// The entry point named by cpp_example.fext.
FEATHER_PLUGIN_ENTRY(register_cpp_example, on_init_level)
