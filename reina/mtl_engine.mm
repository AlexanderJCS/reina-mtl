#include "mtl_engine.hpp"

#include <iostream>

#include "model.hpp"
#include "tri_acc_struct.hpp"
#include "matmath.hpp"


void MTLEngine::init() {
    initDevice();
    initWindow();
    
    createSquare();
    createDefaultLibrary();
    createComputePipeline();
    createCommandQueue();
    createRenderPipeline();
    createAccStruct();
    createViewProjMatrix();
}

void MTLEngine::run() {
    while (!glfwWindowShouldClose(glfwWindow)) {
        @autoreleasepool {
            metalDrawable = (__bridge CA::MetalDrawable*)[metalLayer nextDrawable];
            draw();
        }
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

void MTLEngine::createViewProjMatrix() {
    simd::float4x4 proj = makePerspective(1.57f, 800.0f/600.0f, 0.01f, 1e6);
    simd::float4x4 view = lookAt(simd::float3{0, 0, 0}, simd::float3{0, 0, 1}, simd::float3{0, 1, 0});
    
    simd::float4x4 viewProjBufferContents[] = {
        simd::inverse(view),
        simd::inverse(proj)
    };
    
    viewProjBuffer = metalDevice->newBuffer(&viewProjBufferContents, sizeof(viewProjBufferContents), MTL::ResourceStorageModeShared);
}

void MTLEngine::initWindow() {
    glfwInit();
    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
    glfwWindow = glfwCreateWindow(800, 600, "Metal Engine", NULL, NULL);
    if (!glfwWindow) {
        glfwTerminate();
        exit(EXIT_FAILURE);
    }
    
    int width, height;
    glfwGetFramebufferSize(glfwWindow, &width, &height);
    
    metalWindow = glfwGetCocoaWindow(glfwWindow);
    metalLayer = [CAMetalLayer layer];
    metalLayer.device = (__bridge id<MTLDevice>)metalDevice;
    metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    metalWindow.contentView.layer = metalLayer;
    metalWindow.contentView.wantsLayer = YES;
    metalLayer.drawableSize = CGSizeMake(width, height);
    
}

void MTLEngine::createAccStruct() {
    model = std::make_unique<Model>(metalDevice);
    MTL::CommandBuffer* commandBuffer = metalCommandQueue->commandBuffer();
    accStruct = std::make_unique<TriangleAccelerationStructure>(metalDevice, commandBuffer, *model);
    commandBuffer->commit();
    commandBuffer->waitUntilCompleted();
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

    grassTexture = new Texture("assets/mc_grass.jpeg", metalDevice, MTL::TextureUsageShaderRead | MTL::TextureUsageShaderWrite);
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
    encoder->setComputePipelineState(computePSO);
    encoder->setTexture(grassTexture->texture, 0);
    encoder->setComputePipelineState(computePSO);
    encoder->setAccelerationStructure(accStruct->accelerationStructure, 0);
    encoder->setBuffer(viewProjBuffer, 0, 1);
    encoder->setBuffer(model->getVertexBuffer(), 0, 2);
    encoder->setBuffer(model->getIndexBuffer(), 0, 3);
    MTL::Size gridSize = MTL::Size(grassTexture->width, grassTexture->height, 1);
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
    renderCommandEncoder->setFragmentTexture(grassTexture->texture, 0);
    renderCommandEncoder->drawPrimitives(typeTriangle, vertexStart, vertexCount);
}
