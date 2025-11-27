#include "buffers.hpp"

MTL::Buffer* makePrivateBuffer(MTL::Device* device, MTL::CommandQueue* cmdQueue, void* data, uint32_t size) {
    MTL::Buffer* staging = device->newBuffer(data, size, MTL::StorageModeShared);
    MTL::Buffer* dst = device->newBuffer(size, MTL::ResourceStorageModePrivate);
    
    MTL::CommandBuffer* cmdBuffer = cmdQueue->commandBuffer();
    MTL::BlitCommandEncoder* blit = cmdBuffer->blitCommandEncoder();
    blit->copyFromBuffer(staging, 0, dst, 0, size);
    blit->endEncoding();
    cmdBuffer->commit();
    cmdBuffer->waitUntilCompleted();
    
    staging->release();
    
    return dst;
}
