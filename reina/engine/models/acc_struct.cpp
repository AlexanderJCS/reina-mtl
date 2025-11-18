//
//  acc_struct.cpp
//  reina
//
//  Created by Alex Castronovo on 11/17/25.
//

#include "acc_struct.hpp"

MTL::AccelerationStructure* AccelerationStructure::getAccelerationStructure() const {
    return m_accStruct;
}

void AccelerationStructure::build(MTL::Device* device, MTL::CommandQueue* cmdQueue, MTL::AccelerationStructureDescriptor* accStructDescriptor) {
    
    // Get sizes
    MTL::AccelerationStructureSizes sizes = device->accelerationStructureSizes(accStructDescriptor);
    
    // Make acc struct pointer
    m_accStruct = device->newAccelerationStructure(sizes.accelerationStructureSize);
    
    // Make scratch buffer
    MTL::Buffer* scratchBuffer = device->newBuffer(sizes.buildScratchBufferSize, MTL::ResourceStorageModePrivate);
    
    // Encode build command
    MTL::CommandBuffer* cmdBuffer = cmdQueue->commandBuffer();
    MTL::AccelerationStructureCommandEncoder* commandEncoder = cmdBuffer->accelerationStructureCommandEncoder();
    commandEncoder->buildAccelerationStructure(m_accStruct, accStructDescriptor, scratchBuffer, 0);
    commandEncoder->endEncoding();
    
    cmdBuffer->commit();
    cmdBuffer->waitUntilCompleted();
}

void AccelerationStructure::compact(MTL::Device* device, MTL::CommandQueue* cmdQueue) {
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
