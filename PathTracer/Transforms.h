/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Header for trasnform matrices
*/

#ifndef Transforms_h
#define Transforms_h

#import <simd/simd.h>
#include <node.h>

matrix_float4x4 matrix4x4_translation(float tx, float ty, float tz);
matrix_float4x4 matrix4x4_rotation(float radians, vector_float3 axis);
matrix_float4x4 matrix4x4_scale(float sx, float sy, float sz);
matrix_float4x4 matrix4x4_from_mat4(const mat4& matrix);

#endif
