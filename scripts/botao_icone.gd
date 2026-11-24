class_name BotaoIcone
extends Control
# Botão quadrado com um ícone desenhado por código (habilidade, lista de modificadores, etc.).

signal pressionado
signal dica_pedida(mostrar: bool, no: Control)

var icone := "estrela"
var cor := Color.WHITE
var badge := -1                 # número no canto (ex.: usos restantes). -1 = sem número
var desativado := false
var clicavel := true
var pulsar := false             # brilho pulsando (chama a atenção)
var sobre := false
var tempo := 0.0


func configurar(nome_icone: String, cor_icone: Color, lado := 64.0) -> void:
	icone = nome_icone
	cor = cor_icone
	custom_minimum_size = Vector2(lado, lado)
	size = Vector2(lado, lado)
	pivot_offset = size / 2.0


func atualizar(esta_desativado: bool, valor_badge: int, esta_pulsando: bool) -> void:
	desativado = esta_desativado
	badge = valor_badge
	pulsar = esta_pulsando
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_ao_entrar)
	mouse_exited.connect(_ao_sair)


func _ao_entrar() -> void:
	sobre = true
	dica_pedida.emit(true, self)
	queue_redraw()


func _ao_sair() -> void:
	sobre = false
	dica_pedida.emit(false, self)
	queue_redraw()


func _process(delta: float) -> void:
	tempo += delta
	if pulsar and not desativado:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var clique := event as InputEventMouseButton
	if clique and clique.pressed and clique.button_index == MOUSE_BUTTON_LEFT:
		if clicavel and not desativado:
			_pop()
			pressionado.emit()


func _pop() -> void:
	scale = Vector2.ONE
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.15, 1.15), 0.07)
	t.tween_property(self, "scale", Vector2.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var fundo := Color(0.11, 0.1, 0.18)
	var borda := cor.darkened(0.3)
	var cor_icone := cor

	if desativado:
		fundo = Color(0.08, 0.08, 0.11)
		borda = Color(0.3, 0.3, 0.38)
		cor_icone = Color(0.4, 0.4, 0.5)
	elif sobre and clicavel:
		borda = cor.lightened(0.3)
		fundo = fundo.lerp(cor, 0.15)

	var caixa := StyleBoxFlat.new()
	caixa.bg_color = fundo
	caixa.border_color = borda
	caixa.set_border_width_all(3)
	caixa.set_corner_radius_all(12)
	if pulsar and not desativado:
		var pulso := 0.5 + 0.5 * sin(tempo * 4.0)
		caixa.shadow_color = Color(cor, 0.25 + 0.3 * pulso)
		caixa.shadow_size = 5 + int(8.0 * pulso)
	draw_style_box(caixa, Rect2(Vector2.ZERO, size))

	IconesArvore.desenhar(self, icone, size / 2.0, size.x * 0.32, cor_icone)

	# Número no canto
	if badge >= 0:
		var centro := Vector2(size.x - 12.0, size.y - 12.0)
		draw_circle(centro, 11.0, Color(0.05, 0.04, 0.1))
		draw_arc(centro, 11.0, 0.0, TAU, 16, borda, 2.0)
		draw_string(ThemeDB.fallback_font, centro + Vector2(-8.0, 6.0), str(badge),
			HORIZONTAL_ALIGNMENT_CENTER, 16.0, 16, Color.WHITE)
