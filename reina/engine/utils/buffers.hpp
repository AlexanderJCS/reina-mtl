#ifndef buffers_hpp
#define buffers_hpp

#include <Metal/Metal.hpp>

MTL::Buffer* makePrivateBuffer(MTL::Device* device, MTL::CommandQueue* cmdQueue, void* data, uint32_t size);

#endif /* buffers_hpp */
