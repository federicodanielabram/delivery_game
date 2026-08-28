shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 4.0) = 1.4;

void fragment() {
	vec2 texel = blur_amount / vec2(textureSize(TEXTURE, 0));
	vec4 col = vec4(0.0);
	col += texture(TEXTURE, UV + vec2(-texel.x, -texel.y));
	col += texture(TEXTURE, UV + vec2( 0.0,     -texel.y));
	col += texture(TEXTURE, UV + vec2( texel.x, -texel.y));
	col += texture(TEXTURE, UV + vec2(-texel.x,  0.0    ));
	col += texture(TEXTURE, UV);
	col += texture(TEXTURE, UV + vec2( texel.x,  0.0    ));
	col += texture(TEXTURE, UV + vec2(-texel.x,  texel.y));
	col += texture(TEXTURE, UV + vec2( 0.0,      texel.y));
	col += texture(TEXTURE, UV + vec2( texel.x,  texel.y));
	COLOR = (col / 9.0) * COLOR;
}
