#include "structures.fxh"
#include "RayUtils.fxh"

float3 RandomColor(uint id)
{
    return normalize(float3(
        frac(sin(id * 12.9898) * 43758.5453),
        frac(sin((id + 17) * 78.233) * 12345.6789),
        frac(sin((id + 42) * 23.123) * 98765.4321)
    )) * 0.9 + 0.1;
}

float3 GetSurfaceColor(uint instanceID)
{
    return (instanceID >= 4) ? RandomColor(instanceID) : g_ConstantsCB.SphereReflectionColorMask.rgb;
}

bool IsInShadow(float3 surfacePos, float3 lightDir)
{
    RayDesc shadowRay = { surfacePos + lightDir * 0.001, lightDir, 0.0, 1e20 };
    return CastShadow(shadowRay, 0).Shading > 0.0;
}

[shader("closesthit")]
void main(inout PrimaryRayPayload payload, in ProceduralGeomIntersectionAttribs attribs)
{
    float3 worldPos = WorldRayOrigin() + WorldRayDirection() * RayTCurrent();
    float3 normal = normalize(attribs.Normal);
    uint instID = InstanceIndex();
    float3 baseColor = GetSurfaceColor(instID);

    float3 color = baseColor * 0.5; // luz ambiental mínima pero colorida

    [unroll]
    for (uint i = 0; i < NUM_LIGHTS; ++i)
    {
        float3 lightDir = normalize(g_ConstantsCB.LightPos[i].xyz - worldPos);
        float diffuse = saturate(dot(normal, lightDir));
        if (IsInShadow(worldPos, lightDir))
        {
            diffuse *= 0.5;
        }
        color += diffuse * g_ConstantsCB.LightColor[i].rgb * baseColor * 2.0; // más intenso
    }

    payload.Color = float4(saturate(color), 1.0);
}