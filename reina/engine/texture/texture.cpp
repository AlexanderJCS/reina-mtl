#include "texture.hpp"

#include <iostream>

#define STB_IMAGE_WRITE_IMPLEMENTATION
#include <stb/stb_image_write.h>

Texture::Texture(const char* filepath, MTL::Device* device, MTL::TextureUsage usage, MTL::PixelFormat format) {
    stbi_set_flip_vertically_on_load(true);
    unsigned char* image = stbi_load(filepath, &width, &height, &channels, STBI_rgb_alpha);
    assert(image != NULL);

    init(device, format, usage);

    MTL::Region region = MTL::Region(0, 0, 0, width, height, 1);
    NS::UInteger bytesPerRow = 4 * width;
    
    texture->replaceRegion(region, 0, image, bytesPerRow);

    stbi_image_free(image);
}

Texture::Texture(MTL::Device* device, int width, int height, int channels, MTL::PixelFormat pixelFormat, MTL::TextureUsage usage)
        : width(width), height(height), channels(channels) {
    init(device, pixelFormat, usage);
}

void Texture::init(MTL::Device* device, MTL::PixelFormat pixelFormat, MTL::TextureUsage usage) {
    MTL::TextureDescriptor* textureDescriptor = MTL::TextureDescriptor::alloc()->init();
    textureDescriptor->setPixelFormat(pixelFormat);
    textureDescriptor->setWidth(width);
    textureDescriptor->setHeight(height);
    textureDescriptor->setUsage(usage);
    
    texture = device->newTexture(textureDescriptor);
    textureDescriptor->release();
}

void Texture::save(MTL::Device* device, MTL::CommandQueue* cmdQueue, const std::string& filename) {
    const uint32_t bytesPerPixel = 4;  // e.g., RGBA8. Doesn't work with other image types.
    const uint32_t bytesPerRow = width * bytesPerPixel;
    const uint32_t dataSize = bytesPerRow * height;
    
    MTL::Buffer* readbackBuffer = device->newBuffer(dataSize, MTL::ResourceStorageModeShared);
    
    MTL::CommandBuffer* cmdBuffer = cmdQueue->commandBuffer();
    MTL::BlitCommandEncoder* encoder = cmdBuffer->blitCommandEncoder();
    
    encoder->copyFromTexture(
        texture,
        0,                      // source slice
        0,                      // source level
        MTL::Origin(0, 0, 0),
        MTL::Size(width, height, 1),
        readbackBuffer,
        0,                      // destination offset
        bytesPerRow,
        dataSize
    );
    
    encoder->endEncoding();
    cmdBuffer->commit();
    cmdBuffer->waitUntilCompleted();
    
    stbi_flip_vertically_on_write(1);
    stbi_write_png(filename.c_str(),
                  width,
                  height,
                  channels,
                  readbackBuffer->contents(),
                  bytesPerRow
                  );
    
    readbackBuffer->release();
}

Texture::~Texture() {
    texture->release();
    texture = nullptr;
}
