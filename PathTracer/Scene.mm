/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation for scene creation functions
*/


#import "Scene.h"


#import <CoreFoundation/CFBase.h>
#import <CoreFoundation/CFString.h>
#import <CoreFoundation/CFURL.h>
#import <CoreFoundation/CFBundle.h>


using namespace simd;

std::vector<vector_float3> vertices;
std::vector<vector_float3> normals;
std::vector<vector_float3> colors;
std::vector<vector_float2> uvs;
std::vector<uint32_t> indices;
std::vector<uint32_t> masks;
std::vector<uint32_t> materials;

Meshgroup meshgroup;

void loadMeshFromBundle(const char* name, const char* ext)
{
    // see https://stackoverflow.com/questions/24165681/accessing-files-in-resources-folder-in-mac-osx-app-bundle/24165954
    CFStringRef nameRef;
    nameRef = CFStringCreateWithCString(kCFAllocatorDefault,name,kCFStringEncodingUTF8);
    CFStringRef extRef;
    extRef = CFStringCreateWithCString(kCFAllocatorDefault,ext,kCFStringEncodingUTF8);
    CFURLRef urlRef = CFBundleCopyResourceURL(CFBundleGetMainBundle(), nameRef, extRef, NULL);
    CFRelease(nameRef);
    CFRelease(extRef);
    
    CFURLRef urlDirectoryFileRef = CFURLCreateCopyDeletingLastPathComponent(NULL, urlRef);
    CFStringRef stringDirectoryRef = CFURLCopyPath(urlDirectoryFileRef);
    CFStringRef stringNameRef = CFURLCopyLastPathComponent(urlRef);
    
//    CFStringRef appStringRef = CFURLGetString ( appUrlRef );

    // do something with the file
    //...
    const CFIndex kCStringSize = 256;
    char temporaryNameCString[kCStringSize];
    bzero(temporaryNameCString,kCStringSize);
    char temporaryPathCString[kCStringSize];
    bzero(temporaryPathCString,kCStringSize);
    CFStringGetCString(stringNameRef, temporaryNameCString, kCStringSize, kCFStringEncodingUTF8);
    CFStringGetCString(stringDirectoryRef, temporaryPathCString, kCStringSize, kCFStringEncodingUTF8);
    
    // Ensure you release the reference
    CFRelease(urlRef);
    CFRelease(urlDirectoryFileRef);
    CFRelease(stringDirectoryRef);
    CFRelease(stringNameRef);
    
    meshgroup.load_from_file(temporaryPathCString, temporaryNameCString, true);
}

void loadMeshFromUrl(CFURLRef urlRef)
{
    CFURLRef urlDirectoryFileRef = CFURLCreateCopyDeletingLastPathComponent(NULL, urlRef);
    CFStringRef stringDirectoryRef = CFURLCopyPath(urlDirectoryFileRef);
    CFRelease(urlDirectoryFileRef);
    CFStringRef stringNameRef = CFURLCopyLastPathComponent(urlRef);
    
//    CFStringRef appStringRef = CFURLGetString ( appUrlRef );

    // do something with the file
    //...
    const CFIndex kCStringSize = 256;
    char temporaryNameCString[kCStringSize];
    bzero(temporaryNameCString,kCStringSize);
    char temporaryPathCString[kCStringSize];
    bzero(temporaryPathCString,kCStringSize);
    CFStringGetCString(stringNameRef, temporaryNameCString, kCStringSize, kCFStringEncodingUTF8);
    CFStringGetCString(stringDirectoryRef, temporaryPathCString, kCStringSize, kCFStringEncodingUTF8);
      
    CFRelease(stringDirectoryRef);
    CFRelease(stringNameRef);
    
    meshgroup.load_from_file(temporaryPathCString, temporaryNameCString, false);
}


float3 getTriangleNormal(float3 v0, float3 v1, float3 v2) {
    float3 e1 = normalize(v1 - v0);
    float3 e2 = normalize(v2 - v0);
    
    return cross(e1, e2);
}

void createCubeFace(std::vector<float3> & vertices,
                    std::vector<float3> & normals,
                    std::vector<float3> & colors,
                    std::vector<float2> & uvs,
                    std::vector<uint32_t> & indices,
                    float3 *cubeVertices,
                    float3 color,
                    unsigned int i0,
                    unsigned int i1,
                    unsigned int i2,
                    unsigned int i3,
                    bool inwardNormals,
                    unsigned int triangleMask,
                    unsigned int materialIndex)
{
    float3 v0 = cubeVertices[i0]; //0
    float3 v1 = cubeVertices[i1]; //2
    float3 v2 = cubeVertices[i2]; //3
    float3 v3 = cubeVertices[i3]; //1
    
    float3 n0 = getTriangleNormal(v0, v1, v2);
    float3 n1 = getTriangleNormal(v0, v2, v3);
    
    float2 uv00 = {0,0};
    float2 uv10 = {1,0};
    float2 uv01 = {0,1};
    float2 uv11 = {1,1};
    
    if (inwardNormals) {
        n0 = -n0;
        n1 = -n1;
    }

    uint32_t vertexIndices[6] = {0,1,2,0,2,3};
    uint32_t vertexOffset = static_cast<uint32_t>(vertices.size());
    
    vertices.push_back(v0);uvs.push_back(uv01);normals.push_back(n0);colors.push_back(color);
    vertices.push_back(v1);uvs.push_back(uv00);normals.push_back(n0);colors.push_back(color);
    vertices.push_back(v2);uvs.push_back(uv10);normals.push_back(n0);colors.push_back(color);
    vertices.push_back(v3);uvs.push_back(uv11);normals.push_back(n0);colors.push_back(color);
    
    for (int i=0;i<6;++i) {
        indices.push_back(vertexOffset + vertexIndices[i]);
    }

    for (int i = 0; i < 2; i++)
        masks.push_back(triangleMask);
    
    for (int i = 0; i < 2; i++)
        materials.push_back(materialIndex);
    
}

void createCube(unsigned int faceMask,
                vector_float3 color,
                matrix_float4x4 transform,
                bool inwardNormals,
                unsigned int triangleMask,
                unsigned int materialIndex)
{
    float3 cubeVertices[] = {
        vector3(-0.5f, -0.5f, -0.5f),
        vector3( 0.5f, -0.5f, -0.5f),
        vector3(-0.5f,  0.5f, -0.5f),
        vector3( 0.5f,  0.5f, -0.5f),
        vector3(-0.5f, -0.5f,  0.5f),
        vector3( 0.5f, -0.5f,  0.5f),
        vector3(-0.5f,  0.5f,  0.5f),
        vector3( 0.5f,  0.5f,  0.5f),
    };
    
    for (int i = 0; i < 8; i++) {
        float3 vertex = cubeVertices[i];
        
        float4 transformedVertex = vector4(vertex.x, vertex.y, vertex.z, 1.0f);
        transformedVertex = transform * transformedVertex;
        
        cubeVertices[i] = transformedVertex.xyz;
    }
    
    if (faceMask & FACE_MASK_NEGATIVE_X)
        createCubeFace(vertices, normals, colors, uvs, indices, cubeVertices, color, 0, 4, 6, 2, inwardNormals, triangleMask, materialIndex);
    
    if (faceMask & FACE_MASK_POSITIVE_X)
        createCubeFace(vertices, normals, colors, uvs, indices, cubeVertices, color, 1, 3, 7, 5, inwardNormals, triangleMask, materialIndex);
    
    if (faceMask & FACE_MASK_NEGATIVE_Y)
        createCubeFace(vertices, normals, colors, uvs, indices, cubeVertices, color, 0, 1, 5, 4, inwardNormals, triangleMask, materialIndex);
    
    if (faceMask & FACE_MASK_POSITIVE_Y)
        createCubeFace(vertices, normals, colors, uvs, indices, cubeVertices, color, 2, 6, 7, 3, inwardNormals, triangleMask, materialIndex);
    
    if (faceMask & FACE_MASK_NEGATIVE_Z)
        createCubeFace(vertices, normals, colors, uvs, indices, cubeVertices, color, 0, 2, 3, 1, inwardNormals, triangleMask, materialIndex);
    
    if (faceMask & FACE_MASK_POSITIVE_Z)
        createCubeFace(vertices, normals, colors, uvs, indices, cubeVertices, color, 4, 5, 7, 6, inwardNormals, triangleMask, materialIndex);
}
