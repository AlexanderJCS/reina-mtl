//
//  tri_acc_struct.cpp
//  reina
//
//  Created by Alex Castronovo on 11/6/25.
//

#include "tri_acc_struct.hpp"

#include <iostream>

TriangleAccelerationStructure::TriangleAccelerationStructure(MTL::Device* device, MTL::CommandQueue* cmdQueue, const Model& model) {
    MTL::CommandBuffer* cmdBuffer = cmdQueue->commandBuffer();
    
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

    m_accStruct = device->newAccelerationStructure(sizes.accelerationStructureSize);
    
    MTL::Buffer* scratchBuffer = device->newBuffer(sizes.buildScratchBufferSize, MTL::ResourceStorageModePrivate);
    
    MTL::AccelerationStructureCommandEncoder* commandEncoder = cmdBuffer->accelerationStructureCommandEncoder();
    commandEncoder->buildAccelerationStructure(m_accStruct, accStructDescriptor, scratchBuffer, 0);
    commandEncoder->endEncoding();
    
    cmdBuffer->commit();
    cmdBuffer->waitUntilCompleted();
    
    compact(device, cmdQueue);
}

MTL::AccelerationStructure* TriangleAccelerationStructure::getAccelerationStructure() const {
    return m_accStruct;
}

void TriangleAccelerationStructure::compact(MTL::Device* device, MTL::CommandQueue* cmdQueue) {
    MTL::CommandBuffer* sizeCmdBuffer = cmdQueue->commandBuffer();
    
    MTL::Buffer* sizeBuffer = device->newBuffer(sizeof(long), MTL::StorageModeShared);
    
    MTL::AccelerationStructureCommandEncoder* sizeEncoder = sizeCmdBuffer->accelerationStructureCommandEncoder();
    sizeEncoder->writeCompactedAccelerationStructureSize(m_accStruct, sizeBuffer, 0);
    
    sizeEncoder->endEncoding();
    sizeCmdBuffer->commit();
    sizeCmdBuffer->waitUntilCompleted();
    
    MTL::CommandBuffer* compactCmdBuffer = cmdQueue->commandBuffer();
    long* compactedSize = reinterpret_cast<long*>(sizeBuffer->contents());
    MTL::AccelerationStructure* compacted = device->newAccelerationStructure(*compactedSize);
    
    MTL::AccelerationStructureCommandEncoder* compactCommandEncoder = compactCmdBuffer->accelerationStructureCommandEncoder();
    
    compactCommandEncoder->copyAndCompactAccelerationStructure(m_accStruct, compacted);
    
    compactCommandEncoder->endEncoding();
    compactCmdBuffer->commit();
    compactCmdBuffer->waitUntilCompleted();
    
    m_accStruct = compacted;
}
