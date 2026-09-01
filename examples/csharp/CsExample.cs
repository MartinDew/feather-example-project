// A Feather extension written in C#, against C# bindings generated from the
// engine's published API description (api/feather_api.json). Those bindings are
// P/Invoke declarations over the C bindings compiled into the engine, so this
// file drives the same C entry points the C example calls -- just through the
// generated idiomatic wrappers.
//
// Published with NativeAOT (NativeLib=Shared), so the result is an ordinary
// native shared library. The engine dlopens it exactly like a C or C++ extension
// and never learns there is a .NET runtime inside.
//
// Note what is *not* here. There is no entry point, no DllImport resolver and no
// dispatch on the init level: the SDK ships those once
// (sdk/csharp/FeatherPluginBootstrap.cs), and finds the code below by reflecting
// over the assembly. cs_example.fext names the SDK's fixed entry point, so there
// is no name to keep in sync either. Compare examples/c/c_example.c, which has
// to export its entry point by hand because C has no way to be found.

using System;
using System.Numerics;
using FeatherPlugin;

internal static class CsExample {

	// Mirrors feather::InitLevel, which crosses the boundary as a uint8_t.
	private const byte InitLevelCore = 0;

	// Called at each init level, ascending -- the same shape the C example's
	// exported entry point gets, without having to export anything.
	[FeatherInit]
	private static void OnInitLevel(byte level) {
		Console.WriteLine($"[cs_example] init level '{InitLevelName(level)}' entered");

		if (level != InitLevelCore) {
			return;
		}

		// From here on everything goes through the generated bindings. The
		// wrapper owns the underlying C++ Projection and frees it on Dispose,
		// which is what the using declarations below are for.
		using var projection = Feather.Projection.CreatePerspectiveFov(60.0f, 16.0f / 9.0f, 0.1f, 1000.0f);

		Console.WriteLine($"[cs_example]   projection type   : {projection.GetType()}");
		Console.WriteLine($"[cs_example]   vertical fov      : {projection.GetFovY():F4} rad");
		Console.WriteLine($"[cs_example]   horizontal fov    : {projection.GetFovX():F4} rad");
		Console.WriteLine($"[cs_example]   aspect ratio      : {projection.GetAspectRatio():F4}");
		Console.WriteLine($"[cs_example]   near / far planes : {projection.GetNearPlane():F2} / {projection.GetFarPlane():F2}");
		Console.WriteLine($"[cs_example]   reverse-Z         : {(projection.IsReverseZ() ? "yes" : "no")}");

		using var reversed = projection.CreateReverseZ();
		Console.WriteLine($"[cs_example]   reverse-Z variant : near {reversed.GetNearPlane():F2}, "
				+ $"far {reversed.GetFarPlane():F2}, reverse-Z {(reversed.IsReverseZ() ? "yes" : "no")}");

		DefineEcsTypes();
	}

	// The generated wrapper for feather::to_string is not usable here: it renders
	// a `const char*` return as `byte?` and hands back only the first byte. The
	// generated enum carries the same names, so ask it instead.
	private static string InitLevelName(byte level) => ((Feather.InitLevel)level).ToString();

	// An ECS component, declared the same way the Python example declares one --
	// a type with fields. It is never instantiated; it describes a layout.
	[FeatherComponent]
	private struct Spin {
		public float Speed;
		public int Ticks;
		public Vector3 Axis;
	}

	// A system over it. Components are named as strings, so this could equally
	// query the engine's own "Transform".
	[FeatherSystem("Spin", Phase = "on_update")]
	private static void Advance(ulong entity, ComponentView[] components, double deltaTime) {
		ComponentView spin = components[0];

		int ticks = spin.GetInt("Ticks");
		if (ticks >= 3) {
			return;
		}

		spin.SetInt("Ticks", ticks + 1);
		spin.SetFloat("Speed", spin.GetFloat("Speed") + 2.5f);

		Vector3 axis = spin.GetVector3("Axis");
		spin.SetVector3("Axis", axis + new Vector3(1.0f, 2.0f, 3.0f));

		Console.WriteLine($"[cs_example] tick {ticks + 1}: speed {spin.GetFloat("Speed"):F1} "
				+ $"axis {spin.GetVector3("Axis")}");
	}

	private static void DefineEcsTypes() {
		// The component and system above were registered by the bootstrap
		// before this ran; what is left is to give the system something to
		// match.
		ulong entity = World.Spawn("SpinDemo", "Spin");
		ComponentView view = World.View(entity, "Spin");

		Console.WriteLine($"[cs_example] spin initial speed {view.GetFloat("Speed"):F1} "
				+ $"ticks {view.GetInt("Ticks")} axis {view.GetVector3("Axis")}");

		view.SetFloat("Speed", 1.0f);
		view.SetVector3("Axis", new Vector3(10.0f, 20.0f, 30.0f));

		Console.WriteLine($"[cs_example] spin seeded speed {view.GetFloat("Speed"):F1} "
				+ $"axis {view.GetVector3("Axis")}");
	}
}
