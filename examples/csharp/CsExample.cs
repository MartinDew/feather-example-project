// A Feather extension written in C#, against C# bindings generated from the
// engine's published API description (api/feather_api.json). Those bindings are
// P/Invoke declarations over libfeather_c, so this file drives the same C entry
// points the C example calls -- just through the generated idiomatic wrappers.
//
// Published with NativeAOT (NativeLib=Shared), so the result is an ordinary
// native shared library exporting the entry point below. The engine dlopens it
// exactly like a C or C++ extension and never learns there is a .NET runtime
// inside.
//
// The engine finds it through cs_example.fext, the manifest next to this file,
// which names that entry point. Without a manifest an extension has to hand
// back a C++ Extension object, which meant constructing one through hand-written
// P/Invoke declarations and getting its ownership right; the manifest removes
// that requirement entirely.

using System;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

internal static class CsExample {

	// The generated [DllImport]s name the library "feather_c" with no path.
	// .NET would turn that into a dlopen of several candidate spellings, and
	// loading a second copy would give this extension its own set of engine
	// globals. The engine has already loaded libfeather_c into the global
	// symbol scope before it loads any extension, so the reliable answer is
	// the main program's handle: a lookup there finds the copy the process
	// already has, without naming a file at all.
	//
	// Resolving explicitly also turns a lookup failure into a readable message
	// instead of an abort: an exception escaping an UnmanagedCallersOnly entry
	// point cannot cross back into C, so the runtime just calls abort().
	[ModuleInitializer]
	internal static void RegisterResolver() {
		NativeLibrary.SetDllImportResolver(typeof(CsExample).Assembly, static (name, assembly, searchPath) => {
			if (name != "feather_c") {
				return IntPtr.Zero;
			}
			// The global scope, which the engine's preload put feather_c into.
			IntPtr main = NativeLibrary.GetMainProgramHandle();
			if (NativeLibrary.TryGetExport(main, "feather_to_string", out _)) {
				return main;
			}
			// Fallback for running outside the engine (a test host, say).
			if (NativeLibrary.TryLoad("libfeather_c.so", out IntPtr handle)) {
				return handle;
			}
			Console.Error.WriteLine("[cs_example] could not resolve libfeather_c");
			return IntPtr.Zero;
		});
	}

	// Mirrors feather::InitLevel, which crosses the boundary as a uint8_t.
	private const byte InitLevelCore = 0;

	[DllImport("feather_c", EntryPoint = "feather_to_string", ExactSpelling = true)]
	private static extern IntPtr InitLevelToString(byte level);

	// The entry point named by cs_example.fext. Called once per initialization
	// level the engine enters, ascending.
	[UnmanagedCallersOnly(EntryPoint = "register_cs_example")]
	public static void Register(byte level) {
		try {
			RegisterCore(level);
		} catch (Exception ex) {
			Console.Error.WriteLine($"[cs_example] register failed: {ex}");
		}
	}

	private static void RegisterCore(byte level) {
		Console.WriteLine($"[cs_example] init level '{Marshal.PtrToStringUTF8(InitLevelToString(level))}' entered");

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
	}
}
