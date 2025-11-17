#include "instance_acc_struct.hpp"


InstanceAccelerationStructure::InstanceAccelerationStructure(MTL::Device* device, MTL::CommandQueue* cmdQueue, const std::vector<MTL::AccelerationStructure*>& accStructs) {
    
    MTL::CommandBuffer* cmdBuffer = cmdQueue->commandBuffer();
    
    // 1. Create descriptor
    MTL::InstanceAccelerationStructureDescriptor* instanceASDesc =
        MTL::InstanceAccelerationStructureDescriptor::alloc()->init();

    NS::Array* accStructsArray = NS::Array::array(reinterpret_cast<const NS::Object *const*>(accStructs.data()), accStructs.size());

    instanceASDesc->setInstanceCount(accStructs.size());
    instanceASDesc->setInstancedAccelerationStructures(accStructsArray);
    instanceASDesc->setInstanceDescriptorType(MTL::AccelerationStructureInstanceDescriptorTypeDefault);
    
    // 2. Configure instances
    std::vector<MTL::AccelerationStructureInstanceDescriptor> instanceDescriptors(instanceASDesc->instanceCount());
    
    for (int instanceIdx = 0; instanceIdx < instanceASDesc->instanceCount(); instanceIdx++) {
        MTL::AccelerationStructureInstanceDescriptor& desc = instanceDescriptors[instanceIdx];
        
        
        desc.intersectionFunctionTableOffset = 0;
        desc.options = 0;
        
        desc.accelerationStructureIndex = instanceIdx;
        desc.mask = 0xFFFFFFFF;
        
        MTL::PackedFloat4x3 transform;
        transform[0][0] = 1;
        transform[1][1] = 1;
        transform[2][2] = 1;
        
        desc.transformationMatrix = transform;
    }
    

    MTL::Buffer* instanceDescriptorBuffer = device->newBuffer(instanceDescriptors.data(), sizeof(MTL::AccelerationStructureInstanceDescriptor) * instanceDescriptors.size(), MTL::StorageModeShared);
    
    instanceASDesc->setInstanceDescriptorBuffer(instanceDescriptorBuffer);
    
    // 3. Build
    MTL::AccelerationStructureSizes sizes = device->accelerationStructureSizes(instanceASDesc);
    m_accStruct = device->newAccelerationStructure(sizes.accelerationStructureSize);
    
    MTL::Buffer* scratchBuffer = device->newBuffer(sizes.buildScratchBufferSize, MTL::ResourceStorageModePrivate);
    
    MTL::AccelerationStructureCommandEncoder* commandEncoder = cmdBuffer->accelerationStructureCommandEncoder();
    commandEncoder->buildAccelerationStructure(m_accStruct, instanceASDesc, scratchBuffer, 0);
    commandEncoder->endEncoding();
    
    cmdBuffer->commit();
    cmdBuffer->waitUntilCompleted();
}

MTL::AccelerationStructure* InstanceAccelerationStructure::getAccelerationStructure() const {
    return m_accStruct;
}
