struct VertexAttribute
{
    float4 positionOS : POSITION;
    float4 tangentOS : TANGENT;
    float3 normalOS : NORMAL;
    float2 uv : TEXCOORD0;

};
struct VertexShaderOutput
{
    float4 positionCS : SV_Position;
    float3 positionWS : TEXCOORD0;
    float3 normalWS : TEXCOORD1;
    float4 tangentWS : TEXCOORD2;
    //float4 tangentTS : TEXCOORD3;
    float2 uv : TEXCOORD3;    
};