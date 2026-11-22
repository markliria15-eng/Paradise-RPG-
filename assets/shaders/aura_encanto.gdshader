// Contorno brilhante do heroi com arma encantada (scripts/profissoes.gd -> _atualizar_aura).
// Desenha a silhueta engrossada na cor do encanto, pulsando; fica atras do sprite do heroi.
shader_type canvas_item;
render_mode blend_add;

uniform vec4 cor : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float raio = 4.0;
uniform float intensidade = 1.0;

void fragment() {
	vec2 passo = TEXTURE_PIXEL_SIZE * raio;
	float a = 0.0;
	for (int i = 0; i < 12; i++) {
		float ang = float(i) * 0.5235988;
		vec2 d = vec2(cos(ang), sin(ang));
		a = max(a, texture(TEXTURE, UV + d * passo).a);
		a = max(a, texture(TEXTURE, UV + d * passo * 0.5).a);
	}
	float pulso = 0.7 + 0.3 * sin(TIME * 3.2);
	COLOR = vec4(cor.rgb, a * cor.a * intensidade * pulso);
}
