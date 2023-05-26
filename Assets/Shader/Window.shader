Shader "Unlit/Window"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Size("Size",float)=1
        _T("Time",float)=1
        _Distortion("Distortion",Range(-5,5))=1
        _Blur("Blur",range(0,1))=1
        _DropSpeed("DropSpeed",float)=1
    }
    //水滴速度过于平均，如果有快有慢就更好了
    //水滴的轨迹形状太圆了
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Transparent"}
        LOD 100
        GrabPass{"_GrabTexture"}
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
            #define S(a,b,t)smoothstep(a,b,t) 
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 grabUv:TEXCOORD1;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex,_GrabTexture;
            float4 _MainTex_ST;
            float _Size,_T,_Distortion,_Blur,_DropSpeed;
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.grabUv=UNITY_PROJ_COORD(ComputeGrabScreenPos(o.vertex)); 
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }
            float N21(float2 p)
            {
                p=frac(p*float2(123.34,345.45));
                p+=dot(p,p+34.345);
                return frac(p.x*p.y);
            }
            float3 Layer(float2 UV,float t)
            {
                float2 aspect=float2(2,1);
                float2 uv=UV*_Size*aspect;
                uv.y+=t*.25; 
                float2 gv=frac(uv)-.5; 
                float2 id=floor(uv);

                float n=N21(id);
                t+=n*6.2831;
                //水滴下落路线
                float w=UV.y*10; 
                float x=(n-.5)*.8;
                x+=(.4-abs(x))*sin(3*w)*pow(sin(w),6)*.45;
                float y=-sin(t+sin(t+sin(t)*.5))*.45;
                //水滴形状
                y-=(gv.x-x)*(gv.x-x);
                
                float2 dropPos=(gv-float2(x,y))/aspect;
                float drop=S(.05,.03,length(dropPos)); 

                //水滴拖尾效果
                float2 trailPos=(gv-float2(x,t*.25))/aspect;
                trailPos.y=(frac(trailPos.y*8)-.5)/8;
                float trail=S(.03,.01,length(trailPos)); 
                float fogTrail=S(-.05,.05,dropPos.y);
                fogTrail*=S(.5,y,gv.y);
                trail*=fogTrail;
                //拖尾雾气效果
                fogTrail*=S(.05,.04,abs(dropPos.x));
                float2 offs=drop*dropPos+trail*trailPos;
                //if(gv.x>.48||gv.y>.49) col=float4(1,0,0,1);
                return float3(offs,fogTrail);
            }
            fixed4 frag (v2f i) : SV_Target
            {
                //t表示时间,没两小时重置一次，以防时间数字太大导致伪随机数露馅
                float t=fmod(_Time.y*_DropSpeed+_T,7200);

                float4 col=0;
                //区域分隔

                float3 drops=Layer(i.uv,t);
                drops+=Layer(i.uv*1.23+7.54,t);
                drops+=Layer(i.uv*1.35+1.54,t);
                drops+=Layer(i.uv*1.57-7.54,t);
                float fade=1-saturate(fwidth(i.uv)*60);
                float blur=_Blur*7*(1-drops.z);

                //col=tex2Dlod(_MainTex,float4(i.uv+drops.xy*_Distortion,0,blur));
                float2 projUv=i.grabUv.xy/i.grabUv.w;
                projUv+=drops.xy*_Distortion*fade;
                blur*=.01;

                const float numsSamples=32;
                float a=N21(i.uv)*6.2831;
                for(float i=0;i<numsSamples;i++)
                {
                    float2 offs=float2(sin(a),cos(a))*blur;
                    float d=frac(sin((i+1)*546.)*5424.);
                    d=sqrt(d);
                    offs*=d;
                    col+=tex2D(_GrabTexture,projUv+offs);
                    a++;
                }
                col/=numsSamples;
                //col*=0;col+=fade; 
                return col;
            }
            ENDCG
        }
    }
}
