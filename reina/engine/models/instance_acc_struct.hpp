#ifndef instance_acc_struct_hpp
#define instance_acc_struct_hpp

#include <Metal/Metal.hpp>
#include <vector>

#include "tri_acc_struct.hpp"

class InstanceAccelerationStructure {
public:
    InstanceAccelerationStructure(MTL::Device* device, MTL::CommandQueue* cmdQueue, const std::vector<MTL::AccelerationStructure*>& accStructs);

    [[nodiscard]] MTL::AccelerationStructure* getAccelerationStructure() const;
    
private:
    MTL::AccelerationStructure* m_accStruct;
};

#endif /* instance_acc_struct_hpp */
