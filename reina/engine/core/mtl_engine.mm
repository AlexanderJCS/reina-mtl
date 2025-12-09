#include "mtl_engine.hpp"

#include <simd/simd.h>
#include <iostream>
#include <chrono>

#include "buffers.hpp"
#include "model.hpp"
#include "tri_acc_struct.hpp"
#include "matmath.hpp"
#include "scene.hpp"


void MTLEngine::init() {
    initDevice();
    initWindow();
    
    createSquare();
    createDefaultLibrary();
    createAllComputePSOs();
    createCommandQueue();
    createRenderPipeline();
    createAccStructs();
    createBuffers();
}

void MTLEngine::updateBuffers() {
    frameParams.frameIndex++;
    void* contents = frameParamsBuffer->contents();
    memcpy(contents, &frameParams, sizeof(frameParams));
    
    frameParamsBuffer->didModifyRange(
        NS::Range::Make(0, sizeof(FrameParams))
    );
}

void MTLEngine::run() {
    uint32_t samples = 0;
    
    while (!glfwWindowShouldClose(glfwWindow)) {
        samples += frameParams.samplesPerBatch;
        
        @autoreleasepool {
            metalDrawable = (__bridge CA::MetalDrawable*)[metalLayer nextDrawable];
            auto start = std::chrono::steady_clock::now();
            runRaytrace();
            auto end = std::chrono::steady_clock::now();
            tonemap();
            sendRenderCommand();
            
            std::chrono::duration<double> elapsed = end - start;
            std::cout << "Samples: " << samples << " Time: " << elapsed.count() * 1000 << " ms\n";
        }
        
        updateBuffers();
        glfwPollEvents();
    }
}

void MTLEngine::cleanup() {
    glfwTerminate();
    device->release();
}

void MTLEngine::initDevice() {
    device = NS::TransferPtr(MTL::CreateSystemDefaultDevice());
}

void MTLEngine::createBuffers() {
    simd::float4x4 proj = makePerspective(1.57f / 3.0f, float(WIDTH)/float(HEIGHT), 0.01f, 1e6);
    simd::float4x4 view = lookAt(simd::float3{0, 1, -5}, simd::float3{0, 1, 0}, simd::float3{0, 1, 0});
    
    CameraData viewProjBufferContents{
        .invView = simd::inverse(view),
        .invProj = simd::inverse(proj)
    };
    
    viewProjBuffer = NS::TransferPtr(makePrivateBuffer(device.get(), cmdQueue.get(), &viewProjBufferContents, sizeof(CameraData)));
    
    frameParams = FrameParams(0, 64);
    frameParamsBuffer = NS::TransferPtr(device->newBuffer(&frameParams, sizeof(FrameParams), MTL::ResourceStorageModeManaged));
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
    metalLayer.device = (__bridge id<MTLDevice>)device.get();
    metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    metalLayer.drawableSize = CGSizeMake(drawableWidth, drawableHeight);
    metalLayer.displaySyncEnabled = NO;
    metalWindow.contentView.layer = metalLayer;
    metalWindow.contentView.wantsLayer = YES;
}

void MTLEngine::createAccStructs() {
    std::shared_ptr<Model> cornell = std::make_shared<Model>(device.get(), cmdQueue.get(), "assets/cornell_box.obj");
    std::shared_ptr<Model> cornellLight = std::make_shared<Model>(device.get(), cmdQueue.get(), "assets/cornell_light.obj");
    std::shared_ptr<Model> triangle = std::make_shared<Model>(device.get(), cmdQueue.get(), "assets/triangle.obj");
    std::shared_ptr<Model> bunny = std::make_shared<Model>(device.get(), cmdQueue.get(), "assets/bunny.obj");
    std::shared_ptr<Model> ball = std::make_shared<Model>(device.get(), cmdQueue.get(), "assets/uv_sphere_highres.obj");
    childAccStructs = std::vector<std::unique_ptr<TriangleAccelerationStructure>>{};
    
    childAccStructs.push_back(std::make_unique<TriangleAccelerationStructure>(device.get(), cmdQueue.get(), *cornell));
    
    scene = std::make_unique<Scene>();
    std::shared_ptr<Material> red = std::make_shared<Material>(0, simd::float3{0.9f, 0.7f, 0.6f}, simd::float3{0, 0, 0}, 0);
    std::shared_ptr<Material> mirror = std::make_shared<Material>(1, simd::float3(0.9f), simd::float3{0, 0, 0}, 0);
    std::shared_ptr<Material> white = std::make_shared<Material>(0, simd::float3{0.9f, 0.9f, 0.9f}, 0);
    std::shared_ptr<Material> emissive = std::make_shared<Material>(0, simd::float3{0.9f, 0.7f, 0.6f}, simd::float3{10, 10, 10}, 0);
//    scene->addObject(ball, red, matrix_identity_float4x4);
//    scene->addObject(triangle, white, matrix_identity_float4x4);
//    scene->addObject(cornell, white, matrix_identity_float4x4);
    scene->addObject(cornellLight, emissive, matrix_identity_float4x4);
    scene->addObject(ball, mirror, matrix_identity_float4x4);
    
    scene->build(device.get(), cmdQueue.get());
    
    std::vector<MTL::AccelerationStructure*> subStructs;
    for (const std::unique_ptr<TriangleAccelerationStructure>& accStruct : childAccStructs) {
        subStructs.push_back(accStruct->getAccelerationStructure());
    }

    std::vector<simd::float4x4> transforms{
        matrix_identity_float4x4
    };
    
    instanceAccStruct = std::make_unique<InstanceAccelerationStructure>(device.get(), cmdQueue.get(), subStructs, transforms);
}

void MTLEngine::createSquare() {
    FullscreenQuadVertexData squareVertices[] {
        {{-1.0f, -1.0f,  1.0f, 1.0f}, {0.0f, 0.0f}},
        {{-1.0f,  1.0f,  1.0f, 1.0f}, {0.0f, 1.0f}},
        {{ 1.0f,  1.0f,  1.0f, 1.0f}, {1.0f, 1.0f}},
        {{-1.0f, -1.0f,  1.0f, 1.0f}, {0.0f, 0.0f}},
        {{ 1.0f,  1.0f,  1.0f, 1.0f}, {1.0f, 1.0f}},
        {{ 1.0f, -1.0f,  1.0f, 1.0f}, {1.0f, 0.0f}}
    };

    squareVertexBuffer = NS::TransferPtr(device->newBuffer(&squareVertices, sizeof(squareVertices), MTL::ResourceStorageModeShared));

    rtPing = std::make_unique<Texture>(device.get(), drawableWidth, drawableHeight, 4, MTL::PixelFormatRGBA32Float, MTL::TextureUsageShaderRead | MTL::TextureUsageShaderWrite);
    rtPong = std::make_unique<Texture>(device.get(), drawableWidth, drawableHeight, 4, MTL::PixelFormatRGBA32Float, MTL::TextureUsageShaderRead | MTL::TextureUsageShaderWrite);
    
    tonemapped = std::make_unique<Texture>(device.get(), drawableWidth, drawableHeight, 4, MTL::PixelFormatRGBA8Unorm, MTL::TextureUsageShaderRead | MTL::TextureUsageShaderWrite);
}


void MTLEngine::createDefaultLibrary() {
    defaultLib = NS::TransferPtr(device->newDefaultLibrary());
    if(!defaultLib){
        std::cerr << "Failed to load default library.";
        std::exit(-1);
    }
}

void MTLEngine::createCommandQueue() {
    cmdQueue = NS::TransferPtr(device->newCommandQueue());
}

void MTLEngine::createAllComputePSOs() {
    NS::String* raytraceMainName =
        NS::String::alloc()->init("raytraceMain", NS::UTF8StringEncoding);

    NS::String* tonemapMainName =
        NS::String::alloc()->init("tonemapMain", NS::UTF8StringEncoding);

    raytracePSO = NS::TransferPtr(createComputePSO(raytraceMainName));
    tonemapPSO  = NS::TransferPtr(createComputePSO(tonemapMainName));

    raytraceMainName->release();
    tonemapMainName->release();
}

MTL::ComputePipelineState* MTLEngine::createComputePSO(NS::String* kernelName) {
    MTL::Function* computeShader = defaultLib->newFunction(kernelName);
    NS::Error* error = nullptr;
    MTL::ComputePipelineState* pso = device->newComputePipelineState(computeShader, &error);
    if (error) {
        printf("Compute pipeline creation error: %s\n", error->localizedDescription()->utf8String());
    }
    
    computeShader->release();
    
    return pso;
}

void MTLEngine::createRenderPipeline() {
    MTL::Function* vertexShader = defaultLib->newFunction(NS::String::string("vertexShader", NS::ASCIIStringEncoding));
    assert(vertexShader);
    MTL::Function* fragmentShader = defaultLib->newFunction(NS::String::string("fragmentShader", NS::ASCIIStringEncoding));
    assert(fragmentShader);

    MTL::RenderPipelineDescriptor* renderPipelineDescriptor = MTL::RenderPipelineDescriptor::alloc()->init();
    renderPipelineDescriptor->setLabel(NS::String::string("Triangle Rendering Pipeline", NS::ASCIIStringEncoding));
    renderPipelineDescriptor->setVertexFunction(vertexShader);
    renderPipelineDescriptor->setFragmentFunction(fragmentShader);
    assert(renderPipelineDescriptor);
    MTL::PixelFormat pixelFormat = (MTL::PixelFormat)metalLayer.pixelFormat;
    renderPipelineDescriptor->colorAttachments()->object(0)->setPixelFormat(pixelFormat);

    NS::Error* error;
    metalRenderPSO = NS::TransferPtr(device->newRenderPipelineState(renderPipelineDescriptor, &error));

    renderPipelineDescriptor->release();
}

void MTLEngine::runRaytrace() {
    MTL::CommandBuffer* commandBuffer = cmdQueue->commandBuffer();
    MTL::ComputeCommandEncoder* encoder = commandBuffer->computeCommandEncoder();
    
    for (const auto& accStruct : scene->getChildAccStructs()) {
        encoder->useResource(accStruct.getAccelerationStructure(), MTL::ResourceUsageRead);
    }

    encoder->setComputePipelineState(raytracePSO.get());
    encoder->setTexture(rtPing->texture, INPUT_TEXTURE_IDX);
    encoder->setTexture(rtPong->texture, OUTPUT_TEXTURE_IDX);
    encoder->setAccelerationStructure(scene->getInstanceAccStruct().getAccelerationStructure(), ACC_STRUCT_BUFFER_IDX);
    encoder->setBuffer(viewProjBuffer.get(), 0, CAMERA_BUFFER_IDX);
    encoder->setBuffer(scene->getVertexBuffer(), 0, VERTICES_BUFFER_IDX);
    encoder->setBuffer(scene->getIndexBuffer(), 0, INDICES_BUFFER_IDX);
    encoder->setBuffer(frameParamsBuffer.get(), 0, FRAME_PARAMS_BUFFER_IDX);
    encoder->setBuffer(scene->getInstanceDataBuffer(), 0, INSTANCE_DATA_BUFFER_IDX);
    encoder->setBuffer(scene->getMaterialBuffer(), 0, MATERIAL_BUFFER_IDX);
    
    MTL::Size gridSize = MTL::Size(rtPing->width, rtPing->height, 1);
    MTL::Size threadgroupSize = MTL::Size(8, 8, 1);
    encoder->dispatchThreads(gridSize, threadgroupSize);

    encoder->endEncoding();
    commandBuffer->commit();
    commandBuffer->waitUntilCompleted();
    
    std::swap(rtPing, rtPong);
}

void MTLEngine::tonemap() {
    MTL::CommandBuffer* commandBuffer = cmdQueue->commandBuffer();
    MTL::ComputeCommandEncoder* encoder = commandBuffer->computeCommandEncoder();
    
    encoder->setComputePipelineState(tonemapPSO.get());
    encoder->setTexture(rtPong->texture, 0);
    encoder->setTexture(tonemapped->texture, 1);
    
    MTL::Size gridSize = MTL::Size(tonemapped->width, tonemapped->height, 1);
    MTL::Size threadgroupSize = MTL::Size(8, 8, 1);
    encoder->dispatchThreads(gridSize, threadgroupSize);
    
    encoder->endEncoding();
    commandBuffer->commit();
    commandBuffer->waitUntilCompleted();
}

void MTLEngine::sendRenderCommand() {
    MTL::CommandBuffer* cmdBuffer = cmdQueue->commandBuffer();

    MTL::RenderPassDescriptor* renderPassDescriptor = MTL::RenderPassDescriptor::alloc()->init();
    MTL::RenderPassColorAttachmentDescriptor* cd = renderPassDescriptor->colorAttachments()->object(0);
    cd->setTexture(metalDrawable->texture());
    cd->setLoadAction(MTL::LoadActionClear);
    cd->setStoreAction(MTL::StoreActionStore);

    MTL::RenderCommandEncoder* renderCommandEncoder = cmdBuffer->renderCommandEncoder(renderPassDescriptor);
    encodeRenderCommand(renderCommandEncoder);
    renderCommandEncoder->endEncoding();

    cmdBuffer->presentDrawable(metalDrawable);
    cmdBuffer->commit();
    cmdBuffer->waitUntilCompleted();

    renderPassDescriptor->release();
}

void MTLEngine::encodeRenderCommand(MTL::RenderCommandEncoder* renderCommandEncoder) {
    renderCommandEncoder->setRenderPipelineState(metalRenderPSO.get());
    renderCommandEncoder->setVertexBuffer(squareVertexBuffer.get(), 0, 0);
    MTL::PrimitiveType typeTriangle = MTL::PrimitiveTypeTriangle;
    NS::UInteger vertexStart = 0;
    NS::UInteger vertexCount = 6;
    renderCommandEncoder->setFragmentTexture(tonemapped->texture, 0);
    renderCommandEncoder->drawPrimitives(typeTriangle, vertexStart, vertexCount);
}

