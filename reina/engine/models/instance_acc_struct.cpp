#include "instance_acc_struct.hpp"

#include "matmath.hpp"

InstanceAccelerationStructure::InstanceAccelerationStructure(MTL::Device* device, MTL::CommandQueue* cmdQueue, const std::vector<MTL::AccelerationStructure*>& accStructs, std::vector<simd::float4x4> transforms) {
    
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
        
        desc.transformationMatrix = simdToMTL(transforms[instanceIdx]);
    }
    

    MTL::Buffer* instanceDescriptorBuffer = device->newBuffer(instanceDescriptors.data(), sizeof(MTL::AccelerationStructureInstanceDescriptor) * instanceDescriptors.size(), MTL::StorageModeShared);
    
    instanceASDesc->setInstanceDescriptorBuffer(instanceDescriptorBuffer);
    
    // 3. Build
    build(device, cmdQueue, instanceASDesc);
    compact(device, cmdQueue);
}
