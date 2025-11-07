//
//  tri_acc_struct.cpp
//  reina
//
//  Created by Alex Castronovo on 11/6/25.
//

#include "tri_acc_struct.hpp"

TriangleAccelerationStructure::TriangleAccelerationStructure(MTL::Device* device, const Model& model) {
    MTL::AccelerationStructureTriangleGeometryDescriptor* geomDescriptor =
        MTL::AccelerationStructureTriangleGeometryDescriptor::alloc()->init();
    
    geomDescriptor->setVertexBuffer(model.getVertexBuffer());
    geomDescriptor->setIndexBuffer(model.getIndexBuffer());
    geomDescriptor->setTriangleCount(model.getTriangleCount());
    
    MTL::PrimitiveAccelerationStructureDescriptor* accStructDescriptor = MTL::PrimitiveAccelerationStructureDescriptor::alloc()->init();
    
    NS::Object* geomObjects[] = { geomDescriptor };
    NS::Array* geomArray = NS::Array::array(geomObjects, 1);
    
    accStructDescriptor->setGeometryDescriptors(geomArray);
    
    MTL::AccelerationStructureSizes sizes = device->accelerationStructureSizes(accStructDescriptor);
    MTL::SizeAndAlign heapSize = device->heapAccelerationStructureSizeAndAlign(sizes.accelerationStructureSize);
    
    MTL::AccelerationStructure accStructure = heap->makeAccelerationStructure(heapSize.size);
    // https://www.youtube.com/watch?v=ZDb7hgF1JGs 8:41
}
