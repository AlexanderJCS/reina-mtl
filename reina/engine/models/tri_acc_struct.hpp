#ifndef tri_acc_struct_hpp
#define tri_acc_struct_hpp

#include <Metal/Metal.hpp>

#include "model.hpp"
#include "acc_struct.hpp"

class TriangleAccelerationStructure : public AccelerationStructure {
public:
    TriangleAccelerationStructure(MTL::Device* device, MTL::CommandQueue* cmdQueue, const Model& model);
};

#endif /* tri_acc_struct_hpp */
