shader_type canvas_item;
render_mode blend_mix;

uniform float vignette_intensity: hint_range(0.0, 1.0) = 0.4;
uniform float vignette_radius: hint_range(0.0, 1.0) = 0.6;
uniform float vignette_smoothness: hint_range(0.0, 1.0) = 0.3;

uniform float watercolor_amount: hint_range(0.0, 1.0) = 0.0;
uniform float paper_roughness: hint_range(0.0, 0.15) = 0.05;
uniform float color_wash_intensity: hint_range(0.0, 0.3) = 0.0;
uniform vec4 color_wash_tint: source_color = vec4(0.95, 0.9, 0.85, 0.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 center = UV - 0.5;
	float dist = length(center);

	float vignette_alpha = smoothstep(
		vignette_radius,
		vignette_radius + (1.0 - vignette_radius) * vignette_smoothness,
		dist
	) * vignette_intensity;

	float noise = hash(UV * 400.0 + TIME * 0.02);
	float paper_alpha = (noise - 0.5) * paper_roughness;

	float wc_alpha = 0.0;
	if (watercolor_amount > 0.001) {
		float wc_noise1 = hash(UV * 80.0 + TIME * 0.01);
		float wc_noise2 = hash(UV * 60.0 + TIME * 0.015);
		float wc_lump = (wc_noise1 * 0.6 + wc_noise2 * 0.4);
		wc_alpha = (wc_lump - 0.3) * 0.4 * watercolor_amount;
	}

	float alpha = clamp(vignette_alpha + paper_alpha + wc_alpha, 0.0, 1.0);

	vec3 overlay_color = color_wash_tint.rgb;
	float wash_alpha = color_wash_intensity * watercolor_amount * (1.0 - dist);
	overlay_color = mix(vec3(0.0), overlay_color, wash_alpha / max(alpha, 0.001));
	alpha = max(alpha, wash_alpha);

	COLOR = vec4(overlay_color, clamp(alpha, 0.0, 1.0));
}
