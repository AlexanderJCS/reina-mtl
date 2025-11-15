#pragma once

#define GLFW_INCLUDE_NONE
#import <GLFW/glfw3.h>
#define GLFW_EXPOSE_NATIVE_COCOA
#import <GLFW/glfw3native.h>

#include <Metal/Metal.hpp>
#include <Metal/Metal.h>
#include <QuartzCore/CAMetalLayer.hpp>
#include <QuartzCore/CAMetalLayer.h>
#include <QuartzCore/QuartzCore.hpp>
#include <simd/simd.h>

#include <filesystem>

#include <stb/stb_image.h>
#include <simd/simd.h>

#include "texture.hpp"
#include "tri_acc_struct.hpp"
#include "shared.hpp"

#include <Metal/Metal.hpp>

class MTLEngine {
public:
    void init();
    void run();
    void cleanup();
    
    void createBuffers();
    void createAccStruct();
    void createSquare();
    void createDefaultLibrary();
    void createCommandQueue();
    void createRenderPipeline();
    void createComputePipeline();
    void updateBuffers();

    void runRaytrace();
    void encodeRenderCommand(MTL::RenderCommandEncoder* renderEncoder);
    void sendRenderCommand();
    void draw();
    
    static void frameBufferSizeCallback(GLFWwindow *window, int width, int height);
    void resizeFrameBuffer(int width, int height);

private:
    void initDevice();
    void initWindow();

    static constexpr uint WIDTH = 800;
    static constexpr uint HEIGHT = 600;
    int drawableWidth;
    int drawableHeight;
    
    std::unique_ptr<TriangleAccelerationStructure> accStruct;
    MTL::Device* metalDevice;
    GLFWwindow* glfwWindow;
    NSWindow* metalWindow;
    CAMetalLayer* metalLayer;
    CA::MetalDrawable* metalDrawable;
    std::unique_ptr<Model> model;

    MTL::Buffer* viewProjBuffer;
    MTL::ComputePipelineState* computePSO;
    MTL::Library* metalDefaultLibrary;
    MTL::CommandQueue* metalCommandQueue;
    MTL::CommandBuffer* metalCommandBuffer;
    MTL::RenderPipelineState* metalRenderPSO;
    MTL::Buffer* triangleVertexBuffer;
    MTL::Buffer* squareVertexBuffer;
    MTL::Buffer* frameParamsBuffer;
    FrameParams frameParams;

    Texture* rayTracingOutput;
};
