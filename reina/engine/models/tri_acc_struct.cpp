#include "tri_acc_struct.hpp"

#include <iostream>

TriangleAccelerationStructure::TriangleAccelerationStructure(MTL::Device* device, MTL::CommandQueue* cmdQueue, const Model& model) {
    
    MTL::AccelerationStructureTriangleGeometryDescriptor* geomDescriptor =
        MTL::AccelerationStructureTriangleGeometryDescriptor::alloc()->init();
    
    geomDescriptor->setVertexBuffer(model.getVertexBuffer());
    geomDescriptor->setVertexStride(sizeof(ModelVertexData));
    geomDescriptor->setVertexBufferOffset(offsetof(ModelVertexData, pos));
    geomDescriptor->setIndexBuffer(model.getIndexBuffer());
    geomDescriptor->setTriangleCount(model.getTriangleCount());
    
    MTL::PrimitiveAccelerationStructureDescriptor* accStructDescriptor = MTL::PrimitiveAccelerationStructureDescriptor::alloc()->init();
    
    NS::Object* geomObjects[] = { geomDescriptor };
    NS::Array* geomArray = NS::Array::array(geomObjects, 1);
    
    accStructDescriptor->setGeometryDescriptors(geomArray);
    
    build(device, cmdQueue, accStructDescriptor);
    compact(device, cmdQueue);
}
