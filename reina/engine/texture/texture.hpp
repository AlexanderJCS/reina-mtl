#pragma once
#include <Metal/Metal.hpp>
#include <stb/stb_image.h>

#include <string>

class Texture {
public:
    Texture(const char* filepath, MTL::Device* metalDevice, MTL::TextureUsage usage);
    Texture(MTL::Device* device, int width, int height, int channels, MTL::PixelFormat pixelFormat, MTL::TextureUsage usage);
    ~Texture();
    
    Texture(const Texture&) = delete;
    Texture& operator=(const Texture&) = delete;
    
    MTL::Texture* texture;
    int width, height, channels;
    
private:
    void init(MTL::Device* device, MTL::PixelFormat pixelFormat, MTL::TextureUsage usage);
};
