/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Header containing types and enum constants shared between Metal shaders and Swift/ObjC source
*/

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

#define TRIANGLE_MASK_GEOMETRY 1
#define TRIANGLE_MASK_LIGHT    2

#define RAY_MASK_PRIMARY   3
#define RAY_MASK_SHADOW    1
#define RAY_MASK_SECONDARY 1

struct Camera {
    vector_float3 position;
    vector_float3 right;
    vector_float3 up;
    vector_float3 forward;
};

struct AreaLight {
    vector_float3 position;
    vector_float3 forward;
    vector_float3 right;
    vector_float3 up;
    vector_float3 color;
};

struct Uniforms
{
    unsigned int width;
    unsigned int height;
    unsigned int frameIndex;
    Camera camera;
    AreaLight light;
};

// Constant values shared between shader and C code which indicate the size of argument arrays
//   in the structure defining the argument buffers
typedef enum Materials {
    ImageMaterial,
    ConcreteMaterial,
    RedConcreteMaterial,
    GreenConcreteMaterial,
    PlywoodMaterial,
    MaterialSize,
    MaxMaterialSize = 64
} Materials;

// Argument buffer indices shared between shader and C code to ensure Metal shader buffer
//   input match Metal API texture set calls
typedef enum AAPLArgumentBufferID
{
    AAPLArgumentBufferIDRandom  = 0,
    AAPLArgumentBufferIDColor   = 1,
    AAPLArgumentBufferIDRenderTarget = AAPLArgumentBufferIDColor+MaxMaterialSize
} AAPLArgumentBufferID;

#endif /* ShaderTypes_h */

