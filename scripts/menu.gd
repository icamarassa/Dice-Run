extends Control
# Menu inicial. Toda a interface é montada por código; a cena só precisa de um nó Control.

const CENA_JOGO := "res://scenes/main.tscn"
const COR_FUNDO_TOPO := Color(0.10, 0.06, 0.18)
const COR_FUNDO_BASE := Color(0.03, 0.02, 0.07)
const COR_OURO := Color(1.0, 0.85, 0.3)

var centro: CenterContainer
var label_ouro: Label
var aba_atual := ""             # "" = melhorias gerais; senão, id da classe
var rolagem_atual: ScrollContainer
var scroll_guardado := 0


func _ready() -> void:
	Salvamento.carregar()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_criar_fundo()
	_criar_estrelas()

	centro = CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centro)

	label_ouro = Estilo.novo_label("", 26, COR_OURO, false)
	label_ouro.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label_ouro.custom_minimum_size = Vector2(320, 0)
	label_ouro.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	add_child(label_ouro)

	_mostrar_principal()


# ======================================================
#  FUNDO
# ======================================================

func _criar_fundo() -> void:
	var gradiente := Gradient.new()
	gradiente.colors = PackedColorArray([COR_FUNDO_TOPO, COR_FUNDO_BASE])
	gradiente.offsets = PackedFloat32Array([0.0, 1.0])

	var textura := GradientTexture2D.new()
	textura.gradient = gradiente
	textura.fill_from = Vector2(0, 0)
	textura.fill_to = Vector2(0, 1)

	var fundo := TextureRect.new()
	fundo.texture = textura
	fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fundo.stretch_mode = TextureRect.STRETCH_SCALE
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)


# Pontinhos que piscam devagar, só para o fundo não ficar parado
func _criar_estrelas() -> void:
	var tamanho := get_viewport_rect().size
	for i in 45:
		var e := ColorRect.new()
		var lado := randf_range(2.0, 5.0)
		e.size = Vector2(lado, lado)
		e.position = Vector2(randf() * tamanho.x, randf() * tamanho.y)
		e.color = Color(1.0, 0.9, 0.6, randf_range(0.15, 0.5))
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(e)
		var t := e.create_tween().set_loops()
		t.tween_property(e, "modulate:a", 0.15, randf_range(1.5, 3.5))
		t.tween_property(e, "modulate:a", 1.0, randf_range(1.5, 3.5))


# ======================================================
#  AJUDANTES
# ======================================================

# Apaga a tela atual e devolve uma coluna nova, com um fade-in
func _limpar() -> VBoxContainer:
	for filho in centro.get_children():
		centro.remove_child(filho)
		filho.queue_free()

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 18)
	coluna.alignment = BoxContainer.ALIGNMENT_CENTER
	coluna.modulate.a = 0.0
	centro.add_child(coluna)
	coluna.create_tween().tween_property(coluna, "modulate:a", 1.0, 0.2)

	label_ouro.text = "Ouro: %d" % Salvamento.ouro
	return coluna


func _botao(texto: String, tamanho := Vector2(340, 64), principal := true) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = tamanho
	b.focus_mode = Control.FOCUS_NONE
	if principal:
		Estilo.botao_dourado(b, 28)
	else:
		Estilo.botao_secundario(b, 22)
	return b


func _espaco(altura: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, altura)
	return c


func _titulo(coluna: VBoxContainer, texto: String) -> void:
	coluna.add_child(Estilo.novo_label(texto, 48, Color.WHITE, false))


# O ouro pisca em vermelho quando falta dinheiro
func _piscar_ouro() -> void:
	label_ouro.modulate = Color(1.0, 0.3, 0.3)
	label_ouro.create_tween().tween_property(label_ouro, "modulate", Color.WHITE, 0.6)


# ======================================================
#  TELA PRINCIPAL
# ======================================================

func _mostrar_principal() -> void:
	var c := _limpar()
	c.add_child(Estilo.novo_label("JOGO DE DADOS", 84, COR_OURO, false))
	c.add_child(Estilo.novo_label("Role. Escolha. Sobreviva.", 26, Color(0.8, 0.8, 0.92), false))
	c.add_child(_espaco(24))

	var jogar := _botao("JOGAR")
	jogar.pressed.connect(_mostrar_classes)
	c.add_child(jogar)

	var melhorias := _botao("MELHORIAS", Vector2(340, 58), false)
	melhorias.pressed.connect(_abrir_melhorias)
	c.add_child(melhorias)

	var opcoes := _botao("OPÇÕES", Vector2(340, 58), false)
	opcoes.pressed.connect(_mostrar_opcoes)
	c.add_child(opcoes)

	var sair := _botao("SAIR", Vector2(340, 58), false)
	sair.pressed.connect(get_tree().quit)
	c.add_child(sair)

	if Salvamento.melhor_nivel > 0:
		c.add_child(_espaco(8))
		c.add_child(Estilo.novo_label("Melhor nível: %d" % Salvamento.melhor_nivel, 20, Color(0.7, 0.7, 0.85), false))


# ======================================================
#  ESCOLHA DE CLASSE
# ======================================================

func _mostrar_classes() -> void:
	var c := _limpar()
	_titulo(c, "Escolha sua classe")

	var classes := Salvamento.todas_classes()
	if classes.is_empty():
		c.add_child(Estilo.novo_label("Nenhuma classe encontrada em res://dados/classes/", 22, Color(1.0, 0.5, 0.45), false))
	else:
		var fileira := HBoxContainer.new()
		fileira.add_theme_constant_override("separation", 24)
		fileira.alignment = BoxContainer.ALIGNMENT_CENTER
		c.add_child(fileira)
		for classe in classes:
			fileira.add_child(_card_classe(classe))

	var voltar := _botao("VOLTAR", Vector2(240, 54), false)
	voltar.pressed.connect(_mostrar_principal)
	c.add_child(voltar)


func _card_classe(classe: ClasseJogador) -> Button:
	var liberada := Salvamento.classe_desbloqueada(classe.id)
	var cor := classe.cor if liberada else Color(0.5, 0.5, 0.56)

	var card := Button.new()
	card.custom_minimum_size = Vector2(280, 440)
	card.focus_mode = Control.FOCUS_NONE
	card.add_theme_stylebox_override("normal", Estilo.estilo_card(cor, false))
	card.add_theme_stylebox_override("hover", Estilo.estilo_card(cor, true, 5, 22))
	card.add_theme_stylebox_override("pressed", Estilo.estilo_card(cor, true))
	card.pressed.connect(_on_classe_clicada.bind(classe))

	var caixa := VBoxContainer.new()
	caixa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.add_theme_constant_override("separation", 10)
	card.add_child(caixa)

	caixa.add_child(Estilo.novo_label(classe.nome.to_upper(), 30, cor))
	caixa.add_child(Estilo.novo_label(classe.descricao, 15, Color(0.8, 0.8, 0.88)))

	var atributos := "Vida %d   Armadura %d   Dado d%d" % [classe.vida_inicial, classe.armadura_inicial, classe.dado_inicial]
	if classe.resist_veneno > 0.0 or classe.resist_fogo > 0.0:
		atributos += "\nResist. veneno %d%%   fogo %d%%" % [roundi(classe.resist_veneno * 100.0), roundi(classe.resist_fogo * 100.0)]
	caixa.add_child(Estilo.novo_label(atributos, 15, Color.WHITE))

	caixa.add_child(Estilo.novo_label(classe.passiva_descricao, 15, Color(0.6, 0.9, 0.7)))
	caixa.add_child(Estilo.novo_label("%s\n%s" % [classe.nome_habilidade, classe.descricao_habilidade], 15, COR_OURO))

	# Empurra o rodapé para baixo
	var mola := Control.new()
	mola.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mola.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.add_child(mola)

	if liberada:
		caixa.add_child(Estilo.novo_label("SELECIONAR", 22, COR_OURO, false))
	else:
		caixa.add_child(Estilo.novo_label("BLOQUEADA\nDesbloquear: %d ouro" % classe.custo_desbloqueio, 18, Color(0.85, 0.85, 0.9), false))
	return card


func _on_classe_clicada(classe: ClasseJogador) -> void:
	if Salvamento.classe_desbloqueada(classe.id):
		Salvamento.classe_atual = classe.id
		Salvamento.salvar()
		get_tree().change_scene_to_file(CENA_JOGO)
	elif Salvamento.desbloquear_classe(classe):
		_mostrar_classes()
	else:
		_piscar_ouro()


# ======================================================
#  MELHORIAS PERMANENTES
# ======================================================

func _abrir_melhorias() -> void:
	scroll_guardado = 0
	_mostrar_melhorias()


func _mostrar_melhorias() -> void:
	var c := _limpar()
	_titulo(c, "Melhorias permanentes")

	# Abas: uma geral e uma para cada classe
	var abas := HBoxContainer.new()
	abas.add_theme_constant_override("separation", 10)
	abas.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_child(abas)
	_adicionar_aba(abas, "Geral", "")
	for classe in Salvamento.todas_classes():
		_adicionar_aba(abas, classe.nome, classe.id)

	rolagem_atual = ScrollContainer.new()
	rolagem_atual.custom_minimum_size = Vector2(880, 370)
	rolagem_atual.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	c.add_child(rolagem_atual)

	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 10)
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem_atual.add_child(lista)

	var total := 0
	for m in Salvamento.todas_melhorias():
		if m.classe == aba_atual:
			lista.add_child(_linha_melhoria(m))
			total += 1
	if total == 0:
		lista.add_child(Estilo.novo_label("Nenhuma melhoria encontrada em res://dados/melhorias/", 20, Color(1.0, 0.5, 0.45), false))

	rolagem_atual.set_deferred("scroll_vertical", scroll_guardado)

	var voltar := _botao("VOLTAR", Vector2(240, 54), false)
	voltar.pressed.connect(_mostrar_principal)
	c.add_child(voltar)


func _adicionar_aba(abas: HBoxContainer, texto: String, id_classe: String) -> void:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(150, 44)
	b.focus_mode = Control.FOCUS_NONE
	if aba_atual == id_classe:
		Estilo.botao_dourado(b, 20)
	else:
		Estilo.botao_secundario(b, 20)
	b.pressed.connect(_on_aba_clicada.bind(id_classe))
	abas.add_child(b)


func _on_aba_clicada(id_classe: String) -> void:
	aba_atual = id_classe
	scroll_guardado = 0
	_mostrar_melhorias()


func _linha_melhoria(m: Melhoria) -> PanelContainer:
	var nivel := Salvamento.nivel_melhoria(m.id)
	var motivo := Salvamento.motivo_bloqueio(m)

	var painel := PanelContainer.new()
	painel.add_theme_stylebox_override("panel", Estilo.painel(Color(0.1, 0.08, 0.18, 0.92), 12, 14))

	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 16)
	painel.add_child(linha)

	var textos := VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(textos)

	var titulo := Estilo.novo_label("%s   [%d/%d]" % [m.nome, nivel, m.nivel_max], 22, Color.WHITE, false)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	textos.add_child(titulo)

	var descricao := Estilo.novo_label(m.descricao, 16, Color(0.75, 0.75, 0.85))
	descricao.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	textos.add_child(descricao)

	if motivo.begins_with("Requer"):
		var req := Estilo.novo_label(motivo, 15, Color(1.0, 0.55, 0.45))
		req.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		textos.add_child(req)

	var botao := Button.new()
	botao.custom_minimum_size = Vector2(190, 56)
	botao.focus_mode = Control.FOCUS_NONE
	Estilo.botao_dourado(botao, 20)
	if nivel >= m.nivel_max:
		botao.text = "MÁXIMO"
		botao.disabled = true
	elif motivo == "":
		botao.text = "Comprar\n%d ouro" % Salvamento.custo_melhoria(m)
	else:
		botao.text = "%d ouro" % Salvamento.custo_melhoria(m)
		botao.disabled = true
	botao.pressed.connect(_on_comprar.bind(m))
	linha.add_child(botao)
	return painel


func _on_comprar(m: Melhoria) -> void:
	if rolagem_atual:
		scroll_guardado = rolagem_atual.scroll_vertical
	if Salvamento.comprar_melhoria(m):
		_mostrar_melhorias()
	else:
		_piscar_ouro()


# ======================================================
#  OPÇÕES
# ======================================================

func _mostrar_opcoes() -> void:
	var c := _limpar()
	_titulo(c, "Opções")

	var caixa := VBoxContainer.new()
	caixa.custom_minimum_size = Vector2(560, 0)
	caixa.add_theme_constant_override("separation", 20)
	c.add_child(caixa)

	# Tela cheia
	var cheia := CheckButton.new()
	cheia.text = "Tela cheia (F11)"
	cheia.button_pressed = Salvamento.tela_cheia
	cheia.focus_mode = Control.FOCUS_NONE
	cheia.add_theme_font_size_override("font_size", 24)
	cheia.toggled.connect(_on_tela_cheia)
	caixa.add_child(cheia)

	# Resolução
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

	# Volume
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

	c.add_child(_espaco(10))

	# Ferramentas de teste (remova quando o jogo estiver pronto)
	c.add_child(Estilo.novo_label("Ferramentas de teste", 18, Color(0.6, 0.6, 0.75), false))
	var dar_ouro := _botao("Dar 500 de ouro", Vector2(300, 46), false)
	dar_ouro.pressed.connect(_on_dar_ouro)
	c.add_child(dar_ouro)
	var apagar := _botao("Apagar progresso", Vector2(300, 46), false)
	apagar.pressed.connect(_on_apagar_progresso)
	c.add_child(apagar)

	var voltar := _botao("VOLTAR", Vector2(240, 54), false)
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


func _on_dar_ouro() -> void:
	Salvamento.ouro += 500
	Salvamento.salvar()
	label_ouro.text = "Ouro: %d" % Salvamento.ouro


func _on_apagar_progresso() -> void:
	Salvamento.resetar_progresso()
	label_ouro.text = "Ouro: %d" % Salvamento.ouro
