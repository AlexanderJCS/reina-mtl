#ifndef tri_acc_struct_hpp
#define tri_acc_struct_hpp

#include <Metal/Metal.hpp>

#include "model.hpp"

class TriangleAccelerationStructure {
public:
    TriangleAccelerationStructure(MTL::Device* device, MTL::CommandQueue* cmdQueue, const Model& model);
    
    [[nodiscard]] MTL::AccelerationStructure* getAccelerationStructure() const;
    
private:
    void compact(MTL::Device* device, MTL::CommandQueue* cmdQueue);
    
    MTL::AccelerationStructure* m_accStruct;
};

#endif /* tri_acc_struct_hpp */
