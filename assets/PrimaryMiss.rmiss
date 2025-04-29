
#include "structures.fxh"

ConstantBuffer<Constants> g_ConstantsCB;

[shader("miss")]
void main(inout PrimaryRayPayload payload)
{
const float3 Palette[] = {
    float3(0.40, 0.55, 0.85),  
    float3(0.55, 0.70, 0.90),  
    float3(0.70, 0.80, 0.93),  
    float3(0.80, 0.88, 0.95),  
    float3(0.88, 0.93, 0.97), 
    float3(0.95, 0.97, 1.00)   
};



    // Generate sky color.
    float factor  = clamp((WorldRayDirection().y + 0.5) / 1.5 * 4.0, 0.0, 4.0);
    int   idx     = floor(factor);
          factor -= float(idx);
    float3 color  = lerp(Palette[idx], Palette[idx+1], factor);

    payload.Color = color;
    //payload.Depth = RayTCurrent(); // bug in DXC for SPIRV
    payload.Depth = g_ConstantsCB.ClipPlanes.y;
}
