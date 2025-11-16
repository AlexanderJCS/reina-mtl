#ifndef instance_acc_struct_hpp
#define instance_acc_struct_hpp

#include <Metal/Metal.hpp>
#include <vector>

#include "tri_acc_struct.hpp"

class InstanceAccelerationStructure {
public:
    InstanceAccelerationStructure(MTL::Device* device, MTL::CommandQueue* cmdQueue, const std::vector<MTL::AccelerationStructure*>& accStructs);

    MTL::AccelerationStructure* accelerationStructure;
};

#endif /* instance_acc_struct_hpp */
