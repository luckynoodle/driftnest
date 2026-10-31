// Painted meadow: layered value noise blended between greens, with soft brush strokes.
shader_type canvas_item;

uniform vec3 c_dark : source_color = vec3(0.42, 0.70, 0.33);
uniform vec3 c_mid : source_color = vec3(0.55, 0.80, 0.40);
uniform vec3 c_light : source_color = vec3(0.67, 0.87, 0.47);
uniform vec3 c_warm : source_color = vec3(0.78, 0.86, 0.45);

varying vec2 wpos;

float hash(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
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

void vertex() {
	wpos = VERTEX;
}

void fragment() {
	float n = fbm(wpos / 520.0);
	float d = fbm(wpos / 140.0 + vec2(7.0, 3.0));
	float strokes = noise(vec2(wpos.x / 18.0 + wpos.y / 40.0, wpos.y / 6.0));
	vec3 col = mix(c_dark, c_mid, smoothstep(0.28, 0.52, n));
	col = mix(col, c_light, smoothstep(0.55, 0.78, n) * 0.85);
	col = mix(col, c_warm, smoothstep(0.62, 0.9, d) * 0.28);
	col = mix(col, c_dark, smoothstep(0.62, 0.22, d) * 0.18);
	col *= 0.95 + 0.08 * strokes;
	COLOR = vec4(col, 1.0);
}
