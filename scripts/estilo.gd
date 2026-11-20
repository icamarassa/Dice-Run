class_name Estilo
extends RefCounted
# Funções de aparência usadas pelo jogo e pelo menu.


static func novo_label(texto: String, tamanho: int, cor := Color.WHITE, quebra_linha := true) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if quebra_linha:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	return l


static func estilo_botao(cor: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = cor
	s.border_color = cor.lightened(0.35)
	s.set_border_width_all(3)
	s.set_corner_radius_all(12)
	s.shadow_color = Color(cor, 0.4)
	s.shadow_size = 8
	return s


# Botão dourado (ações principais)
static func botao_dourado(botao: Button, tamanho_fonte := 28) -> void:
	botao.add_theme_font_size_override("font_size", tamanho_fonte)
	var escuro := Color(0.12, 0.08, 0.02)
	for nome_cor in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		botao.add_theme_color_override(nome_cor, escuro)
	botao.add_theme_stylebox_override("normal", estilo_botao(Color(0.95, 0.7, 0.15)))
	botao.add_theme_stylebox_override("hover", estilo_botao(Color(1.0, 0.82, 0.35)))
	botao.add_theme_stylebox_override("pressed", estilo_botao(Color(0.8, 0.55, 0.1)))
	botao.add_theme_stylebox_override("disabled", estilo_botao(Color(0.4, 0.4, 0.45)))


# Botão roxo (ações secundárias)
static func botao_secundario(botao: Button, tamanho_fonte := 22) -> void:
	botao.add_theme_font_size_override("font_size", tamanho_fonte)
	botao.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	botao.add_theme_color_override("font_hover_color", Color.WHITE)
	botao.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.62))
	botao.add_theme_stylebox_override("normal", estilo_botao(Color(0.28, 0.22, 0.48)))
	botao.add_theme_stylebox_override("hover", estilo_botao(Color(0.4, 0.32, 0.65)))
	botao.add_theme_stylebox_override("pressed", estilo_botao(Color(0.2, 0.16, 0.36)))
	botao.add_theme_stylebox_override("disabled", estilo_botao(Color(0.16, 0.15, 0.22)))


static func painel(cor := Color(0, 0, 0, 0.45), raio := 10, margem := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = cor
	s.set_corner_radius_all(raio)
	s.set_content_margin_all(margem)
	return s


static func estilo_card(cor: Color, destacado: bool, espessura := 4, brilho := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.09, 0.09, 0.13).lerp(cor, 0.28 if destacado else 0.14)
	s.border_color = cor
	s.set_border_width_all(espessura)
	s.set_corner_radius_all(16)
	s.shadow_color = Color(cor, 0.55 if destacado else 0.3)
	s.shadow_size = brilho
	return s
