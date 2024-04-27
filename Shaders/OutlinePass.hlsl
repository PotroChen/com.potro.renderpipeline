#ifndef UNIVERSAL_OUTLINE_PASS_INCLUDED
#define UNIVERSAL_OUTLINE_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

struct Attributes
{
    float4 positionOS     : POSITION;
    float4 tangentOS      : TANGENT;
    float3 normalOS       : NORMAL;
    float3 vertColor : COLOR;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS   : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

//
Varyings OutlineVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    float3 binormalOS = normalize(cross(input.normalOS,input.tangentOS.xyz) * sign(input.tangentOS.w));
    float3 tangentOS = normalize(input.tangentOS.xyz);
    float3 normalOS = normalize(input.normalOS);
    //����Ҫ����TBN������ֻ��Ҫ�˽�ռ�ת����������Ƶ������϶�TBN�ĸ������һ����
    float3x3 ts2os = float3x3(float3(tangentOS.x,binormalOS.x,normalOS.x),
                              float3(tangentOS.y,binormalOS.y,normalOS.y),
                              float3(tangentOS.z,binormalOS.z,normalOS.z));

    float3 smoothedNormalTS = input.vertColor;
    smoothedNormalTS.z = sqrt(1-smoothedNormalTS.r*smoothedNormalTS.r - smoothedNormalTS.g * smoothedNormalTS.g);
    float3 smoothedNormalOS = normalize(mul(ts2os,smoothedNormalTS));

    //float3 smoothedNormalVS = mul((float3x3)UNITY_MATRIX_IT_MV, input.normalOS);//���Դ���
    float3 smoothedNormalVS = mul((float3x3)UNITY_MATRIX_IT_MV, smoothedNormalOS);
    smoothedNormalVS.z = -0.5;//ͳһ����������չ�ı������ӱ�ƽ���������˵�ס���汳��Ŀ�����
    
    float4 positionVS = mul(UNITY_MATRIX_MV,input.positionOS);
    positionVS = positionVS + float4(normalize(smoothedNormalVS), 0) * _Outline;
    
    output.positionCS = mul(UNITY_MATRIX_P, positionVS);

    return output;
}

half4 OutlineFragment(Varyings input) : SV_TARGET
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    return half4(_OutColor.r,_OutColor.g,_OutColor.b,1);
}
#endif
