// Lake water. The draw colour's red channel carries depth (0 = shore, 1 = deep), so the
// script can paint depth with soft blobs; this shader turns that into colour, ripples,
// glints and shore foam.
shader_type canvas_item;

uniform vec3 shallow : source_color = vec3(0.50, 0.83, 0.93);
uniform vec3 mid_col : source_color = vec3(0.20, 0.60, 0.80);
uniform vec3 deep : source_color = vec3(0.12, 0.42, 0.62);

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

void vertex() {
	wpos = VERTEX;
}

void fragment() {
	float depth = COLOR.r;
	float a = COLOR.a;
	vec3 col = mix(shallow, mid_col, smoothstep(0.0, 0.55, depth));
	col = mix(col, deep, smoothstep(0.55, 1.0, depth));
	// slow ripple bands
	float r = noise(wpos / vec2(70.0, 26.0) + vec2(TIME * 0.18, TIME * 0.05))
		- noise(wpos / vec2(52.0, 20.0) - vec2(TIME * 0.12, -TIME * 0.07));
	col += vec3(0.10, 0.12, 0.13) * smoothstep(0.18, 0.38, r);
	// sky sheen near the top of each pool
	col += vec3(0.06, 0.08, 0.1) * smoothstep(0.4, 0.0, depth) * 0.6;
	// glints
	float s = noise(wpos / vec2(10.0, 4.0) + vec2(TIME * 0.7, TIME * 0.2));
	col += vec3(1.0) * smoothstep(0.9, 0.98, s) * 0.7 * (1.0 - depth * 0.4);
	// shore foam
	float edge = 1.0 - smoothstep(0.0, 0.12, depth);
	float patches = smoothstep(0.5, 0.75, noise(wpos / vec2(22.0, 12.0) + vec2(TIME * 0.25, TIME * 0.1)));
	col = mix(col, vec3(0.97, 1.0, 1.0), edge * patches * 0.75);
	COLOR = vec4(col, a);
}
