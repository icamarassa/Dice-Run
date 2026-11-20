class_name MenuPausa
extends Control
# Menu de pausa. Funciona com o jogo congelado (get_tree().paused = true).

signal continuar
signal abandonar
signal sair

var ouro_em_jogo := 0
var penalidade := 0.5
var centro: CenterContainer


# Chame ANTES de adicionar à cena
func configurar(ouro: int, perda: float) -> void:
	ouro_em_jogo = ouro
	penalidade = perda


func _ready() -> void:
	# Este menu precisa continuar funcionando enquanto o resto do jogo está pausado
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.82)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)

	centro = CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centro)

	_mostrar_principal()


# ESC fecha a pausa
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		continuar.emit()


# ---------- Ajudantes ----------

func _limpar() -> VBoxContainer:
	for filho in centro.get_children():
		centro.remove_child(filho)
		filho.queue_free()
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 16)
	coluna.alignment = BoxContainer.ALIGNMENT_CENTER
	centro.add_child(coluna)
	return coluna


func _botao(texto: String, principal := false, tamanho := Vector2(360, 56)) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = tamanho
	b.focus_mode = Control.FOCUS_NONE
	if principal:
		Estilo.botao_dourado(b, 26)
	else:
		Estilo.botao_secundario(b, 22)
	return b


# ---------- Telas ----------

func _mostrar_principal() -> void:
	var c := _limpar()
	c.add_child(Estilo.novo_label("PAUSADO", 64, Color(1.0, 0.85, 0.3), false))
	c.add_child(Estilo.novo_label("Ouro desta partida: %d" % ouro_em_jogo, 22, Color(0.85, 0.85, 0.92), false))

	var voltar := _botao("CONTINUAR", true, Vector2(360, 64))
	voltar.pressed.connect(func(): continuar.emit())
	c.add_child(voltar)

	var opcoes := _botao("OPÇÕES")
	opcoes.pressed.connect(_mostrar_opcoes)
	c.add_child(opcoes)

	var abandonar_b := _botao("ABANDONAR PARTIDA")
	abandonar_b.pressed.connect(_mostrar_confirmacao.bind(false))
	c.add_child(abandonar_b)

	var sair_b := _botao("SAIR DO JOGO")
	sair_b.pressed.connect(_mostrar_confirmacao.bind(true))
	c.add_child(sair_b)

	c.add_child(Estilo.novo_label("ESC para continuar", 16, Color(0.6, 0.6, 0.75), false))


func _mostrar_confirmacao(fechar_o_jogo: bool) -> void:
	var c := _limpar()
	var levado := roundi(ouro_em_jogo * (1.0 - penalidade))
	var perdido := ouro_em_jogo - levado

	c.add_child(Estilo.novo_label("Tem certeza?", 56, Color(0.95, 0.4, 0.35), false))
	c.add_child(Estilo.novo_label("A partida será encerrada.", 24, Color.WHITE, false))
	c.add_child(Estilo.novo_label("Você leva %d de ouro e perde %d." % [levado, perdido], 24, Color(1.0, 0.85, 0.3), false))

	var sim := _botao("SIM, SAIR DA PARTIDA", true, Vector2(380, 60))
	if fechar_o_jogo:
		sim.text = "SIM, FECHAR O JOGO"
		sim.pressed.connect(func(): sair.emit())
	else:
		sim.pressed.connect(func(): abandonar.emit())
	c.add_child(sim)

	var nao := _botao("NÃO, VOLTAR")
	nao.pressed.connect(_mostrar_principal)
	c.add_child(nao)


func _mostrar_opcoes() -> void:
	var c := _limpar()
	c.add_child(Estilo.novo_label("Opções", 56, Color.WHITE, false))

	var caixa := VBoxContainer.new()
	caixa.custom_minimum_size = Vector2(560, 0)
	caixa.add_theme_constant_override("separation", 20)
	c.add_child(caixa)

	var cheia := CheckButton.new()
	cheia.text = "Tela cheia (F11)"
	cheia.button_pressed = Salvamento.tela_cheia
	cheia.focus_mode = Control.FOCUS_NONE
	cheia.add_theme_font_size_override("font_size", 24)
	cheia.toggled.connect(_on_tela_cheia)
	caixa.add_child(cheia)

	var linha_res := HBoxContainer.new()
	linha_res.add_theme_constant_override("separation", 20)
	caixa.add_child(linha_res)
	var rotulo_res := Label.new()
	rotulo_res.text = "Resolução da janela"
	rotulo_res.add_theme_font_size_override("font_size", 24)
	rotulo_res.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha_res.add_child(rotulo_res)
	var lista_res := OptionButton.new()
	lista_res.add_theme_font_size_override("font_size", 22)
	lista_res.focus_mode = Control.FOCUS_NONE
	for r in Salvamento.RESOLUCOES:
		lista_res.add_item("%d x %d" % [r.x, r.y])
	lista_res.select(Salvamento.indice_resolucao)
	lista_res.item_selected.connect(_on_resolucao)
	linha_res.add_child(lista_res)

	var linha_vol := HBoxContainer.new()
	linha_vol.add_theme_constant_override("separation", 20)
	caixa.add_child(linha_vol)
	var rotulo_vol := Label.new()
	rotulo_vol.text = "Volume"
	rotulo_vol.add_theme_font_size_override("font_size", 24)
	rotulo_vol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha_vol.add_child(rotulo_vol)
	var barra := HSlider.new()
	barra.min_value = 0.0
	barra.max_value = 1.0
	barra.step = 0.05
	barra.value = Salvamento.volume
	barra.custom_minimum_size = Vector2(260, 28)
	barra.focus_mode = Control.FOCUS_NONE
	barra.value_changed.connect(_on_volume)
	barra.drag_ended.connect(_on_volume_solto)
	linha_vol.add_child(barra)

	var voltar := _botao("VOLTAR")
	voltar.pressed.connect(_mostrar_principal)
	c.add_child(voltar)


func _on_tela_cheia(ligado: bool) -> void:
	Salvamento.tela_cheia = ligado
	Salvamento.aplicar_opcoes()
	Salvamento.salvar()


func _on_resolucao(indice: int) -> void:
	Salvamento.indice_resolucao = indice
	Salvamento.aplicar_opcoes()
	Salvamento.salvar()


func _on_volume(valor: float) -> void:
	Salvamento.volume = valor
	Salvamento.aplicar_opcoes()


func _on_volume_solto(_mudou: bool) -> void:
	Salvamento.salvar()
