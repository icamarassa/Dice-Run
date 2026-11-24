class_name ArvoreMelhorias
extends Control
# Árvore de melhorias no estilo dos jogos incrementais.
#  - Roda do mouse: zoom.  Arrastar com o botão esquerdo (ou do meio): mover.
#  - Só aparecem as melhorias que já podem ser compradas. Ao evoluir uma, a linha até a
#    próxima acende aos poucos e a nova melhoria surge.

signal hover_mudou(m: Melhoria, area: Rect2)    # m é null quando o mouse sai de um ícone
signal compra_realizada(m: Melhoria)

const TAM_NO := 96.0
const ESPACO_X := 150.0
const ESPACO_Y := 150.0
const ZOOM_MIN := 0.5
const ZOOM_MAX := 1.6

var aba := ""
var mundo: Control                         # tudo que se move e recebe zoom fica aqui dentro
var nos := {}                              # id da melhoria -> NoMelhoria
var melhorias_aba: Array[Melhoria] = []
var progresso_linha := {}                  # id do filho -> 0..1 (quanto da linha já acendeu)
var linha_liberada := {}                   # id do filho -> a linha já estava acesa?
var zoom := 1.0
var area_conteudo := Vector2.ZERO
var arrastando := false
var moveu_demais := false
var pos_clique := Vector2.ZERO
var hover_id := ""


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mundo = Control.new()
	mundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mundo)
	resized.connect(_limitar)
	mouse_exited.connect(_limpar_hover)


func _tamanho_janela() -> Vector2:
	return custom_minimum_size if size == Vector2.ZERO else size


func construir(id_aba: String) -> void:
	aba = id_aba
	for filho in mundo.get_children():
		mundo.remove_child(filho)
		filho.queue_free()
	nos.clear()
	melhorias_aba.clear()
	progresso_linha.clear()
	linha_liberada.clear()
	hover_id = ""

	var posicoes := {}
	var indice_auto := 0
	var max_c := 0
	var max_l := 0
	for m in Salvamento.todas_melhorias():
		if m.classe != aba:
			continue
		melhorias_aba.append(m)
		var p := ArvoreLayout.posicao(m, indice_auto)
		if not ArvoreLayout.NOS.has(m.id):
			indice_auto += 1
		posicoes[m.id] = p
		max_c = maxi(max_c, p.x)
		max_l = maxi(max_l, p.y)
	area_conteudo = Vector2(max_c * ESPACO_X + TAM_NO, max_l * ESPACO_Y + TAM_NO)

	for m in melhorias_aba:
		var p: Vector2i = posicoes[m.id]
		var no := NoMelhoria.new()
		no.configurar(m, ArvoreLayout.icone(m), ArvoreLayout.cor(m))
		no.size = Vector2(TAM_NO, TAM_NO)
		no.position = Vector2(p.x * ESPACO_X, p.y * ESPACO_Y)
		mundo.add_child(no)
		nos[m.id] = no

		# Só aparece o que já pode ser comprado
		var liberada := Salvamento.requisito_cumprido(m)
		linha_liberada[m.id] = liberada
		progresso_linha[m.id] = 1.0 if liberada else 0.0
		no.visible = liberada

	zoom = 1.0
	mundo.scale = Vector2.ONE
	var janela := _tamanho_janela()
	mundo.position = (janela - area_conteudo) / 2.0
	atualizar(false)


# Reavalia o estado de todos os ícones (depois de uma compra, por exemplo)
func atualizar(animar := true) -> void:
	for m in melhorias_aba:
		var no: NoMelhoria = nos[m.id]
		no.atualizar_estado()
		if Salvamento.requisito_cumprido(m) and not linha_liberada[m.id]:
			linha_liberada[m.id] = true
			if animar:
				_acender_linha(m.id)
				no.aparecer(0.7)        # surge quando a linha já está quase acesa
			else:
				progresso_linha[m.id] = 1.0
				no.visible = true
	queue_redraw()


func _acender_linha(id: String) -> void:
	var t := create_tween()
	t.tween_method(_definir_progresso.bind(id), 0.0, 1.0, 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _definir_progresso(valor: float, id: String) -> void:
	progresso_linha[id] = valor
	queue_redraw()


# ======================================================
#  ENTRADA: zoom, arrastar, passar o mouse e clicar
# ======================================================

func _gui_input(event: InputEvent) -> void:
	var botao := event as InputEventMouseButton
	if botao:
		match botao.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_dar_zoom(1.12, botao.position)
			MOUSE_BUTTON_WHEEL_DOWN:
				_dar_zoom(1.0 / 1.12, botao.position)
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE:
				if botao.pressed:
					arrastando = true
					moveu_demais = false
					pos_clique = botao.position
				else:
					# Soltou sem ter arrastado: foi um clique
					if arrastando and not moveu_demais and botao.button_index == MOUSE_BUTTON_LEFT:
						_clicar_em(botao.position)
					arrastando = false
					mouse_default_cursor_shape = Control.CURSOR_ARROW
					_atualizar_hover(botao.position, true)
		return

	var mov := event as InputEventMouseMotion
	if mov:
		if arrastando:
			if not moveu_demais and mov.position.distance_to(pos_clique) > 6.0:
				moveu_demais = true
				_limpar_hover()
			if moveu_demais:
				mouse_default_cursor_shape = Control.CURSOR_DRAG
				mundo.position += mov.relative
				_limitar()
		else:
			_atualizar_hover(mov.position)


func _dar_zoom(fator: float, centro: Vector2) -> void:
	var novo := clampf(zoom * fator, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(novo, zoom):
		return
	# Mantém o ponto sob o mouse parado enquanto o zoom muda
	var antes := (centro - mundo.position) / zoom
	zoom = novo
	mundo.scale = Vector2(zoom, zoom)
	mundo.position = centro - antes * zoom
	_limitar()
	_atualizar_hover(centro, true)


# Impede de arrastar a árvore para longe demais
func _limitar() -> void:
	if mundo == null:
		return
	var janela := _tamanho_janela()
	var conteudo := area_conteudo * zoom
	var folga := 120.0
	var pos := mundo.position
	for eixo in 2:
		if conteudo[eixo] + folga * 2.0 < janela[eixo]:
			pos[eixo] = (janela[eixo] - conteudo[eixo]) / 2.0
		else:
			pos[eixo] = clampf(pos[eixo], janela[eixo] - conteudo[eixo] - folga, folga)
	mundo.position = pos
	queue_redraw()


func _no_em(pos_local: Vector2) -> String:
	var p := (pos_local - mundo.position) / zoom
	for id in nos:
		var no: Control = nos[id]
		if no.visible and Rect2(no.position, no.size).has_point(p):
			return id
	return ""


func _atualizar_hover(pos_local: Vector2, forcar := false) -> void:
	var id := _no_em(pos_local)
	if id == hover_id and not forcar:
		return

	if hover_id != "" and nos.has(hover_id):
		nos[hover_id].definir_sobre(false)
	hover_id = id

	if id == "":
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		hover_mudou.emit(null, Rect2())
		return

	var no: NoMelhoria = nos[id]
	no.definir_sobre(true)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var area := Rect2(global_position + mundo.position + no.position * zoom, no.size * zoom)
	hover_mudou.emit(no.m, area)


func _limpar_hover() -> void:
	if hover_id != "" and nos.has(hover_id):
		nos[hover_id].definir_sobre(false)
	hover_id = ""
	hover_mudou.emit(null, Rect2())


func _clicar_em(pos_local: Vector2) -> void:
	var id := _no_em(pos_local)
	if id == "":
		return
	var no: NoMelhoria = nos[id]
	if Salvamento.comprar_melhoria(no.m):
		no.pop()
		atualizar()
		compra_realizada.emit(no.m)
		_atualizar_hover(pos_local, true)     # atualiza a caixinha com o novo nível
	else:
		no.recusar()


# ======================================================
#  DESENHO: as linhas entre as melhorias
# ======================================================

func _draw() -> void:
	draw_set_transform(mundo.position, 0.0, Vector2(zoom, zoom))
	for m in melhorias_aba:
		var pai_id := ArvoreLayout.pai(m)
		if pai_id == "" or not nos.has(pai_id) or not nos.has(m.id):
			continue
		var pai_no: Control = nos[pai_id]
		var filho_no: Control = nos[m.id]
		var progresso: float = progresso_linha[m.id]
		if not pai_no.visible or (progresso <= 0.0 and not filho_no.visible):
			continue

		var p1 := pai_no.position + pai_no.size / 2.0
		var p2 := filho_no.position + filho_no.size / 2.0
		var cor_linha := ArvoreLayout.cor(m)
		draw_line(p1, p2, Color(0, 0, 0, 0.55), 9.0, true)
		draw_line(p1, p2, Color(0.26, 0.26, 0.36), 4.0, true)      # trilho apagado
		if progresso > 0.0:
			var ponta := p1.lerp(p2, progresso)
			draw_line(p1, ponta, Color(cor_linha, 0.35), 11.0, true)  # brilho
			draw_line(p1, ponta, cor_linha, 4.0, true)
			if progresso < 1.0:
				draw_circle(ponta, 7.0, Color(1, 1, 1, 0.9))         # "faísca" na ponta

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_string(ThemeDB.fallback_font, Vector2(14.0, size.y - 12.0),
		"Arraste para mover  •  Roda do mouse para o zoom", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(1, 1, 1, 0.3))


# ======================================================
#  Um ícone quadrado da árvore
# ======================================================
class NoMelhoria extends Control:
	var m: Melhoria
	var icone := "estrela"
	var cor := Color.WHITE
	var estado := "disponivel"      # disponivel, sem_ouro, maximo
	var sobre := false
	var tempo := 0.0


	func configurar(melhoria: Melhoria, nome_icone: String, cor_icone: Color) -> void:
		m = melhoria
		icone = nome_icone
		cor = cor_icone
		mouse_filter = Control.MOUSE_FILTER_IGNORE    # quem cuida do mouse é a árvore


	func _ready() -> void:
		pivot_offset = size / 2.0


	func definir_sobre(valor: bool) -> void:
		sobre = valor
		queue_redraw()


	func _process(delta: float) -> void:
		tempo += delta
		if estado == "disponivel" and visible:
			queue_redraw()      # o brilho pulsa


	func atualizar_estado() -> void:
		var nivel := Salvamento.nivel_melhoria(m.id)
		if nivel >= m.nivel_max:
			estado = "maximo"
		elif Salvamento.ouro >= Salvamento.custo_melhoria(m):
			estado = "disponivel"
		else:
			estado = "sem_ouro"
		queue_redraw()


	# Surge com um "pop" depois de "atraso" segundos
	func aparecer(atraso: float) -> void:
		visible = true
		modulate.a = 0.0
		scale = Vector2(0.3, 0.3)
		var t := create_tween().set_parallel(true)
		t.tween_property(self, "modulate:a", 1.0, 0.3).set_delay(atraso)
		t.tween_property(self, "scale", Vector2.ONE, 0.45).set_delay(atraso) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


	func pop() -> void:
		scale = Vector2.ONE
		var t := create_tween()
		t.tween_property(self, "scale", Vector2(1.25, 1.25), 0.1)
		t.tween_property(self, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


	func recusar() -> void:
		var x := position.x
		var t := create_tween()
		for desvio in [-8.0, 8.0, -5.0, 5.0, 0.0]:
			t.tween_property(self, "position:x", x + desvio, 0.04)


	func _draw() -> void:
		var nivel := Salvamento.nivel_melhoria(m.id)
		var fundo := Color(0.11, 0.1, 0.18)
		var borda := cor.darkened(0.4)

		match estado:
			"disponivel":
				fundo = fundo.lerp(cor, 0.18)
				borda = cor
			"maximo":
				fundo = fundo.lerp(Color(1.0, 0.85, 0.3), 0.22)
				borda = Color(1.0, 0.85, 0.3)
		if sobre:
			borda = borda.lightened(0.3)

		var caixa := StyleBoxFlat.new()
		caixa.bg_color = fundo
		caixa.border_color = borda
		caixa.set_border_width_all(4)
		caixa.set_corner_radius_all(14)
		if estado == "disponivel":
			var pulso := 0.5 + 0.5 * sin(tempo * 4.0)
			caixa.shadow_color = Color(cor, 0.25 + 0.3 * pulso)
			caixa.shadow_size = 6 + int(8.0 * pulso)
		draw_style_box(caixa, Rect2(Vector2.ZERO, size))

		IconesArvore.desenhar(self, icone, Vector2(size.x * 0.5, size.y * 0.42), size.x * 0.34, cor)

		# Bolinhas de nível (cheia = comprado)
		var total := m.nivel_max
		var passo := minf(14.0, (size.x - 20.0) / maxf(total, 1.0))
		var x0 := (size.x - passo * (total - 1)) / 2.0
		for i in total:
			var centro := Vector2(x0 + i * passo, size.y - 13.0)
			if i < nivel:
				draw_circle(centro, 4.5, cor.lightened(0.25))
			else:
				draw_arc(centro, 4.5, 0.0, TAU, 12, Color(0.5, 0.5, 0.62), 1.6)
