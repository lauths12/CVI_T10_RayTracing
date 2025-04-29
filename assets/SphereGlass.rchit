#include "structures.fxh"
#include "RayUtils.fxh"

float3 LightAbsorption(float3 color1, float depth)
{
    float factor = clamp(depth * 0.25 + pow(depth * g_ConstantsCB.GlassAbsorption, 2.2) * 0.25 + 0.05, 0.0, 1.0);
    return lerp(color1, color1 * g_ConstantsCB.GlassMaterialColor.rgb, factor);
}

float Fresnel(float eta, float cosThetaI)
{
    cosThetaI = clamp(cosThetaI, -1.0, 1.0);
    if (cosThetaI < 0.0)
    {
        eta = 1.0 / eta;
        cosThetaI = -cosThetaI;
    }
    float sinThetaTSq = eta * eta * (1.0 - cosThetaI * cosThetaI);
    if (sinThetaTSq > 1.0) return 1.0;
    float cosThetaT = sqrt(1.0 - sinThetaTSq);
    float Rs = (eta * cosThetaI - cosThetaT) / (eta * cosThetaI + cosThetaT);
    float Rp = (eta * cosThetaT - cosThetaI) / (eta * cosThetaT + cosThetaI);
    return 0.5 * (Rs * Rs + Rp * Rp);
}

[shader("closesthit")]
void main(inout PrimaryRayPayload payload, in ProceduralGeomIntersectionAttribs attr)
{
    float3 normal = normalize(mul((float3x3)ObjectToWorld3x4(), attr.Normal));
    const float AirIOR = 1.0;
    float3 resultColor = float3(0.0, 0.0, 0.0);

    RayDesc ray;
    ray.TMin = SMALL_OFFSET;
    ray.TMax = 100.0;

    if (g_ConstantsCB.GlassEnableDispersion && payload.Recursion == 0)
    {
        float3 AccumColor = float3(0.0, 0.0, 0.0);
        float3 AccumMask  = float3(0.0, 0.0, 0.0);
        const int step = MAX_DISPERS_SAMPLES / g_ConstantsCB.DispersionSampleCount;
        for (int i = 0; i < MAX_DISPERS_SAMPLES; i += step)
        {
            float3 rayDir = refract(WorldRayDirection(), normal, AirIOR / lerp(g_ConstantsCB.GlassIndexOfRefraction.x, g_ConstantsCB.GlassIndexOfRefraction.y, g_ConstantsCB.DispersionSamples[i].a));
            float fresnel = Fresnel(AirIOR / g_ConstantsCB.GlassIndexOfRefraction.x, dot(WorldRayDirection(), -normal));

            ray.Origin = WorldRayOrigin() + WorldRayDirection() * RayTCurrent() + normal * SMALL_OFFSET;
            ray.Direction = reflect(WorldRayDirection(), normal);
            PrimaryRayPayload reflPayload = CastPrimaryRay(ray, payload.Recursion + 1);

            float3 refrColor = float3(0.0, 0.0, 0.0);
            if (fresnel < 1.0)
            {
                ray.Origin = WorldRayOrigin() + WorldRayDirection() * RayTCurrent();
                ray.Direction = rayDir;
                PrimaryRayPayload refrPayload = CastPrimaryRay(ray, payload.Recursion + 1);
                refrColor = LightAbsorption(refrPayload.Color, refrPayload.Depth);
            }

            AccumColor += lerp(refrColor, reflPayload.Color, fresnel) * g_ConstantsCB.DispersionSamples[i].rgb;
            AccumMask += g_ConstantsCB.DispersionSamples[i].rgb;
        }
        resultColor = AccumColor / AccumMask;
    }
    else
    {
        float3 rayDir = refract(WorldRayDirection(), normal, AirIOR / g_ConstantsCB.GlassIndexOfRefraction.x);
        float fresnel = Fresnel(AirIOR / g_ConstantsCB.GlassIndexOfRefraction.x, dot(WorldRayDirection(), -normal));

        ray.Origin = WorldRayOrigin() + WorldRayDirection() * RayTCurrent() + normal * SMALL_OFFSET;
        ray.Direction = reflect(WorldRayDirection(), normal);
        PrimaryRayPayload reflPayload = CastPrimaryRay(ray, payload.Recursion + 1);

        if (fresnel < 1.0)
        {
            ray.Origin = WorldRayOrigin() + WorldRayDirection() * RayTCurrent();
            ray.Direction = rayDir;
            PrimaryRayPayload refrPayload = CastPrimaryRay(ray, payload.Recursion + 1);
            resultColor = LightAbsorption(refrPayload.Color, refrPayload.Depth);
        }

        resultColor = lerp(resultColor, reflPayload.Color, fresnel);
    }

    payload.Color = resultColor;
    payload.Depth = RayTCurrent();
}
