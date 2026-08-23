#pragma once
#include <world/ecs_defs.h>
#include <core/world/ecs_feature.h>

#include "TestEcsModule.gen.h"

namespace feather {

using EcsModule = feather::EcsFeature;

class TestEcsModule : public EcsModule {
	FCLASS();

	[[get(protected), set(public)]]
	int foo;
public:
	TestEcsModule(World world);
	~TestEcsModule() override;

	// int get_foo() {return foo;}
	// void set_foo(int val) {foo = val; }
};

} //namespace feather
