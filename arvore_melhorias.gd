class_name ArvoreMelhorias
extends Control
# Árvore de melhorias no estilo dos jogos incrementais: ícones quadrados ligados por linhas.
# Uma melhoria só pode ser comprada depois que a anterior (o "pai") atingir o nível exigido.

signal passou_o_mouse(m: Melhoria)
signal compra_realizada(m: Melhoria)

const TAM_NO := 96.0
const ESPACO_X := 150.0
const ESPACO_Y := 150.0
const MARGEM := 40.0
const LARGURA_MINIMA := 780.0

var aba := ""
var nos := {}                              # id da melhoria -> NoMelhoria
var melhorias_aba: Array[Melhoria] = []


func construir(id_aba: String) -> void:
	aba = id_aba
	for filho in get_children():
		remove_child(filho)
		filho.queue_free()
	nos.clear()
	melhorias_aba.clear()

	# 1) Descobre quais melhorias fazem parte desta aba e onde cada uma fica
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

	# 2) Calcula o tamanho e centraliza o conteúdo
	var largura_conteudo := max_c * ESPACO_X + TAM_NO
	var largura := maxf(largura_conteudo + MARGEM * 2.0, LARGURA_MINIMA)
	var desloc_x := (largura - largura_conteudo) / 2.0
	custom_minimum_size = Vector2(largura, MARGEM * 2.0 + max_l * ESPACO_Y + TAM_NO)

	# 3) Cria os ícones
	for m in melhorias_aba:
		var p: Vector2i = posicoes[m.id]
		var no := NoMelhoria.new()
		no.configurar(m, ArvoreLayout.icone(m), ArvoreLayout.cor(m))
		no.size = Vector2(TAM_NO, TAM_NO)
		no.position = Vector2(desloc_x + p.x * ESPACO_X, MARGEM + p.y * ESPACO_Y)
		no.clicado.connect(_on_no_clicado)
		no.entrou.connect(func(melhoria): passou_o_mouse.emit(melhoria))
		add_child(no)
		nos[m.id] = no

	atualizar()


# Reavalia o estado de todos os ícones (depois de uma compra, por exemplo)
func atualizar() -> void:
	for id in nos:
		nos[id].atualizar_estado()
	queue_redraw()


func _on_no_clicado(m: Melhoria) -> void:
	var no: Control = nos[m.id]
	if Salvamento.comprar_melhoria(m):
		no.pop()
		atualizar()
		compra_realizada.emit(m)
	else:
		no.recusar()


# As linhas ligando cada melhoria ao seu "pai" (desenhadas por baixo dos ícones)
func _draw() -> void:
	for m in melhorias_aba:
		var pai_id := ArvoreLayout.pai(m)
		if pai_id == "" or not nos.has(pai_id) or not nos.has(m.id):
			continue
		var a: Control = nos[pai_id]
		var b: Control = nos[m.id]
		var p1 := a.position + a.size / 2.0
		var p2 := b.position + b.size / 2.0
		var liberada := Salvamento.requisito_cumprido(m)
		var cor_linha := ArvoreLayout.cor(m) if liberada else Color(0.26, 0.26, 0.36)
		draw_line(p1, p2, Color(0, 0, 0, 0.55), 9.0, true)
		draw_line(p1, p2, cor_linha, 4.0, true)


# ======================================================
#  Um ícone quadrado da árvore
# ======================================================
class NoMelhoria extends Control:
	signal clicado(m: Melhoria)
	signal entrou(m: Melhoria)

	var m: Melhoria
	var icone := "estrela"
	var cor := Color.WHITE
	var estado := "bloqueado"      # bloqueado, disponivel, sem_ouro, maximo
	var sobre := false
	var tempo := 0.0


	func configurar(melhoria: Melhoria, nome_icone: String, cor_icone: Color) -> void:
		m = melhoria
		icone = nome_icone
		cor = cor_icone


	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		pivot_offset = size / 2.0
		mouse_entered.connect(_ao_entrar)
		mouse_exited.connect(_ao_sair)


	func _ao_entrar() -> void:
		sobre = true
		entrou.emit(m)
		queue_redraw()


	func _ao_sair() -> void:
		sobre = false
		queue_redraw()


	func _process(delta: float) -> void:
		tempo += delta
		if estado == "disponivel":
			queue_redraw()      # o brilho pulsa


	func atualizar_estado() -> void:
		var nivel := Salvamento.nivel_melhoria(m.id)
		if nivel >= m.nivel_max:
			estado = "maximo"
		elif not Salvamento.requisito_cumprido(m):
			estado = "bloqueado"
		elif Salvamento.ouro >= Salvamento.custo_melhoria(m):
			estado = "disponivel"
		else:
			estado = "sem_ouro"
		queue_redraw()


	func _gui_input(event: InputEvent) -> void:
		var clique := event as InputEventMouseButton
		if clique and clique.pressed and clique.button_index == MOUSE_BUTTON_LEFT:
			clicado.emit(m)


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
		var cor_icone := cor

		match estado:
			"bloqueado":
				fundo = Color(0.07, 0.07, 0.1)
				borda = Color(0.28, 0.28, 0.36)
				cor_icone = Color(0.4, 0.4, 0.5)
			"disponivel":
				fundo = fundo.lerp(cor, 0.18)
				borda = cor
			"maximo":
				fundo = fundo.lerp(Color(1.0, 0.85, 0.3), 0.22)
				borda = Color(1.0, 0.85, 0.3)
		if sobre and estado != "bloqueado":
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

		IconesArvore.desenhar(self, icone, Vector2(size.x * 0.5, size.y * 0.42), size.x * 0.34, cor_icone)

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

		# Cadeado
		if estado == "bloqueado":
			var cinza := Color(0.72, 0.72, 0.82)
			draw_rect(Rect2(size.x - 30.0, 13.0, 18.0, 14.0), cinza)
			draw_arc(Vector2(size.x - 21.0, 13.0), 6.0, PI, TAU, 10, cinza, 2.5)
