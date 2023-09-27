//
//  Shader.metal
//  Bezier
//
//  Created by MotionVFX on 27/09/2023.
//

#include <metal_stdlib>

using namespace metal;

struct VertexIn {
    float2 position;
};

vertex float4 vertex_main(constant VertexIn *vertices [[buffer(0)]], uint vid [[vertex_id]]) {
    return float4(vertices[vid].position, 0.0, 1.0);
}

fragment float4 fragment_main() {
    return float4(0.4,0.8,0.24,1.0);
}

