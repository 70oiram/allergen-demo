shader_type canvas_item;
// 瀕死狀態：畫面周邊的暗紅色血管（心跳）。pulse 0→1 時血管加深並往畫面中心小幅蔓延；
// 整體顯示由節點 modulate.a 控制。

uniform vec2 view = vec2(1920.0, 1080.0);
uniform float pulse = 0.0;          // 心跳強度（由腳本 tween）
uniform float reach_rest = 110.0;   // 平時血管伸入距離（畫面像素）
uniform float reach_beat = 210.0;   // 心跳最強時伸入距離
uniform vec3 vein_color = vec3(0.30, 0.0, 0.03);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return v;
}

// 固定像素寬度的線：取 fbm 的 0.5 等值線，除以梯度避免平坦處糊成一片
float fbm3(vec2 p) {
	return 0.57 * noise(p) + 0.29 * noise(p * 2.03 + vec2(17.0, 9.0)) + 0.14 * noise(p * 4.1 + vec2(5.0, 23.0));
}

float vein_line(vec2 p, float width_px) {
	float n = fbm3(p + vec2(noise(p * 0.6 + 3.1), noise(p * 0.6 + 8.3)) * 0.6);
	float dist_px = abs(n - 0.5) / max(fwidth(n), 1e-4);
	return 1.0 - smoothstep(width_px * 0.5, width_px * 0.5 + 1.2, dist_px);
}

// 以「沿邊座標、離邊距離」取樣：沿離邊方向拉長，血管由邊緣朝中心延伸
float vessels(float along, float d, float t) {
	vec2 q = vec2(along / 70.0, d / 260.0);
	float main_v = vein_line(q, mix(5.0, 1.0, t));
	float fine_v = vein_line(q * vec2(2.3, 1.7) + vec2(31.0, 5.0), mix(2.5, 0.6, t)) * (1.0 - t);
	return max(main_v, fine_v * 0.75);
}

void fragment() {
	vec2 px = UV * view;
	vec2 e = min(px, view - px);
	// 平滑取最近邊距離與兩側權重，角落不出現斜接縫
	float k = 80.0;
	float h = clamp(0.5 + 0.5 * (e.y - e.x) / k, 0.0, 1.0);   // 1 = 靠左右邊，0 = 靠上下邊
	float d = mix(e.y, e.x, h) - k * h * (1.0 - h);

	// 伸入距離隨位置起伏，血管末端參差不齊
	float jitter = 0.6 + 0.7 * fbm(px / 160.0);
	float reach = mix(reach_rest, reach_beat, pulse) * jitter;
	float t = clamp(d / max(reach, 1.0), 0.0, 1.0);   // 0 = 邊緣，1 = 末端

	// 四邊各自偏移取樣，避免上下、左右圖樣對稱
	float v_lr = vessels(px.y + (px.x < view.x * 0.5 ? 0.0 : 5300.0), e.x, t);
	float v_tb = vessels(px.x + (px.y < view.y * 0.5 ? 2100.0 : 8700.0), e.y, t);
	float v = mix(v_tb, v_lr, h) * (1.0 - smoothstep(0.6, 1.0, t));

	// 緊貼邊緣的暗紅充血底色（深淺不一）
	float rim = (1.0 - smoothstep(0.0, mix(35.0, 60.0, pulse), d)) * (0.55 + 0.45 * fbm(px / 60.0));

	float a = max(v * 0.95, rim * 0.8) * (0.5 + 0.5 * pulse);
	COLOR = vec4(vein_color, a);
}
