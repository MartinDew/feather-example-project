#pragma once
#include <core/world/ecs_module.h>

#include "world/ecs_defs.h"

namespace feather {

class TestEcsModule : public EcsModule {
	FCLASS(TestEcsModule, EcsModule);
protected:
	static void _bind_members();

public:
	TestEcsModule(World world);
	~TestEcsModule() override;
};

} //namespace feather
