#ifndef tri_acc_struct_hpp
#define tri_acc_struct_hpp

#include <Metal/Metal.hpp>

#include "model.hpp"

class TriangleAccelerationStructure {
public:
    TriangleAccelerationStructure(MTL::Device* device, MTL::CommandBuffer* cmdBuffer, const Model& model);
    
    MTL::AccelerationStructure* accelerationStructure;
    
private:
    void compact();
};

#endif /* tri_acc_struct_hpp */
