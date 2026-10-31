// Screen finish for the "storybook miniature" look: tilt-shift blur at the top and bottom,
// a warm sunlight wash from the top-left, cool shade bottom-right, soft vignette and paper grain.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float blur_px = 2.6;
uniform float band = 0.18;
uniform float grain = 0.022;

void fragment() {
	vec2 uv = SCREEN_UV;
	float b = smoothstep(band, 0.0, uv.y) + smoothstep(1.0 - band, 1.0, uv.y);
	vec3 col = texture(screen_tex, uv).rgb;
	if (b > 0.01) {
		vec2 px = SCREEN_PIXEL_SIZE * blur_px * b;
		vec3 acc = col * 2.0;
		float w = 2.0;
		for (int i = 0; i < 8; i++) {
			float ang = float(i) * 0.785398;
			vec2 o = vec2(cos(ang), sin(ang));
			acc += texture(screen_tex, uv + o * px).rgb;
			acc += texture(screen_tex, uv + o * px * 2.2).rgb * 0.7;
			w += 1.7;
		}
		col = acc / w;
	}
	float d = dot(uv, vec2(0.62, 0.78));
	col = mix(col, col * vec3(1.05, 1.03, 0.93) + vec3(0.045, 0.035, 0.0), (1.0 - smoothstep(0.0, 0.85, d)) * 0.7);
	col = mix(col, col * vec3(0.93, 0.97, 1.05), smoothstep(0.85, 1.4, d) * 0.6);
	vec2 v = (uv - 0.5) * vec2(1.0, 1.25);
	float vig = smoothstep(0.42, 0.9, length(v));
	col = mix(col, col * vec3(0.74, 0.8, 0.9), vig * 0.5);
	float g = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	col += g * grain;
	COLOR = vec4(col, 1.0);
}
