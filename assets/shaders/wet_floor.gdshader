shader_type canvas_item;

uniform float wet_darkness   : hint_range(0.0, 1.0) = 0.32;
uniform float ripple_speed   : hint_range(0.0, 5.0) = 0.9;
uniform float ripple_scale   : hint_range(1.0, 100.0) = 22.0;
uniform float ripple_strength: hint_range(0.0, 0.03) = 0.006;

void fragment() {
	float r1 = sin(UV.x * ripple_scale       + TIME * ripple_speed)        * ripple_strength;
	float r2 = cos(UV.x * ripple_scale * 0.7 - TIME * ripple_speed * 1.3)  * ripple_strength * 0.5;
	vec2 duv = clamp(UV + vec2(r1, r2), vec2(0.0), vec2(1.0));

	vec4 base = texture(TEXTURE, duv);
	COLOR = vec4(base.rgb * (1.0 - wet_darkness), base.a);
}
