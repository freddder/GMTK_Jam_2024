shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D noise_texture;

void fragment() {
	vec2 distortedUV = SCREEN_UV + texture(noise_texture, UV).r * 0.03;
	vec4 main_color = textureLod(screen_texture, distortedUV, 0.0);
	vec4 mask = texture(TEXTURE, UV, 0.0);
    COLOR = main_color * mask;
	COLOR.rgb = COLOR.gbr;
}