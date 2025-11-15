#ifndef instance_acc_struct_hpp
#define instance_acc_struct_hpp

#include <Metal/Metal.hpp>
#include <vector>

#include "tri_acc_struct.hpp"

class InstanceAccelerationStructure {
public:
    InstanceAccelerationStructure(MTL::Device* device, MTL::CommandBuffer* cmdBuf, const std::vector<TriangleAccelerationStructure>& subStructs);

    MTL::AccelerationStructure* accelerationStructure;
};

#endif /* instance_acc_struct_hpp */
