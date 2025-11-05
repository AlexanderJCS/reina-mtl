#pragma once
#include <Metal/Metal.hpp>
#include <stb/stb_image.h>

class Texture {
public:
    Texture(const char* filepath, MTL::Device* metalDevice);
    Texture(MTL::Device* device, int width, int height, int channels, MTL::PixelFormat pixelFormat);
    ~Texture();
    
    MTL::Texture* texture;
    int width, height, channels;
    
private:
    void init(MTL::Device* device, MTL::PixelFormat pixelFormat);
};
