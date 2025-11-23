#include "mtl_engine.hpp"

#include <simd/simd.h>
#include <iostream>

#include "model.hpp"
#include "tri_acc_struct.hpp"
#include "matmath.hpp"
#include "scene.hpp"


void MTLEngine::init() {
    initDevice();
    initWindow();
    
    createSquare();
    createDefaultLibrary();
    createComputePipeline();
    createCommandQueue();
    createRenderPipeline();
    createAccStructs();
    createBuffers();
}

void MTLEngine::updateBuffers() {
    frameParams.frameIndex++;
    void* contents = frameParamsBuffer->contents();
    memcpy(contents, &frameParams, sizeof(frameParams));
}

void MTLEngine::run() {
    while (!glfwWindowShouldClose(glfwWindow)) {
        @autoreleasepool {
            metalDrawable = (__bridge CA::MetalDrawable*)[metalLayer nextDrawable];
            draw();
        }
        
        updateBuffers();
        glfwPollEvents();
    }
}

void MTLEngine::cleanup() {
    glfwTerminate();
    metalDevice->release();
}

void MTLEngine::initDevice() {
    metalDevice = MTL::CreateSystemDefaultDevice();
}

void MTLEngine::createBuffers() {
    simd::float4x4 proj = makePerspective(1.57f / 3.0f, float(WIDTH)/float(HEIGHT), 0.01f, 1e6);
    simd::float4x4 view = lookAt(simd::float3{0, 1, -6}, simd::float3{0, 1.0, 0}, simd::float3{0, 1, 0});
    
    CameraData viewProjBufferContents{
        .invView = simd::inverse(view),
        .invProj = simd::inverse(proj)
    };
    
    viewProjBuffer = metalDevice->newBuffer(&viewProjBufferContents, sizeof(viewProjBufferContents), MTL::ResourceStorageModeShared);
    
    frameParams = FrameParams(0, 64);
    frameParamsBuffer = metalDevice->newBuffer(&frameParams, sizeof(FrameParams), MTL::ResourceStorageModeShared);
}

void MTLEngine::initWindow() {
    glfwInit();
    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
    glfwWindow = glfwCreateWindow(WIDTH, HEIGHT, "Metal Engine", NULL, NULL);
    if (!glfwWindow) {
        glfwTerminate();
        exit(EXIT_FAILURE);
    }

    glfwGetFramebufferSize(glfwWindow, &drawableWidth, &drawableHeight);
    
    metalWindow = glfwGetCocoaWindow(glfwWindow);
    metalLayer = [CAMetalLayer layer];
    metalLayer.device = (__bridge id<MTLDevice>)metalDevice;
    metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    metalLayer.drawableSize = CGSizeMake(drawableWidth, drawableHeight);
    metalLayer.displaySyncEnabled = NO;
    metalWindow.contentView.layer = metalLayer;
    metalWindow.contentView.wantsLayer = YES;
}

void MTLEngine::createAccStructs() {
    Model cornell(metalDevice, "assets/cornell_box.obj");
    Model bunny(metalDevice, "assets/bunny.obj");
    childAccStructs = std::vector<std::unique_ptr<TriangleAccelerationStructure>>{};
    
    childAccStructs.push_back(std::make_unique<TriangleAccelerationStructure>(metalDevice, metalCommandQueue, cornell));
    //    childAccStructs.push_back(std::make_unique<TriangleAccelerationStructure>(metalDevice, metalCommandQueue, *model));
    
    simd::float4x4 transform1 = translate(matrix_identity_float4x4, simd::float3{-1.5, 0, 0});
    simd::float4x4 transform2 = translate(matrix_identity_float4x4, simd::float3{1.5, 0, 0});
    
    scene = std::make_unique<Scene>();
    scene->addObject(Object{std::make_shared<Model>(cornell), transform2});
    scene->addObject(Object{std::make_shared<Model>(cornell), transform1});
    scene->addObject(Object{std::make_shared<Model>(bunny), matrix_identity_float4x4});
    scene->build(metalDevice, metalCommandQueue);
    
    
    std::vector<MTL::AccelerationStructure*> subStructs;
    for (const std::unique_ptr<TriangleAccelerationStructure>& accStruct : childAccStructs) {
        subStructs.push_back(accStruct->getAccelerationStructure());
    }

    std::vector<simd::float4x4> transforms{
        matrix_identity_float4x4
    };
    
    instanceAccStruct = std::make_unique<InstanceAccelerationStructure>(metalDevice, metalCommandQueue, subStructs, transforms);
}

void MTLEngine::createSquare() {
    VertexData squareVertices[] {
        {{-1.0f, -1.0f,  1.0f, 1.0f}, {0.0f, 0.0f}},
        {{-1.0f,  1.0f,  1.0f, 1.0f}, {0.0f, 1.0f}},
        {{ 1.0f,  1.0f,  1.0f, 1.0f}, {1.0f, 1.0f}},
        {{-1.0f, -1.0f,  1.0f, 1.0f}, {0.0f, 0.0f}},
        {{ 1.0f,  1.0f,  1.0f, 1.0f}, {1.0f, 1.0f}},
        {{ 1.0f, -1.0f,  1.0f, 1.0f}, {1.0f, 0.0f}}
    };

    squareVertexBuffer = metalDevice->newBuffer(&squareVertices, sizeof(squareVertices), MTL::ResourceStorageModeShared);

    rayTracingOutput = new Texture(metalDevice, drawableWidth, drawableHeight, 4, MTL::PixelFormatRGBA32Float, MTL::TextureUsageShaderRead | MTL::TextureUsageShaderWrite);
}


void MTLEngine::createDefaultLibrary() {
    metalDefaultLibrary = metalDevice->newDefaultLibrary();
    if(!metalDefaultLibrary){
        std::cerr << "Failed to load default library.";
        std::exit(-1);
    }
}

void MTLEngine::createCommandQueue() {
    metalCommandQueue = metalDevice->newCommandQueue();
}

void MTLEngine::createComputePipeline() {
    MTL::Function* computeShader = metalDefaultLibrary->newFunction(NS::String::string("raytraceMain", NS::ASCIIStringEncoding));
    NS::Error* error = nullptr;
    computePSO = metalDevice->newComputePipelineState(computeShader, &error);
    if (error) {
        printf("Compute pipeline creation error: %s\n", error->localizedDescription()->utf8String());
    }
}

void MTLEngine::createRenderPipeline() {
    MTL::Function* vertexShader = metalDefaultLibrary->newFunction(NS::String::string("vertexShader", NS::ASCIIStringEncoding));
    assert(vertexShader);
    MTL::Function* fragmentShader = metalDefaultLibrary->newFunction(NS::String::string("fragmentShader", NS::ASCIIStringEncoding));
    assert(fragmentShader);

    MTL::RenderPipelineDescriptor* renderPipelineDescriptor = MTL::RenderPipelineDescriptor::alloc()->init();
    renderPipelineDescriptor->setLabel(NS::String::string("Triangle Rendering Pipeline", NS::ASCIIStringEncoding));
    renderPipelineDescriptor->setVertexFunction(vertexShader);
    renderPipelineDescriptor->setFragmentFunction(fragmentShader);
    assert(renderPipelineDescriptor);
    MTL::PixelFormat pixelFormat = (MTL::PixelFormat)metalLayer.pixelFormat;
    renderPipelineDescriptor->colorAttachments()->object(0)->setPixelFormat(pixelFormat);

    NS::Error* error;
    metalRenderPSO = metalDevice->newRenderPipelineState(renderPipelineDescriptor, &error);

    renderPipelineDescriptor->release();
}

void MTLEngine::draw() {
    runRaytrace();
    sendRenderCommand();
}

void MTLEngine::runRaytrace() {
    MTL::CommandBuffer* commandBuffer = metalCommandQueue->commandBuffer();
    MTL::ComputeCommandEncoder* encoder = commandBuffer->computeCommandEncoder();
    
    for (const auto& accStruct : scene->getChildAccStructs()) {
        encoder->useResource(accStruct.getAccelerationStructure(), MTL::ResourceUsageRead);
    }

    encoder->setComputePipelineState(computePSO);
    encoder->setTexture(rayTracingOutput->texture, 0);
    encoder->setAccelerationStructure(scene->getInstanceAccStruct().getAccelerationStructure(), ACC_STRUCT_BUFFER_IDX);
    encoder->setBuffer(viewProjBuffer, 0, CAMERA_BUFFER_IDX);
    encoder->setBuffer(scene->getVertexBuffer(), 0, VERTICES_BUFFER_IDX);
    encoder->setBuffer(scene->getIndexBuffer(), 0, INDICES_BUFFER_IDX);
    encoder->setBuffer(frameParamsBuffer, 0, FRAME_PARAMS_BUFFER_IDX);
    encoder->setBuffer(scene->getInstanceIdxMapBuffer(), 0, INSTANCE_IDX_MAP_BUFFER_IDX);
    
    MTL::Size gridSize = MTL::Size(rayTracingOutput->width, rayTracingOutput->height, 1);
    MTL::Size threadgroupSize = MTL::Size(8, 8, 1);
    encoder->dispatchThreads(gridSize, threadgroupSize);

    encoder->endEncoding();
    commandBuffer->commit();
    commandBuffer->waitUntilCompleted();
}

void MTLEngine::sendRenderCommand() {
    metalCommandBuffer = metalCommandQueue->commandBuffer();

    MTL::RenderPassDescriptor* renderPassDescriptor = MTL::RenderPassDescriptor::alloc()->init();
    MTL::RenderPassColorAttachmentDescriptor* cd = renderPassDescriptor->colorAttachments()->object(0);
    cd->setTexture(metalDrawable->texture());
    cd->setLoadAction(MTL::LoadActionClear);
    cd->setClearColor(MTL::ClearColor(41.0f/255.0f, 42.0f/255.0f, 48.0f/255.0f, 1.0));
    cd->setStoreAction(MTL::StoreActionStore);

    MTL::RenderCommandEncoder* renderCommandEncoder = metalCommandBuffer->renderCommandEncoder(renderPassDescriptor);
    encodeRenderCommand(renderCommandEncoder);
    renderCommandEncoder->endEncoding();

    metalCommandBuffer->presentDrawable(metalDrawable);
    metalCommandBuffer->commit();
    metalCommandBuffer->waitUntilCompleted();

    renderPassDescriptor->release();
}

void MTLEngine::encodeRenderCommand(MTL::RenderCommandEncoder* renderCommandEncoder) {
    renderCommandEncoder->setRenderPipelineState(metalRenderPSO);
    renderCommandEncoder->setVertexBuffer(squareVertexBuffer, 0, 0);
    MTL::PrimitiveType typeTriangle = MTL::PrimitiveTypeTriangle;
    NS::UInteger vertexStart = 0;
    NS::UInteger vertexCount = 6;
    renderCommandEncoder->setFragmentTexture(rayTracingOutput->texture, 0);
    renderCommandEncoder->drawPrimitives(typeTriangle, vertexStart, vertexCount);
}
