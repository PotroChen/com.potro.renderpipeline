Shader "Universal Render Pipeline/OutlineExample"
{
    Properties
    {
        _Outline("Outline", Float) = 0.01
        _OutColor("OutColor", COLOR) = (0, 0, 0, 1)
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry" }
        Pass
        {
            Tags{ "LightMode" = "SRPDefaultUnlit" }
            Name "Outline"
            Cull Front

            HLSLPROGRAM

            float _Outline;
            half3 _OutColor;
            #pragma vertex OutlineVertex
            #pragma fragment OutlineFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/OutlinePass.hlsl"
            ENDHLSL
        }
        Pass
        {
            Tags{ "LightMode" = "UniversalForward" }
		    Cull Back
            Name "OutlineExample"

            HLSLPROGRAM
            #pragma vertex ExampleVertex
            #pragma fragment ExampleFragment
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            struct Attributes
            {
                float3 positionOS     : POSITION;
                //UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;

                //UNITY_VERTEX_INPUT_INSTANCE_ID
                //UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings ExampleVertex(Attributes input)
            {
                Varyings output = (Varyings)0;

                //UNITY_SETUP_INSTANCE_ID(input);
                //UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                output.positionCS = TransformObjectToHClip(input.positionOS);

                return output;
            }

            half4 ExampleFragment(Varyings input) : SV_TARGET
            {
                //UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                return half4(1,1,1,1);
            }
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
