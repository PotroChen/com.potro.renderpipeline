Shader "Hidden/Universal Render Pipeline/Custom/ExponentialHeightFog"
{
    HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

        TEXTURE2D_X(_SourceTex);
        float4x4 _FrustumCornersRay;
        float4x4 _ViewProjectionInverseMatrix;
        //参数考虑都用half,界面使用Clamp
        float _FogDensity;
        half _FogOpacity;
        float _FogHeight;
        float _HeightFalloff;
        float _FogStartDistance;
        float4 _FogColor;
        float _InscatteringExponent;
        float _InscatteringStartDistance;

        TEXTURE3D(_HeightNoiseTexture);        SAMPLER(sampler_HeightNoiseTexture);
        float3 _HeightNoiseScale;
        float2 _HeightNoiseFlowSpeed;
        float _HeightNoisePower;

        TEXTURE2D(_HeightColorRampTexture);        SAMPLER(sampler_HeightColorRampTexture);
        float _BottomHeight;
        float _TopHeight;

        struct VaryingsCMB
        {
            float4 positionCS    : SV_POSITION;
            float4 uv            : TEXCOORD0;
            UNITY_VERTEX_OUTPUT_STEREO
        };

        VaryingsCMB VertCMB(Attributes input)
        {
            VaryingsCMB output;
            UNITY_SETUP_INSTANCE_ID(input);
            UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

            output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
            output.uv.xy = input.uv;

            float4 projPos = output.positionCS * 0.5;
            projPos.xy = projPos.xy + projPos.w;//xy的范围从[-w,w]->[0,w]
            output.uv.zw = projPos.xy;//uv.zw为范围[0,w]的xy.但是好像URP确定屏幕后处理的shader这里的w为1？

            return output;
        }

        float CalculateLineIntegralShared(float heightFalloff,float rayDirectionY,float rayOriginTerms)
        {
            //-127是UE源码的经验值，UE中的注释“if it's lower than -127.0, then exp2() goes crazy in OpenGL's GLSL.”
            float falloff = max(-127,heightFalloff * rayDirectionY);
            float lineIntegral = ( 1- exp2(-falloff) ) / falloff;
	        float lineIntegralTaylor = log(2.0) - ( 0.5 * pow(2,log(2.0) ) ) * falloff;		// Taylor expansion around 0

            return rayOriginTerms * ( abs(falloff) > 0.01 ? lineIntegral : lineIntegralTaylor );
        }

        float GetInscatterFog(float3 positionWS, float3 cameraPoistionWS, float3 mainLightDirectionWS, float inscatteringExponent)
        {
            float3 vectorCamToReceiver = normalize(positionWS - cameraPoistionWS);
            float3 vectorCamToSun = mainLightDirectionWS;
            half base = saturate(dot(vectorCamToReceiver,vectorCamToSun));
            
            half inscatterFog = saturate(pow(base,inscatteringExponent));
            return inscatterFog;
        }

    ENDHLSL
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}
        LOD 100
        ZTest Always ZWrite Off Cull Off

        Pass
        {
            Name "ExponentialHeightFog"

            HLSLPROGRAM
                #pragma vertex VertCMB
                #pragma fragment Frag

                half4 Frag(VaryingsCMB input) : SV_Target
                {
                    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                    float4 uv = float4(UnityStereoTransformScreenSpaceTex(input.uv.xy),input.uv.zw);
 
                    float depth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_PointClamp, uv.xy).r;
                #if UNITY_REVERSED_Z
                    depth = 1.0 - depth;
                #endif

                    depth = depth * 2.0 - 1.0;
                    float3 viewPos = ComputeViewSpacePosition(uv.zw, depth, unity_CameraInvProjection);
                    float4 positionWS = float4(mul(unity_CameraToWorld, float4(viewPos, 1.0)).xyz, 1.0);

                    float3 cameraToReceiver = positionWS.xyz - _WorldSpaceCameraPos;
                    //Length的平方，因为夹角为0，cos为1
                    float cameraToReceiverLengthSqr = dot(cameraToReceiver, cameraToReceiver);
                    //Length的倒数,rsqrt作用是返回平方根的倒数，输入模的平方，则返回模的倒数
	                float cameraToReceiverLengthInv = rsqrt(max(cameraToReceiverLengthSqr, 0.00000001f));
                    //Length的平方乘以模的倒数 = 模
	                float cameraToReceiverLength = cameraToReceiverLengthSqr * cameraToReceiverLengthInv;//如果直接用这个变量当作rayLength(高度距离和雾效的衰减关系会没有)
                    half3 cameraToReceiverNormalized = cameraToReceiver * cameraToReceiverLengthInv;

                    float rayLength = max(cameraToReceiverLength - _FogStartDistance,0); 
                    float rayDirectionY = positionWS.y;

                    half3 noiseUV = half3(positionWS.x/_HeightNoiseScale.x,positionWS.y/_HeightNoiseScale.y,positionWS.z/_HeightNoiseScale.z);
                    noiseUV = noiseUV + half3(frac(_Time.x)*_HeightNoiseFlowSpeed.x,0,frac(_Time.x)*_HeightNoiseFlowSpeed.y);
                    half heightNosie = SAMPLE_TEXTURE3D(_HeightNoiseTexture,sampler_HeightNoiseTexture,noiseUV);
                    rayDirectionY = rayDirectionY + heightNosie *  _HeightNoisePower;

                    float exponent =  max(-127,_HeightFalloff * (rayDirectionY - _FogHeight));
                    float rayOriginalTerms = _FogDensity * exp2(-exponent);
                    float exponentialHeightLineIntegralShared = CalculateLineIntegralShared(_HeightFalloff,rayDirectionY,rayOriginalTerms);
                    float exponentialHeightLineIntegral = exponentialHeightLineIntegralShared * rayLength;
                    //half expFogFactor = saturate(exp2(-exponentialHeightLineIntegral));
                    half expFogFactor = max(saturate(exp2(-exponentialHeightLineIntegral)),_FogOpacity);

                    //Inscattered
                    float dirExponentialHeightLineIntegral = exponentialHeightLineIntegralShared * max(rayLength - _InscatteringStartDistance,0); 
                    half  dirInscatteringFogFactor = saturate(exp2(-dirExponentialHeightLineIntegral));
                    half3 directionalLightInscattering = pow(saturate(dot(cameraToReceiverNormalized,_MainLightPosition.xyz)),_InscatteringExponent);
                    half3 directionalInscattering = directionalLightInscattering * (1 - dirInscatteringFogFactor);

                    //half3 fogColor = _FogColor;
                    half2 heightColorRampUV = half2(1,(clamp(positionWS.y,_BottomHeight,_TopHeight)-_BottomHeight)/(_TopHeight - _BottomHeight));
                    half3 fogColor =  SAMPLE_TEXTURE2D(_HeightColorRampTexture,sampler_HeightColorRampTexture,heightColorRampUV);
                    fogColor = fogColor * (1 - expFogFactor) +  directionalInscattering;

                    half4 finalColor = SAMPLE_TEXTURE2D_X(_SourceTex,sampler_LinearClamp, input.uv);
                    finalColor.rgb = finalColor.rgb * expFogFactor + fogColor * (1 - expFogFactor);
                    //half t = clamp(rayDirectionY,_BottomHeight,_TopHeight)-_BottomHeight/(_TopHeight - _BottomHeight);
                    //half4 finalColor = half4(t,t,t,1);

                    return finalColor;

                }
            ENDHLSL
        }
    }
}
