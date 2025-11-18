#ifndef instance_acc_struct_hpp
#define instance_acc_struct_hpp

#include <Metal/Metal.hpp>

#include <vector>

#include "acc_struct.hpp"

class InstanceAccelerationStructure : public AccelerationStructure {
public:
    InstanceAccelerationStructure(MTL::Device* device, MTL::CommandQueue* cmdQueue, const std::vector<MTL::AccelerationStructure*>& accStructs);
};

#endif /* instance_acc_struct_hpp */
