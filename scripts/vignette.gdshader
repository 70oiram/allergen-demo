shader_type canvas_item;
// 階段氛圍：第一階段清新、第二階段違和、第三階段陰暗血腥

uniform float strength = 0.25;
uniform float red = 0.0;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	uv.x *= 1.25;
	float d = length(uv);
	float v = smoothstep(0.32, 0.9, d) * strength;
	vec3 tint = mix(vec3(0.0), vec3(0.28, 0.0, 0.02), red);
	COLOR = vec4(tint, v);
}
