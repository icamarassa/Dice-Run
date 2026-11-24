class_name PainelDica
extends PanelContainer
# Caixinha de informação que aparece quando o mouse passa sobre um ícone.

var titulo: Label
var corpo: Label
var rodape: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 200
	visible = false
	custom_minimum_size = Vector2(280, 0)

	var estilo := Estilo.painel(Color(0.05, 0.04, 0.1, 0.97), 12, 14)
	estilo.border_color = Color(0.5, 0.42, 0.7)
	estilo.set_border_width_all(2)
	add_theme_stylebox_override("panel", estilo)

	var caixa := VBoxContainer.new()
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.add_theme_constant_override("separation", 8)
	add_child(caixa)

	titulo = _novo_texto(22, Color.WHITE)
	corpo = _novo_texto(16, Color(0.82, 0.82, 0.9))
	rodape = _novo_texto(16, Color(1.0, 0.85, 0.3))
	for l in [titulo, corpo, rodape]:
		caixa.add_child(l)


func _novo_texto(tamanho: int, cor: Color) -> Label:
	var l := Estilo.novo_label("", tamanho, cor, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.custom_minimum_size = Vector2(250, 0)
	return l


# "ancora" é o retângulo do ícone (em coordenadas da tela); a caixa aparece ao lado dele
func mostrar(texto_titulo: String, texto_corpo: String, texto_rodape: String,
		cor_titulo: Color, cor_rodape: Color, ancora: Rect2) -> void:
	titulo.text = texto_titulo
	titulo.add_theme_color_override("font_color", cor_titulo)
	corpo.text = texto_corpo
	corpo.visible = texto_corpo != ""
	rodape.text = texto_rodape
	rodape.add_theme_color_override("font_color", cor_rodape)
	rodape.visible = texto_rodape != ""

	visible = true
	_posicionar(ancora)
	# O texto com quebra de linha só tem a altura certa um instante depois
	call_deferred("_posicionar", ancora)


func _posicionar(ancora: Rect2) -> void:
	reset_size()
	var tamanho := get_combined_minimum_size()
	size = tamanho
	var tela := get_viewport_rect().size
	var pos := Vector2(ancora.end.x + 14.0, ancora.position.y)
	if pos.x + tamanho.x > tela.x - 8.0:
		pos.x = ancora.position.x - tamanho.x - 14.0
	pos.x = clampf(pos.x, 8.0, tela.x - tamanho.x - 8.0)
	pos.y = clampf(pos.y, 8.0, tela.y - tamanho.y - 8.0)
	global_position = pos


func esconder() -> void:
	visible = false
