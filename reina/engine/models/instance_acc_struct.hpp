#ifndef instance_acc_struct_hpp
#define instance_acc_struct_hpp

#include <Metal/Metal.hpp>

#include <simd/simd.h>
#include <vector>

#include "acc_struct.hpp"

class InstanceAccelerationStructure : public AccelerationStructure {
public:
    InstanceAccelerationStructure(MTL::Device* device, MTL::CommandQueue* cmdQueue, const std::vector<MTL::AccelerationStructure*>& accStructs, std::vector<simd::float4x4> transforms);
};

#endif /* instance_acc_struct_hpp */
