attribute vec4 attr_Position;
attribute vec3 attr_Normal;

#if defined(USE_VERTEX_ANIMATION)
attribute vec4 attr_Position2;
attribute vec3 attr_Normal2;
#elif defined(USE_SKELETAL_ANIMATION)
attribute vec4 attr_BoneIndexes;
attribute vec4 attr_BoneWeights;
#endif

attribute vec4 attr_Color;
attribute vec4 attr_TexCoord0;

#if defined(USE_LIGHTMAP) || defined(USE_TCGEN)
attribute vec4 attr_TexCoord1;
#endif

uniform vec4   u_DiffuseTexMatrix;
uniform vec4   u_DiffuseTexOffTurb;

#if defined(USE_TCGEN) || defined(USE_RGBAGEN)
uniform vec3   u_LocalViewOrigin;
#endif

#if defined(USE_TCGEN)
uniform int    u_TCGen0;
uniform vec3   u_TCGen0Vector0;
uniform vec3   u_TCGen0Vector1;
#endif

#if defined(USE_FOG)
uniform vec4   u_FogDistance;
uniform vec4   u_FogDepth;
uniform float  u_FogEyeT;
uniform vec4   u_FogColorMask;
#endif

#if defined(USE_DEFORM_VERTEXES)
uniform int    u_DeformGen;
uniform float  u_DeformParams[5];
uniform float  u_Time;
#endif

uniform mat4   u_ModelViewProjectionMatrix;
uniform vec4   u_BaseColor;
uniform vec4   u_VertColor;

#if defined(USE_RGBAGEN)
uniform int    u_ColorGen;
uniform int    u_AlphaGen;
uniform vec3   u_AmbientLight;
uniform vec3   u_DirectedLight;
uniform vec3   u_ModelLightDir;
uniform float  u_PortalRange;
#endif

#if defined(USE_VERTEX_ANIMATION)
uniform float  u_VertexLerp;
#elif defined(USE_SKELETAL_ANIMATION)
uniform mat4   u_BoneMatrices[80];
#endif

varying vec2   var_DiffuseTex;
#if defined(USE_LIGHTMAP)
varying vec2   var_LightTex;
#endif
varying vec4   var_Color;

#if defined(USE_DEFORM_VERTEXES)
vec3 DeformPosition(const vec3 pos, const vec3 normal, const vec2 st)
{
	float base =      u_DeformParams[0];
	float amplitude = u_DeformParams[1];
	float phase =     u_DeformParams[2];
	float frequency = u_DeformParams[3];
	float spread =    u_DeformParams[4];

	if (u_DeformGen == DGEN_BULGE)
	{
		phase *= M_PI * 0.25 * st.x;
	}
	else // if (u_DeformGen <= DGEN_WAVE_INVERSE_SAWTOOTH)
	{
		phase += dot(pos.xyz, vec3(spread));
	}

	float value = phase + (u_Time * frequency);
	float func;

	if (u_DeformGen == DGEN_WAVE_SIN)
	{
		func = sin(value * 2.0 * M_PI);
	}
	else if (u_DeformGen == DGEN_WAVE_SQUARE)
	{
		func = sign(sin(value * 2.0 * M_PI));
	}
	else if (u_DeformGen == DGEN_WAVE_TRIANGLE)
	{
		func = 1.0 - abs(4.0 * fract(value + 0.25) - 2.0);
	}
	else if (u_DeformGen == DGEN_WAVE_SAWTOOTH)
	{
		func = fract(value);
	}
	else if (u_DeformGen == DGEN_WAVE_INVERSE_SAWTOOTH)
	{
		func = (1.0 - fract(value));
	}
	else if (u_DeformGen == DGEN_BULGE)
	{
		func = sin(value);
	}

	return pos + normal * (base + func * amplitude);
}
#endif

#if defined(USE_TCGEN)
vec2 GenTexCoords(int TCGen, vec3 position, vec3 normal, vec3 TCGenVector0, vec3 TCGenVector1)
{
	vec2 tex = attr_TexCoord0.st;

	if (TCGen == TCGEN_LIGHTMAP)
	{
		tex = attr_TexCoord1.st;
	}
	else if (TCGen == TCGEN_ENVIRONMENT_MAPPED)
	{
		vec3 viewer = normalize(u_LocalViewOrigin - position);
		tex = -reflect(viewer, normal).yz * vec2(0.5, -0.5) + 0.5;
	}
	else if (TCGen == TCGEN_VECTOR)
	{
		tex = vec2(dot(position, TCGenVector0), dot(position, TCGenVector1));
	}
	
	return tex;
}
#endif

#if defined(USE_TCMOD)
vec2 ModTexCoords(vec2 st, vec3 position, vec4 texMatrix, vec4 offTurb)
{
	float amplitude = offTurb.z;
	float phase = offTurb.w;
	vec2 st2 = vec2(dot(st, texMatrix.xz), dot(st, texMatrix.yw)) + offTurb.xy;

	vec3 offsetPos = position / 1024.0;
	offsetPos.x += offsetPos.z;
	
	vec2 texOffset = sin((offsetPos.xy + vec2(phase)) * 2.0 * M_PI);
	
	return st2 + texOffset * amplitude;	
}
#endif

#if defined(USE_RGBAGEN)
vec4 CalcColor(vec3 position, vec3 normal)
{
	vec4 color = u_VertColor * attr_Color + u_BaseColor;
	
	if (u_ColorGen == CGEN_LIGHTING_DIFFUSE)
	{
		float incoming = clamp(dot(normal, u_ModelLightDir), 0.0, 1.0);

		color.rgb = clamp(u_DirectedLight * incoming + u_AmbientLight, 0.0, 1.0);
	}
	
	vec3 viewer = u_LocalViewOrigin - position;

	if (u_AlphaGen == AGEN_LIGHTING_SPECULAR)
	{
		vec3 lightDir = normalize(vec3(-960.0, 1980.0, 96.0) - position.xyz);
		vec3 reflected = -reflect(lightDir, normal);
		
		color.a = clamp(dot(reflected, normalize(viewer)), 0.0, 1.0);
		color.a *= color.a;
		color.a *= color.a;
	}
	else if (u_AlphaGen == AGEN_PORTAL)
	{
		color.a = clamp(length(viewer) / u_PortalRange, 0.0, 1.0);
	}
	
	return color;
}
#endif

#if defined(USE_FOG)
float CalcFog(vec4 position)
{
	float s = dot(position, u_FogDistance) * 8.0;
	float t = dot(position, u_FogDepth);

	float eyeOutside = step(0.0, -u_FogEyeT);
	float fogged = step(eyeOutside, t);
		
	t = max(t, 1e-6);
	t *= fogged / (t - u_FogEyeT * eyeOutside);

	return s * t;
}
#endif

void main()
{
#if defined(USE_VERTEX_ANIMATION)
	vec4 position = mix(attr_Position, attr_Position2, u_VertexLerp);
	vec3 normal = normalize(mix(attr_Normal, attr_Normal2, u_VertexLerp));
#elif defined(USE_SKELETAL_ANIMATION)
	vec4 position = vec4(0.0);
	vec4 normal4 = vec4(0.0);
	vec4 originalNormal = vec4(attr_Normal, 0.0);

	for (int i = 0; i < 4; i++)
	{
		int boneIndex = int(attr_BoneIndexes[i]);

		position += (u_BoneMatrices[boneIndex] * attr_Position) * attr_BoneWeights[i];
		normal4 += (u_BoneMatrices[boneIndex] * originalNormal) * attr_BoneWeights[i];
	}

	vec3 normal = normal4.xyz;
#else
	vec4 position = attr_Position;
	vec3 normal = attr_Normal;
#endif

#if defined(USE_DEFORM_VERTEXES)
	position.xyz = DeformPosition(position.xyz, normal, attr_TexCoord0.st);
#endif

	gl_Position = u_ModelViewProjectionMatrix * position;

#if defined(USE_TCGEN)
	vec2 tex = GenTexCoords(u_TCGen0, position.xyz, normal, u_TCGen0Vector0, u_TCGen0Vector1);
#else
	vec2 tex = attr_TexCoord0.st;
#endif

#if defined(USE_TCMOD)
	var_DiffuseTex = ModTexCoords(tex, position.xyz, u_DiffuseTexMatrix, u_DiffuseTexOffTurb);
#else
    var_DiffuseTex = tex;
#endif

#if defined(USE_LIGHTMAP)
	var_LightTex = attr_TexCoord1.st;
#endif

#if defined(USE_RGBAGEN)
	var_Color = CalcColor(position.xyz, normal);
#else
	var_Color = u_VertColor * attr_Color + u_BaseColor;
#endif

#if defined(USE_FOG)
	var_Color *= vec4(1.0) - u_FogColorMask * sqrt(clamp(CalcFog(position), 0.0, 1.0));
#endif
}
