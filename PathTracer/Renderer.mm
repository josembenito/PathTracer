/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation for platform independent renderer class
*/

#import <simd/simd.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>

#import "Renderer.h"
#import "Transforms.h"
#import "ShaderTypes.h"
#import "Scene.h"
#import "AAPLImage.h"

#define RENDER_MESH

using namespace simd;

static const NSUInteger maxFramesInFlight = 3;
static const size_t alignedUniformsSize = (sizeof(Uniforms) + 255) & ~255;

static const size_t rayStride = 48;
static const size_t intersectionStride = sizeof(MPSIntersectionDistancePrimitiveIndexCoordinates);
 

@implementation Renderer
{
    MTKView *_view;
    id <MTLDevice> _device;
    id <MTLCommandQueue> _queue;
    id <MTLLibrary> _library;
    
    MPSTriangleAccelerationStructure *_accelerationStructure;
    MPSRayIntersector *_intersector;
    
    id <MTLBuffer> _vertexPositionBuffer;
    id <MTLBuffer> _vertexNormalBuffer;
//    id <MTLBuffer> _vertexColorBuffer;
    id <MTLBuffer> _vertexCoordsBuffer;
    id <MTLBuffer> _rayBuffer;
    id <MTLBuffer> _shadowRayBuffer;
    id <MTLBuffer> _intersectionBuffer;
    id <MTLBuffer> _uniformBuffer;
    id <MTLBuffer> _triangleMaskBuffer;
    id <MTLBuffer> _materialIdsBuffer;
    id <MTLBuffer> _indexBuffer;
    
    
    id <MTLComputePipelineState> _rayPipeline;
    id <MTLComputePipelineState> _shadePipeline;
    id <MTLComputePipelineState> _shadowPipeline;
    id <MTLComputePipelineState> _accumulatePipeline;
    id <MTLRenderPipelineState> _copyPipeline;
    
    id <MTLTexture> _renderTargets[2];
    id <MTLTexture> _accumulationTargets[2];
    id <MTLTexture> _randomTexture;
    NSArray* _colorTexture;
//    id <MTLTexture> _colorTexture[MaterialSize];
    
    dispatch_semaphore_t _sem;
    CGSize _size;
    NSUInteger _uniformBufferOffset;
    NSUInteger _uniformBufferIndex;

    unsigned int _frameIndex;
    
    float _posX,_posY,_posZ;
    float _rotX, _rotY;
    float _lightY;
    vec3 _rootPosition;
    bool _makeFrameDirty;
    Node _rootSceneNode;
    float _scaleValue;
    
    bool _isSceneInitialized;
}

-(nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view;
{
    self = [super init];

    if (self)
    {
        // Metal device was created by platform-specific support code. See iOS/GameViewController.m
        // and macOS/GameViewController.m
        _view = view;
        _device = view.device;
        
        NSLog(@"Metal device: %@", _device.name);

        _sem = dispatch_semaphore_create(maxFramesInFlight);
        
        _lightY = 0.f;
        _rootPosition = vec3(0,0,0);
        _scaleValue = 1.f;
        
//        [self loadMetal];
//        [self createPipelines];
//        [self createScene];
//        [self createBuffers];
//        [self createIntersector];
        
        _posX = 0;
        _posY = 1;
        _posZ = 1.38f;
        
        _rotX = 0; _rotY = 0;
        
        _makeFrameDirty = false;
        
        _isSceneInitialized =false;
        
    }

    return self;
}

- (void)loadMetal
{

    
    // Configure view
    _view.colorPixelFormat = MTLPixelFormatRGBA16Float;
    _view.sampleCount = 1;
    _view.drawableSize = _view.frame.size;

    // Create Metal shader library and command queue. Commands will be executed by GPU from this command queue.
    _library = [_device newDefaultLibrary];
    _queue = [_device newCommandQueue];
}

- (void)createPipelines
{
    NSError *error = NULL;
    
    // Create compute pipelines will will execute code on the GPU
    MTLComputePipelineDescriptor *computeDescriptor = [[MTLComputePipelineDescriptor alloc] init];

    // Set to YES to allow compiler to make certain optimizations
    computeDescriptor.threadGroupSizeIsMultipleOfThreadExecutionWidth = YES;
    
    // Generates rays according to view/projection matrices
    computeDescriptor.computeFunction = [_library newFunctionWithName:@"rayKernel"];
    
    _rayPipeline = [_device newComputePipelineStateWithDescriptor:computeDescriptor
                                                          options:0
                                                       reflection:nil
                                                            error:&error];
    
    if (!_rayPipeline)
        NSLog(@"Failed to create pipeline state: %@", error);
        
    // Consumes ray/scene intersection test results to perform shading
    computeDescriptor.computeFunction = [_library newFunctionWithName:@"shadeKernel"];
    
    _shadePipeline = [_device newComputePipelineStateWithDescriptor:computeDescriptor
                                                          options:0
                                                       reflection:nil
                                                            error:&error];
    
    if (!_shadePipeline)
        NSLog(@"Failed to create pipeline state: %@", error);
    
    // Consumes shadow ray intersection tests to update the output image
    computeDescriptor.computeFunction = [_library newFunctionWithName:@"shadowKernel"];
    
    _shadowPipeline = [_device newComputePipelineStateWithDescriptor:computeDescriptor
                                                             options:0
                                                          reflection:nil
                                                               error:&error];
    
    if (!_shadowPipeline)
        NSLog(@"Failed to create pipeline state: %@", error);

    // Averages the current frame's output image with all previous frames
    computeDescriptor.computeFunction = [_library newFunctionWithName:@"accumulateKernel"];
    
    _accumulatePipeline = [_device newComputePipelineStateWithDescriptor:computeDescriptor
                                                                 options:0
                                                              reflection:nil
                                                                   error:&error];
    
    if (!_accumulatePipeline)
        NSLog(@"Failed to create pipeline state: %@", error);

    // Copies rendered scene into the MTKView
    MTLRenderPipelineDescriptor *renderDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    renderDescriptor.sampleCount = _view.sampleCount;
    renderDescriptor.vertexFunction = [_library newFunctionWithName:@"copyVertex"];
    renderDescriptor.fragmentFunction = [_library newFunctionWithName:@"copyFragment"];
    renderDescriptor.colorAttachments[0].pixelFormat = _view.colorPixelFormat;

    _copyPipeline = [_device newRenderPipelineStateWithDescriptor:renderDescriptor error:&error];
    
    if (!_copyPipeline)
        NSLog(@"Failed to create pipeline state, error %@", error);
}

- (void)createSceneFromUrl:(NSURL*) fileUrl
{
    [self loadMetal];
    [self createPipelines];

    _scaleValue = 0.01f;
    _lightY = 2.5f;
    _rootPosition = vec3(0.0f, 2.6, 0.0f);
    
    loadMeshFromUrl((__bridge CFURLRef) fileUrl);
    
    // Light source
    float4x4 transform = matrix4x4_translation(0.0f, 1.0f, 0.0f) * matrix4x4_scale(0.5f, _lightY, 0.5f);
    createCube(FACE_MASK_POSITIVE_Y, vector3(1.0f, 1.0f, 1.0f), transform, true, TRIANGLE_MASK_LIGHT, ImageMaterial);
    
    [self createBuffers];
    [self createIntersector];
    
    _isSceneInitialized =true;
}

- (void)createScene
{
    _lightY = 1.95f;
#ifdef RENDER_MESH
//    _scaleValue = 0.25f;
//    loadMesh("Cube","gltf");
    _scaleValue = 0.0001f;
    

    _lightY = 2.5f;
    _rootPosition = vec3(0.0f, 2.6, 0.0f);
    loadMeshFromBundle("scene","gltf");

#endif
    
    
    float4x4 transform = matrix4x4_translation(0.0f, 1.0f, 0.0f) * matrix4x4_scale(0.5f, _lightY, 0.5f);
    
    // Light source
    createCube(FACE_MASK_POSITIVE_Y, vector3(1.0f, 1.0f, 1.0f), transform, true, TRIANGLE_MASK_LIGHT, ImageMaterial);
    
     transform = matrix4x4_translation(0.0f, 1.0f, 0.0f) * matrix4x4_scale(2.f, 2.f, 2.f);
       // Top, bottom, and back walls
//    createCube(FACE_MASK_NEGATIVE_Y | FACE_MASK_POSITIVE_Y | FACE_MASK_NEGATIVE_Z, vector3(0.725f, 0.71f, 0.68f), transform, true, TRIANGLE_MASK_GEOMETRY, ConcreteMaterial);

    // Left wall
//    createCube(FACE_MASK_NEGATIVE_X, vector3(0.63f, 0.065f, 0.05f), transform, true, TRIANGLE_MASK_GEOMETRY, RedConcreteMaterial);

    // Right wall
//    createCube(FACE_MASK_POSITIVE_X, vector3(0.14f, 0.45f, 0.091f), transform, true, TRIANGLE_MASK_GEOMETRY, GreenConcreteMaterial);
				
//    transform = matrix4x4_translation(-0.335f, 0.6f, -0.29f) * matrix4x4_rotation(0.3f, vector3(0.0f, 1.0f, 0.0f)) * matrix4x4_scale(0.6f, 1.2f, 0.6f);

    // Tall box
//    createCube(FACE_MASK_ALL, vector3(0.725f, 0.71f, 0.68f), transform, false, TRIANGLE_MASK_GEOMETRY, PlywoodMaterial);

//    transform = matrix4x4_translation(0.3275f, 0.3f, 0.3725f) * matrix4x4_rotation(-0.3f, vector3(0.0f, 1.0f, 0.0f)) * matrix4x4_scale(0.6f, 0.6f, 0.6f);

    // Short box
//    createCube(FACE_MASK_ALL, vector3(0.725f, 0.71f, 0.68f), transform, false, TRIANGLE_MASK_GEOMETRY, PlywoodMaterial);

    
    
}

- (void)createBuffers
{
    // Uniform buffer contains a few small values which change from frame to frame. We will have up to 3
    // frames in flight at once, so allocate a range of the buffer for each frame. The GPU will read from
    // one chunk while the CPU writes to the next chunk. Each chunk must be aligned to 256 bytes on macOS
    // and 16 bytes on iOS.
    NSUInteger uniformBufferSize = alignedUniformsSize * maxFramesInFlight;
    
    // Vertex data should be stored in private or managed buffers on discrete GPU systems (AMD, NVIDIA).
    // Private buffers are stored entirely in GPU memory and cannot be accessed by the CPU. Managed
    // buffers maintain a copy in CPU memory and a copy in GPU memory.
    MTLResourceOptions options = 0;

#if !TARGET_OS_IPHONE
    options = MTLResourceStorageModeManaged;
#else
    options = MTLResourceStorageModeShared;
#endif
    
    _uniformBuffer = [_device newBufferWithLength:uniformBufferSize options:options];

#ifdef RENDER_MESH


    size_t meshesVertexSize = 0;
    for (int i=0;i<meshgroup.meshes.size();++i) {
        meshesVertexSize +=meshgroup.meshes[i].vertex_count;
    }
    {
        size_t size = vertices.size() + meshesVertexSize;
        _vertexPositionBuffer = [_device newBufferWithLength:size * sizeof(float3) options:options];
    }
//    {
        
//        size_t size = colors.size() + meshVertexSize;
//        _vertexColorBuffer = [_device newBufferWithLength:size * sizeof(float3) options:options];
//    }
    {
        size_t size = normals.size() + meshesVertexSize;
        _vertexNormalBuffer = [_device newBufferWithLength:size * sizeof(float3) options:options];
    }
    {
        size_t size = uvs.size() + meshesVertexSize;
        _vertexCoordsBuffer = [_device newBufferWithLength:size * sizeof(float2) options:options];
    }
    size_t meshIndexSize = 0;
    for (int i=0;i<meshgroup.meshes.size();++i) {
        meshIndexSize +=meshgroup.meshes[i].index_count;
    }
    {
        size_t size = indices.size() + meshIndexSize;
        _indexBuffer = [_device newBufferWithLength:size * sizeof(uint32_t) options:options];
    }
    // resize mask and material for mesh triangles
    size_t meshTriangleSize = meshIndexSize/3;
    {
        size_t size = masks.size() + meshTriangleSize;
        _triangleMaskBuffer = [_device newBufferWithLength:size * sizeof(uint32_t) options:options];
    }
    {
        size_t size = materials.size() + meshTriangleSize;
        _materialIdsBuffer = [_device newBufferWithLength:size* sizeof(uint32_t) options:options];
    }

    // transform vertices and normals to their world position
    
    
    _rootSceneNode.init();
    _rootSceneNode.addChild(meshgroup.nodes[0]);
    
    _rootSceneNode.scale = vec3(_scaleValue, _scaleValue, _scaleValue);
    _rootSceneNode.position = _rootPosition;
    _rootSceneNode.rotation = quat_from_axis_deg(45, 0, 1, 0);

    _rootSceneNode.updateHierarchy();
    
    auto inplaceTransformVector3 = [](mat4 A, float* src, size_t count) {
        for (int i=0;i<count;++i) {
            vec4 x(src[0],src[1],src[2],1.f);
//            print(x);
            vec4 b = A*x;
//            print(b);
            src[0]=b.x;
            src[1]=b.y;
            src[2]=b.z;
            src += 3;
        }
    };
    for (int i=0;i<meshgroup.meshes.size();++i) {
        inplaceTransformVector3((*meshgroup.meshes[i].node).worldMatrix, meshgroup.meshes[i].vp, meshgroup.meshes[i].vertex_count);
    }
    for (int i=0;i<meshgroup.meshes.size();++i) {
        inplaceTransformVector3(transpose((*meshgroup.meshes[i].node).worldInverseMatrix), meshgroup.meshes[i].vn, meshgroup.meshes[i].vertex_count);
    }

    // Copy vertex data into buffers
    auto copyToFloat3Buffer = [](float3* dest, float* src, size_t count) {
        for (int i=0;i<count;++i) {
            *dest = vector3(src[0],src[1],src[2]);
            ++dest;
            src += 3;
        }
    };

    // Copy vertex data into buffers

    {
        float3* bufferOffset = (float3*)_vertexPositionBuffer.contents;
        memcpy(bufferOffset, &vertices[0], vertices.size() * sizeof(float3));
        bufferOffset+=vertices.size();
        for (int i=0;i<meshgroup.meshes.size();++i) {
            copyToFloat3Buffer(bufferOffset, meshgroup.meshes[i].vp, meshgroup.meshes[i].vertex_count);
            bufferOffset+=meshgroup.meshes[i].vertex_count;
        }
    }
    
//    {
//        float3* bufferOffset = (float3*)_vertexColorBuffer.contents;
//        memcpy(bufferOffset, &colors[0], colors.size() * sizeof(float3));
//        bufferOffset+=colors.size();
//        for (int i=0;i<meshgroup.meshes.size();++i) {
//            copyToFloat3Buffer(bufferOffset, meshgroup.meshes[i].vc, meshgroup.meshes[i].vertex_count);
//            bufferOffset+=meshVertexSize;
//        }
//    }
    

    {
        float3* bufferOffset = (float3*)_vertexNormalBuffer.contents;
        memcpy(bufferOffset, &normals[0], normals.size() * sizeof(float3));
        bufferOffset+=normals.size();
        for (int i=0;i<meshgroup.meshes.size();++i) {
            copyToFloat3Buffer(bufferOffset, meshgroup.meshes[i].vn, meshgroup.meshes[i].vertex_count);
            bufferOffset+=meshgroup.meshes[i].vertex_count;
        }
    }
    auto copyToFloat2Buffer = [](float2* dest, float* src, size_t count) {
        for (int i=0;i<count;++i) {
            *dest = vector2(src[0],src[1]);
            ++dest;
            src += 2;
        }
    };
    {
        float2* bufferOffset = (float2*)_vertexCoordsBuffer.contents;
        memcpy(bufferOffset, &uvs[0], uvs.size() * sizeof(float2));
        bufferOffset+=uvs.size();
        for (int i=0;i<meshgroup.meshes.size();++i) {
            copyToFloat2Buffer(bufferOffset, meshgroup.meshes[i].uvs[0], meshgroup.meshes[i].vertex_count);
            bufferOffset+=meshgroup.meshes[i].vertex_count;
        }
    }
    auto copyToUint32Buffer = [](uint32_t* dest, unsigned* src, size_t indexOffset, size_t count) {
        for (int i=0;i<count;++i) {
            *dest = uint32_t(src[0]+indexOffset);
            ++dest;
            ++src;
        }
    };
    {
        uint32_t* bufferOffset = (uint32_t*)_indexBuffer.contents;
        memcpy(bufferOffset, &indices[0], indices.size() * sizeof(uint32_t));
        bufferOffset+=indices.size();
        size_t indexOffset = vertices.size();
        for (int i=0;i<meshgroup.meshes.size();++i) {
            copyToUint32Buffer(bufferOffset, meshgroup.meshes[i].faces_indices, indexOffset, meshgroup.meshes[i].index_count);
            bufferOffset+=meshgroup.meshes[i].index_count;
            indexOffset+=meshgroup.meshes[i].vertex_count;
        }
    }
    {
        uint32_t* bufferOffset = (uint32_t*)_triangleMaskBuffer.contents;
        memcpy(bufferOffset, &masks[0], masks.size() * sizeof(uint32_t));
        bufferOffset+=masks.size();
        for (int i=0;i<meshgroup.meshes.size();++i) {
            size_t meshTriangleSize = meshgroup.meshes[i].index_count/3;
            for (int i=0; i < meshTriangleSize; ++i) {
                *bufferOffset = TRIANGLE_MASK_GEOMETRY;
                ++bufferOffset;
            }
        }

    }
    {
        uint32_t* bufferOffset = (uint32_t*)_materialIdsBuffer.contents;
        memcpy(bufferOffset, &materials[0], materials.size() * sizeof(uint32_t));
        bufferOffset+=materials.size();
        for (int i=0;i<meshgroup.meshes.size();++i) {
            size_t meshTriangleSize = meshgroup.meshes[i].index_count/3;
            for (int j=0; j < meshTriangleSize; ++j) {
                *bufferOffset = MaterialSize+i;;
                ++bufferOffset;
            }
        }
    }
    // debug
//    {
//        printf("vertex\n");
//        float3* kk = (float3*)_vertexPositionBuffer.contents;
//        for (int i=0;i<_vertexPositionBuffer.length/sizeof(float3); i++) {
//            printf("%d:[%0.3f,%0.3f,%0.3f]\n", i, kk[i].x, kk[i].y, kk[i].z );
//        }
//    }
//    {
//        printf("normals\n");
//        float3* kk = (float3*)_vertexNormalBuffer.contents;
//        for (int i=0;i<_vertexNormalBuffer.length/sizeof(float3); i++) {
//            printf("%d:[%0.3f,%0.3f,%0.3f]\n", i, kk[i].x, kk[i].y, kk[i].z );
//        }
//    }
//    {
//        printf("uvs\n");
//        float2* kk = (float2*)_vertexCoordsBuffer.contents;
//        for (int i=0;i<_vertexCoordsBuffer.length/sizeof(float2); i++) {
//            printf("%d:[%0.3f,%0.3f]\n", i, kk[i].x, kk[i].y );
//        }
//    }
//    {
//        printf("idx\n");
//        uint32_t* kk = (uint32_t*)_indexBuffer.contents;
//        for (int i=0;i<_indexBuffer.length/(3*sizeof(uint32_t)); i++) {
//            printf("%d:[%d %d %d]\n", i, kk[i*3],kk[i*3+1],kk[i*3+2]);
//        }
//    }
//    {
//        printf("\nmaterials\n");
//        uint32_t* kk = (uint32_t*)_materialIdsBuffer.contents;
//        for (int i=0;i<_materialIdsBuffer.length/sizeof(uint32_t); i++) {
//            printf("%d:%d ", i, kk[i]);
//        }
//    }
//    {
//        printf("\nmasks\n");
//        uint32_t* kk = (uint32_t*)_triangleMaskBuffer.contents;
//        for (int i=0;i<_triangleMaskBuffer.length/sizeof(uint32_t); i++) {
//            printf("%d:%d ", i, kk[i]);
//        }
//    }

#endif
    // When using managed buffers, we need to indicate that we modified the buffer so that the GPU
    // copy can be updated
#if !TARGET_OS_IPHONE
    [_vertexPositionBuffer didModifyRange:NSMakeRange(0, _vertexPositionBuffer.length)];
    //[_vertexColorBuffer didModifyRange:NSMakeRange(0, _vertexColorBuffer.length)];
    [_vertexNormalBuffer didModifyRange:NSMakeRange(0, _vertexNormalBuffer.length)];
    [_vertexCoordsBuffer didModifyRange:NSMakeRange(0, _vertexCoordsBuffer.length)];
    [_triangleMaskBuffer didModifyRange:NSMakeRange(0, _triangleMaskBuffer.length)];
    [_materialIdsBuffer didModifyRange:NSMakeRange(0, _materialIdsBuffer.length)];
    [_indexBuffer didModifyRange:NSMakeRange(0, _indexBuffer.length)];
#endif
    
    
    NSURL *imageFileLocation = nullptr;
//    ImageMaterial,
//    ConcreteMaterial,
//    RedConcreteMaterial,
//    GreenConcreteMaterial,
//    PlywoodMaterial,
    NSArray* textureFileNames = [[NSArray alloc] initWithObjects:@"image",@"concrete",@"redConcrete",@"greenConcrete", @"osb", nil];
    assert(textureFileNames.count >= MaterialSize);
    
    NSMutableArray* textures = [NSMutableArray array];
    for (NSUInteger i = 0; i < MaterialSize; ++i) {
        imageFileLocation= [[NSBundle mainBundle] URLForResource:textureFileNames[i] withExtension:@"tga"];
        [textures addObject:[self createAndLoadTextureUsingAAPLImage: imageFileLocation]];
    }
    
    assert (MaterialSize + meshgroup.meshes.size() < MaxMaterialSize);
    for (int i=0;i<meshgroup.meshes.size();++i) {
        [textures addObject:[self createAndLoadTextureUsingTexture:meshgroup.meshes[i].diffuse]];
    }
    _colorTexture = [textures copy];
    _frameIndex = 0;
}

- (void)createIntersector
{
    // Create a raytracer for our Metal device
    _intersector = [[MPSRayIntersector alloc] initWithDevice:_device];
    
    _intersector.rayDataType = MPSRayDataTypeOriginMaskDirectionMaxDistance;
    _intersector.rayStride = rayStride;
    _intersector.rayMaskOptions = MPSRayMaskOptionPrimitive;
//    _intersector.cullMode = MTLCullModeBack;
    
    // Create an acceleration structure from our vertex position data
    _accelerationStructure = [[MPSTriangleAccelerationStructure alloc] initWithDevice:_device];
    
    _accelerationStructure.vertexBuffer = _vertexPositionBuffer;

    _accelerationStructure.indexBuffer =_indexBuffer;
    _accelerationStructure.maskBuffer = _triangleMaskBuffer;
#ifdef RENDER_MESH
    size_t meshIndexSize = 0;
    for (int i=0;i<meshgroup.meshes.size();++i) {
        meshIndexSize +=meshgroup.meshes[i].index_count;
    }

    size_t triangleSize = indices.size()/3 + meshIndexSize/3;
    _accelerationStructure.triangleCount = triangleSize;
#else
    _accelerationStructure.triangleCount = indices.size() / 3;
    
#endif
    
    [_accelerationStructure rebuild];
}


- (id<MTLTexture>)createAndLoadTextureUsingAAPLImage: (NSURL *) url {
    
    AAPLImage * image = [[AAPLImage alloc] initWithTGAFileAtLocation:url];
    
    NSAssert(image, @"Failed to create the image from %@", url.absoluteString);

    MTLTextureDescriptor *textureDescriptor = [[MTLTextureDescriptor alloc] init];
    
    // Indicate that each pixel has a blue, green, red, and alpha channel, where each channel is
    // an 8-bit unsigned normalized value (i.e. 0 maps to 0.0 and 255 maps to 1.0)
    textureDescriptor.pixelFormat = MTLPixelFormatBGRA8Unorm;
    
    // Set the pixel dimensions of the texture
    textureDescriptor.width = image.width;
    textureDescriptor.height = image.height;
    
    // Create the texture from the device by using the descriptor
    id<MTLTexture> texture = [_device newTextureWithDescriptor:textureDescriptor];
    
    // Calculate the number of bytes per row in the image.
    NSUInteger bytesPerRow = 4 * image.width;
    
    MTLRegion region = {
        { 0, 0, 0 },                   // MTLOrigin
        {image.width, image.height, 1} // MTLSize
    };
    
    // Copy the bytes from the data object into the texture
    [texture replaceRegion:region mipmapLevel:0 withBytes:image.data.bytes bytesPerRow:bytesPerRow];
    return texture;
}

- (id<MTLTexture>)createAndLoadTextureUsingTexture: (Meshgroup::Texture&) texture {
    assert (texture.n == 4);
    MTLTextureDescriptor *textureDescriptor = [[MTLTextureDescriptor alloc] init];
    textureDescriptor.pixelFormat = MTLPixelFormatRGBA8Unorm;
    textureDescriptor.width = texture.x;
    textureDescriptor.height = texture.y;
    
    id<MTLTexture> ret = [_device newTextureWithDescriptor:textureDescriptor];
    MTLRegion region = { { 0, 0, 0 }, {(NSUInteger)texture.x, (NSUInteger)texture.y, 1} };
    [ret replaceRegion:region mipmapLevel:0 withBytes:texture.image_data bytesPerRow:texture.n * texture.x];
    return ret;
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    _size = size;
    
    // Handle window size changes by allocating a buffer large enough to contain one standard ray,
    // one shadow ray, and one ray/triangle intersection result per pixel
    NSUInteger rayCount = (NSUInteger)_size.width * (NSUInteger)_size.height;
    
    // We use private buffers here because rays and intersection results will be entirely produced
    // and consumed on the GPU
    _rayBuffer = [_device newBufferWithLength:rayStride * rayCount options:MTLResourceStorageModePrivate];
    _shadowRayBuffer = [_device newBufferWithLength:rayStride * rayCount options:MTLResourceStorageModePrivate];
    _intersectionBuffer = [_device newBufferWithLength:intersectionStride * rayCount options:MTLResourceStorageModePrivate];
    
    // Create a render target which the shading kernel can write to
    MTLTextureDescriptor *renderTargetDescriptor = [[MTLTextureDescriptor alloc] init];
    
    renderTargetDescriptor.pixelFormat = MTLPixelFormatRGBA32Float;
    renderTargetDescriptor.textureType = MTLTextureType2D;
    renderTargetDescriptor.width = size.width;
    renderTargetDescriptor.height = size.height;

    // Stored in private memory because it will only be read and written from the GPU
    renderTargetDescriptor.storageMode = MTLStorageModePrivate;

    // Indicate that we will read and write the texture from the GPU
    renderTargetDescriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    
    for (NSUInteger i = 0; i < 2; i++) {
        _renderTargets[i] = [_device newTextureWithDescriptor:renderTargetDescriptor];
        _accumulationTargets[i] = [_device newTextureWithDescriptor:renderTargetDescriptor];
    }
    
    renderTargetDescriptor.pixelFormat = MTLPixelFormatR32Uint;
    renderTargetDescriptor.usage = MTLTextureUsageShaderRead;
#if !TARGET_OS_IPHONE
    renderTargetDescriptor.storageMode = MTLStorageModeManaged;
#else
    renderTargetDescriptor.storageMode = MTLStorageModeShared;
#endif
    
    // Generate a texture containing a random integer value for each pixel. This value
    // will be used to decorrelate pixels while drawing pseudorandom numbers from the
    // Halton sequence.
    _randomTexture = [_device newTextureWithDescriptor:renderTargetDescriptor];
    
    uint32_t *randomValues = (uint32_t *)malloc(sizeof(uint32_t) * size.width * size.height);
    
    for (NSUInteger i = 0; i < size.width * size.height; i++)
        randomValues[i] = rand() % (1024 * 1024);
    
    [_randomTexture replaceRegion:MTLRegionMake2D(0, 0, size.width, size.height)
                      mipmapLevel:0
                        withBytes:randomValues
                      bytesPerRow:sizeof(uint32_t) * size.width];
    
    free(randomValues);

}

- (void)updateUniforms {
    auto transformVector = [](const matrix_float4x4& A, const float3& vector)
    {
        float3 v = vector;
        float4 v4 = vector4(v.x, v.y, v.z, 1.0f);
        float4 vt = A * v4;
        return vector3(vt.x,vt.y,vt.z);
    };

    // Update this frame's uniforms
    _uniformBufferOffset = alignedUniformsSize * _uniformBufferIndex;

    Uniforms *uniforms = (Uniforms *)((char *)_uniformBuffer.contents + _uniformBufferOffset);

    uniforms->camera.position = vector3(_posX, _posY, _posZ);

//    uniforms->camera.forward = vector3(0.0f, 0.0f, -1.0f);
//    uniforms->camera.right = vector3(1.0f, 0.0f, 0.0f);
//    uniforms->camera.up = vector3(0.0f, 1.0f, 0.0f);

    matrix_float4x4 cameraRotation = matrix4x4_rotation(_rotY, vector3(0.0f, 1.0f, 0.0f))*matrix4x4_rotation(_rotX, vector3(1.0f, 0.0f, 0.0f));
    
    uniforms->camera.forward = transformVector(cameraRotation, vector3(0.0f, 0.0f,-1.0f));
    uniforms->camera.right = transformVector(cameraRotation, vector3(1.0f, 0.0f,0.0f));
    uniforms->camera.up = transformVector(cameraRotation, vector3(0.0f, 1.0f,0.0f));
    
    uniforms->light.position = vector3(0.0f, _lightY, 0.0f);
    uniforms->light.forward = vector3(0.0f, -1.0f, 0.0f);
    uniforms->light.right = vector3(1.f, 0.0f, 0.0f);
    uniforms->light.up = vector3(0.0f, 0.0f, 1.f);

//    uniforms->light.right = vector3(0.25f, 0.0f, 0.0f);
//    uniforms->light.up = vector3(0.0f, 0.0f, 0.25f);
    uniforms->light.color = vector3(4.0f, 4.0f, 4.0f);
    // frame index is used in the accumulation phase to decide what to mix from previous
    // setting it to 0 will give all weight to new color so that it effectively "clears" the accumulation buffer
    _frameIndex = _makeFrameDirty? 0:_frameIndex;
    _makeFrameDirty = false;
    
    float fieldOfView = 45.0f * (M_PI / 180.0f);
    float aspectRatio = (float)_size.width / (float)_size.height;
    float imagePlaneHeight = tanf(fieldOfView / 2.0f);
    float imagePlaneWidth = aspectRatio * imagePlaneHeight;
    
    uniforms->camera.right *= imagePlaneWidth;
    uniforms->camera.up *= imagePlaneHeight;
    
    uniforms->width = (unsigned int)_size.width;
    uniforms->height = (unsigned int)_size.height;

    uniforms->frameIndex = _frameIndex++;
    
#if !TARGET_OS_IPHONE
    [_uniformBuffer didModifyRange:NSMakeRange(_uniformBufferOffset, alignedUniformsSize)];
#endif
    
    // Advance to the next slot in the uniform buffer
    _uniformBufferIndex = (_uniformBufferIndex + 1) % maxFramesInFlight;
}

- (void)drawInMTKView:(nonnull MTKView *)view
{
    if (!_isSceneInitialized) return;
    // We are using the uniform buffer to stream uniform data to the GPU, so we need to wait until the oldest
    // GPU frame has completed before we can reuse that space in the buffer.
    dispatch_semaphore_wait(_sem, DISPATCH_TIME_FOREVER);

    // Create a command buffer which will contain our GPU commands
    id <MTLCommandBuffer> commandBuffer = [_queue commandBuffer];

    // When the frame has finished, signal that we can reuse the uniform buffer space from this frame.
    // Note that the contents of completion handlers should be as fast as possible as the GPU driver may
    // have other work scheduled on the underlying dispatch queue.
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
        dispatch_semaphore_signal(self->_sem);
    }];

    [self updateUniforms];
    
    NSUInteger width = (NSUInteger)_size.width;
    NSUInteger height = (NSUInteger)_size.height;
    
    // We will launch a rectangular grid of threads on the GPU to generate the rays. Threads are launched in
    // groups called "threadgroups". We need to align the number of threads to be a multiple of the threadgroup
    // size. We indicated when compiling the pipeline that the threadgroup size would be a multiple of the thread
    // execution width (SIMD group size) which is typically 32 or 64 so 8x8 is a safe threadgroup size which
    // should be small to be supported on most devices. A more advanced application would choose the threadgroup
    // size dynamically.
    MTLSize threadsPerThreadgroup = MTLSizeMake(8, 8, 1);
    MTLSize threadgroups = MTLSizeMake((width  + threadsPerThreadgroup.width  - 1) / threadsPerThreadgroup.width,
                                       (height + threadsPerThreadgroup.height - 1) / threadsPerThreadgroup.height,
                                       1);
    
    // First, we will generate rays on the GPU. We create a compute command encoder which will be used to add
    // commands to the command buffer.
    id <MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
    
    // Bind buffers needed by the compute pipeline
    [computeEncoder setBuffer:_uniformBuffer   offset:_uniformBufferOffset atIndex:0];
    [computeEncoder setBuffer:_rayBuffer       offset:0                    atIndex:1];
    
    [computeEncoder setTexture:_randomTexture    atIndex:0];
    [computeEncoder setTexture:_renderTargets[0] atIndex:1];
    
    // Bind the ray generation compute pipeline
    [computeEncoder setComputePipelineState:_rayPipeline];
    
    // Launch threads
    [computeEncoder dispatchThreadgroups:threadgroups threadsPerThreadgroup:threadsPerThreadgroup];
    
    // End the encoder
    [computeEncoder endEncoding];
    
    // We will iterate over the next few kernels several times to allow light to bounce around the scene
    for (int bounce = 0; bounce < 3; bounce++) {
        _intersector.intersectionDataType = MPSIntersectionDataTypeDistancePrimitiveIndexCoordinates;

        // We can then pass the rays to the MPSRayIntersector to compute the intersections with our acceleration structure
        [_intersector encodeIntersectionToCommandBuffer:commandBuffer               // Command buffer to encode into
                                       intersectionType:MPSIntersectionTypeNearest  // Intersection test type
                                              rayBuffer:_rayBuffer                  // Ray buffer
                                        rayBufferOffset:0                           // Offset into ray buffer
                                     intersectionBuffer:_intersectionBuffer         // Intersection buffer (destination)
                               intersectionBufferOffset:0                           // Offset into intersection buffer
                                               rayCount:width * height              // Number of rays
                                  accelerationStructure:_accelerationStructure];    // Acceleration structure
        // We launch another pipeline to consume the intersection results and shade the scene
        computeEncoder = [commandBuffer computeCommandEncoder];
        
        short int index = 0;
        [computeEncoder setBuffer:_uniformBuffer      offset:_uniformBufferOffset atIndex:index++];
        [computeEncoder setBuffer:_rayBuffer          offset:0                    atIndex:index++];
        [computeEncoder setBuffer:_shadowRayBuffer    offset:0                    atIndex:index++];
        [computeEncoder setBuffer:_intersectionBuffer offset:0                    atIndex:index++];
//        [computeEncoder setBuffer:_vertexColorBuffer  offset:0                    atIndex:index++];
        [computeEncoder setBuffer:_vertexNormalBuffer offset:0                    atIndex:index++];
        [computeEncoder setBuffer:_vertexCoordsBuffer offset:0                    atIndex:index++];
        [computeEncoder setBuffer:_triangleMaskBuffer offset:0                    atIndex:index++];
        [computeEncoder setBuffer:_materialIdsBuffer  offset:0                    atIndex:index++];
        [computeEncoder setBuffer:_indexBuffer        offset:0                    atIndex:index++];
        [computeEncoder setBytes:&bounce              length:sizeof(bounce)       atIndex:index++];
        
        [computeEncoder setTexture:_randomTexture  atIndex:AAPLArgumentBufferIDRandom];
//        for (NSUInteger i=0;i<[_colorTexture count]; ++i) {
        for (NSUInteger i=0;i<[_colorTexture count]; ++i) {
            [computeEncoder setTexture:_colorTexture[i] atIndex:AAPLArgumentBufferIDColor+i];
        }
        [computeEncoder setTexture:_renderTargets[0] atIndex:AAPLArgumentBufferIDRenderTarget];

        
        [computeEncoder setComputePipelineState:_shadePipeline];
        
        [computeEncoder dispatchThreadgroups:threadgroups threadsPerThreadgroup:threadsPerThreadgroup];
        
        [computeEncoder endEncoding];
        
        // We intersect rays with the scene, except this time we are intersecting shadow rays. We only need
        // to know whether the shadows rays hit anything on the way to the light source, not which triangle
        // was intersected. Therefore, we can use the "any" intersection type to end the intersection search
        // as soon as any intersection is found. This is typically much faster than finding the nearest
        // intersection. We can also use MPSIntersectionDataTypeDistance, because we don't need the triangle
        // index and barycentric coordinates.
        _intersector.intersectionDataType = MPSIntersectionDataTypeDistance;
        
        [_intersector encodeIntersectionToCommandBuffer:commandBuffer
                                       intersectionType:MPSIntersectionTypeAny
                                              rayBuffer:_shadowRayBuffer
                                        rayBufferOffset:0
                                     intersectionBuffer:_intersectionBuffer
                               intersectionBufferOffset:0
                                               rayCount:width * height
                                  accelerationStructure:_accelerationStructure];
        
        // Finally, we launch a kernel which writes the color computed by the shading kernel into the
        // output image, but only if the corresponding shadow ray does not intersect anything on the way to
        // the light. If the shadow ray intersects a triangle before reaching the light source, the original
        // intersection point was in shadow.
        computeEncoder = [commandBuffer computeCommandEncoder];
        
        [computeEncoder setBuffer:_uniformBuffer      offset:_uniformBufferOffset atIndex:0];
        [computeEncoder setBuffer:_shadowRayBuffer    offset:0                    atIndex:1];
        [computeEncoder setBuffer:_intersectionBuffer offset:0                    atIndex:2];
        
        [computeEncoder setTexture:_renderTargets[0] atIndex:0];
        [computeEncoder setTexture:_renderTargets[1] atIndex:1];
        
        [computeEncoder setComputePipelineState:_shadowPipeline];
        
        [computeEncoder dispatchThreadgroups:threadgroups threadsPerThreadgroup:threadsPerThreadgroup];
        
        [computeEncoder endEncoding];
        
        std::swap(_renderTargets[0], _renderTargets[1]);
    }

    // The final kernel averages the current frame's image with all previous frames to reduce noise due
    // random sampling of the scene.
    computeEncoder = [commandBuffer computeCommandEncoder];
        
    [computeEncoder setBuffer:_uniformBuffer      offset:_uniformBufferOffset atIndex:0];
    
    [computeEncoder setTexture:_renderTargets[0]       atIndex:0];
    [computeEncoder setTexture:_accumulationTargets[0] atIndex:1];
    [computeEncoder setTexture:_accumulationTargets[1] atIndex:2];
    
    [computeEncoder setComputePipelineState:_accumulatePipeline];
    
    [computeEncoder dispatchThreadgroups:threadgroups threadsPerThreadgroup:threadsPerThreadgroup];
    
    [computeEncoder endEncoding];
    
    std::swap(_accumulationTargets[0], _accumulationTargets[1]);

    // Copy the resulting image into our view using the graphics pipeline since we can't write directly to
    // it with a compute kernel. We need to delay getting the current render pass descriptor as long as
    // possible to avoid stalling until the GPU/compositor release a drawable. The render pass descriptor
    // may be nil if the window has moved off screen.
    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;

    if (renderPassDescriptor != nil) {
        // Create a render encoder
        id <MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];

        [renderEncoder setRenderPipelineState:_copyPipeline];
        
        [renderEncoder setFragmentTexture:_accumulationTargets[0] atIndex:0];

        // Draw a quad which fills the screen
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];

        [renderEncoder endEncoding];

        // Present the drawable to the screen
        [commandBuffer presentDrawable:view.currentDrawable];
    }

    // Finally, commit the command buffer so that the GPU can start executing
    [commandBuffer commit];
}
-(void) moveCameraWithSpeedX:(float)x Y:(float)y Z:(float)z RX:(float)rx RY:(float)ry;
{
    _posX += x;
    _posY += y;
    _posZ += z;
    _rotX += rx;
    _rotY += ry;
    
    _makeFrameDirty = true;
}

@end
