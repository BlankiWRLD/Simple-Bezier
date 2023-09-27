//
//  DotShader.metal
//  Bezier
//
//  Created by MotionVFX on 27/09/2023.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]];
    float isDragged [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float isDragged;
};

vertex VertexOut dot_vertex(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.isDragged = in.isDragged;
    return out;
}

fragment half4 dot_fragment(VertexOut in [[stage_in]]) {
    if (in.isDragged > 0.5) {
        return half4(0.0, 1.0, 0.0, 1.0);
    } else {
        return half4(1.0, 0.0, 0.0, 1.0);
    }
}

