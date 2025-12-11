#include "texture.hpp"
#include <iostream>

Texture::Texture(const char* filepath, MTL::Device* device, MTL::TextureUsage usage) {
    stbi_set_flip_vertically_on_load(true);
    unsigned char* image = stbi_load(filepath, &width, &height, &channels, STBI_rgb_alpha);
    assert(image != NULL);

    init(device, MTL::PixelFormatRGBA8Unorm, usage);

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

Texture::~Texture() {
    texture->release();
    texture = nullptr;
    std::cout << "Releasing texture!\n";
}
