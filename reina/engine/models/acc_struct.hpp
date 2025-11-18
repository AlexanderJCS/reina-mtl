#ifndef acc_struct_hpp
#define acc_struct_hpp

#include <Metal/Metal.hpp>

class AccelerationStructure { 
public:
    [[nodiscard]] MTL::AccelerationStructure* getAccelerationStructure() const;
    
protected:
    AccelerationStructure() = default;
    
    void build(MTL::Device* device, MTL::CommandQueue* cmdQueue, MTL::AccelerationStructureDescriptor* accStructDescriptor);
    void compact(MTL::Device* device, MTL::CommandQueue* cmdQueue);
    
    MTL::AccelerationStructure* m_accStruct;
};

#endif /* acc_struct_hpp */
