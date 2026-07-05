shader_type canvas_item;

uniform vec4 flash_color : source_color = vec4(1.0, 0.0, 0.0, 0.0);
uniform float flash_strength = 0.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	vec4 mixed = mix(tex_color, flash_color, flash_strength * flash_color.a);
	COLOR = vec4(mixed.rgb, tex_color.a);
}
