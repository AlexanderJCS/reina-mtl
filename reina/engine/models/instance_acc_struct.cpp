#include "instance_acc_struct.hpp"

InstanceAccelerationStructure::InstanceAccelerationStructure(MTL::Device* device, MTL::CommandBuffer* cmdBuf, const std::vector<TriangleAccelerationStructure>& subStructs) {
    
    // 1) instance-AS descriptor object (Objective-C object)
    MTL::InstanceAccelerationStructureDescriptor* instanceASDesc =
        MTL::InstanceAccelerationStructureDescriptor::alloc()->init();

    // 2) collect instanced acceleration structures
    std::vector<MTL::AccelerationStructure*> accStructPtrs;
    accStructPtrs.reserve(subStructs.size());
    for (size_t i = 0; i < subStructs.size(); ++i) {
        accStructPtrs.push_back(subStructs[i].accelerationStructure);
    }
    NS::Array* accStructsArray =
        NS::Array::array(reinterpret_cast<const NS::Object *const*>(accStructPtrs.data()),
                         accStructPtrs.size());

    instanceASDesc->setInstancedAccelerationStructures(accStructsArray);
    instanceASDesc->setInstanceCount((uint32_t)subStructs.size());
    instanceASDesc->setInstanceDescriptorType(MTL::AccelerationStructureInstanceDescriptorTypeUserID);

    // 3) allocate the CPU-side instance descriptor buffer and set it on the descriptor
    using DescType = MTL::AccelerationStructureUserIDInstanceDescriptor;
    size_t descStride = sizeof(DescType);
    size_t instanceDescriptorBufferSize = descStride * subStructs.size();

    // NOTE: you used StorageModeShared earlier; this is convenient for CPU writes.
    MTL::Buffer* instanceDescriptorBuffer =
        device->newBuffer(instanceDescriptorBufferSize, MTL::ResourceStorageModeShared);
    instanceASDesc->setInstanceDescriptorBuffer(instanceDescriptorBuffer);
    instanceASDesc->setInstanceDescriptorStride((uint32_t)descStride);

    // 4) build the per-instance descriptors and write them into the buffer
    std::vector<DescType> instances(subStructs.size());

    for (size_t i = 0; i < subStructs.size(); ++i) {
        DescType &d = instances[i];

        // transform: identity (example). If you want per-instance transforms, compute per i.
        simd::float4x3 transform = simd::float4x3(
            simd::float3{1,0,0},
            simd::float3{0,1,0},
            simd::float3{0,0,1},
            simd::float3{0,0,0}
        );

        // Pack transform into the packed field (API layout uses PackedFloat4x3)
        MTL::PackedFloat4x3 packed;
        for (int c = 0; c < 4; c++)
            for (int r = 0; r < 3; r++)
                packed.columns[c][r] = transform.columns[c][r];

        d.transformationMatrix = packed;

        // index into the instancedAccelerationStructures array you provided above
        d.accelerationStructureIndex = (uint32_t)i;

        // other fields: use defaults or set as needed
        d.mask = 0xFFu;
        d.options = MTL::AccelerationStructureInstanceOptionDisableTriangleCulling;
        d.intersectionFunctionTableOffset = 0;
        d.userID = (uint32_t)i; // optional user ID
    }

    // copy into GPU-visible buffer
    void* dst = instanceDescriptorBuffer->contents();
    memcpy(dst, instances.data(), instanceDescriptorBufferSize);

    // 5) ask the device how much memory we need for the TLAS and for scratch storage
    MTL::AccelerationStructureSizes sizes = device->accelerationStructureSizes(instanceASDesc);

    // 6) allocate TLAS storage and scratch buffer
    accelerationStructure = device->newAccelerationStructure(sizes.accelerationStructureSize);
    // Some metal-cpp versions return an acceleration structure object directly from device->newAccelerationStructure(...)
    // Others expect you to create an AccStructure from a buffer. If your API doesn't have newAccelerationStructure(size),
    // you can store the tlas in a buffer and then create the AccelerationStructure from it — check your metal-cpp version.

    MTL::Buffer* scratchBuffer =
        device->newBuffer(sizes.buildScratchBufferSize, MTL::ResourceStorageModePrivate);

    // 7) record build on AccelerationStructureCommandEncoder
    MTL::AccelerationStructureCommandEncoder* aenc = cmdBuf->accelerationStructureCommandEncoder();
    // The build method signature varies between versions. The common call is:
    //    aenc->buildAccelerationStructure(instanceASDesc, tlas, scratchBuffer, 0);
    //
    // If your metal-cpp uses a different overload, use the one that takes:
    // - an InstanceAccelerationStructureDescriptor*
    // - destination acceleration structure (MTL::AccelerationStructure*)
    // - scratch buffer (MTL::Buffer*)
    // - scratch offset (uint64_t)
    //
    // Example (adjust if your method name is different):
    aenc->buildAccelerationStructure(accelerationStructure, instanceASDesc, scratchBuffer, 0);

    aenc->endEncoding();

    // 8) commit & wait (you already have cmdBuf passed in; caller may prefer to batch — adapt as needed)
    cmdBuf->commit();
    cmdBuf->waitUntilCompleted();
}
