#pragma once
#include <core/world/ecs_module.h>
#include <world/ecs_defs.h>

#include "TestEcsModule.gen.h"

namespace feather {

class TestEcsModule : public EcsModule {
	FCLASS(EcsModule);

	[[get(protected), set(public)]]
	int foo;

public:
	TestEcsModule(World world);
	~TestEcsModule() override;

	// int get_foo() {return foo;}
	// void set_foo(int val) {foo = val; }
};

} //namespace feather
