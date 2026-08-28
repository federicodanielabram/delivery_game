shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float opacity : hint_range(0.0, 1.0) = 0.72;
uniform float brightness : hint_range(0.5, 4.0) = 1.2;

void fragment() {
	vec4 shape = texture(TEXTURE, UV);
	if (shape.a < 0.01) {
		COLOR = vec4(0.0);
		return;
	}

	// Samplea el área de la pantalla donde están las luces (encima del charco)
	vec2 ref_uv = vec2(SCREEN_UV.x, max(0.0, SCREEN_UV.y - 0.45));
	vec4 reflection = texture(screen_texture, ref_uv);

	COLOR = vec4(reflection.rgb * brightness, shape.a * opacity);
}
