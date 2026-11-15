extends Node2D

signal escolha_feita

enum TipoCasa { NEUTRA, BUFF, DEBUFF }

var total_casas := 15
const TAMANHO_CASA := 64
const ESPACO := 8
const ORIGEM := Vector2(36, 300)

# Metade da janela (1152x648)
const METADE_LARGURA := 576.0
const METADE_ALTURA := 324.0

const VIDA_INICIAL := 10
const DANO_BASE := 4

const CASAS_PARA_REGEN := 4
const CHANCE_DEBUFF_BASE := 0.25
const CHANCE_DEBUFF_POR_NIVEL := 0.03
const CHANCE_DEBUFF_MAX := 0.45
const CHANCE_BUFF := 0.25

const PASTA_BUFFS := "res://dados/buffs/"

# Interface
const DADO_POS := Vector2(330, 95)
const DICA_POS := Vector2(430, 100)
const COR_DADO := Color(0.95, 0.95, 0.9)
const COR_DADO_BONUS := Color(1.0, 0.85, 0.35)
const SEGUNDOS_PARA_DICA := 7.0

const CORES := {
	TipoCasa.NEUTRA: Color(0.319, 0.267, 0.45, 1.0),
	TipoCasa.BUFF: Color(0.2, 0.65, 0.3),
	TipoCasa.DEBUFF: Color(0.75, 0.2, 0.2),
}

# O "peso" define a chance relativa de cada raridade aparecer
const RARIDADES := {
	"Comum": {"nome": "Comum", "peso": 65, "cor": Color(0.72, 0.72, 0.78)},
	"Rara": {"nome": "Rara", "peso": 22, "cor": Color(0.3, 0.6, 1.0)},
	"Epica": {"nome": "Épica", "peso": 10, "cor": Color(0.72, 0.38, 0.95)},
	"Lendaria": {"nome": "Lendária", "peso": 3, "cor": Color(1.0, 0.72, 0.15)},
}

var dado := Dado.new()
var nivel := 1
var posicao_atual := 0
var vida := VIDA_INICIAL
var vida_maxima := VIDA_INICIAL
var reducao_dano := 0
var regen_valor := 0
var casas_andadas := 0
var tipos_casas: Array[int] = []
var todos_buffs: Array[Buff] = []
var ocupado := false
var jogo_terminou := false

var overlay_escolha: ColorRect
var escolha_ativa := false
var dado_visual: ColorRect
var face_dado: Label
var dica_rolar: Label
var painel_status: PanelContainer
var label_status: Label
var timer_dica: Timer
var tween_camera: Tween
var tween_dica: Tween
var tween_botao: Tween

@onready var tabuleiro: Node2D = $Tabuleiro
@onready var marcador: ColorRect = $Marcador
@onready var camera: Camera2D = $Camera2D
@onready var botao_rolar: Button = $UI/BotaoRolar
@onready var label_resultado: Label = $UI/LabelResultado
@onready var label_vida: Label = $UI/LabelVida
@onready var botao_reiniciar: Button = $UI/BotaoReiniciar
@onready var barra_vida: ProgressBar = $UI/BarraVida


func _ready() -> void:
	randomize()
	_organizar_interface()
	_criar_dado_visual()
	_criar_painel_status()
	_criar_dica()

	_carregar_buffs()
	_montar_nivel()
	botao_reiniciar.hide()
	botao_rolar.pressed.connect(_on_botao_rolar_pressed)
	botao_reiniciar.pressed.connect(_on_botao_reiniciar_pressed)

	timer_dica = Timer.new()
	timer_dica.wait_time = SEGUNDOS_PARA_DICA
	timer_dica.timeout.connect(_on_timer_dica)
	add_child(timer_dica)
	timer_dica.start()

	_pulsar_botao(true)
	_mostrar_dica()


# ---------- Interface ----------

func _organizar_interface() -> void:
	label_vida.position = Vector2(100, 20)
	barra_vida.position = Vector2(100, 50)
	barra_vida.size = Vector2(200, 24)
	barra_vida.show_percentage = false
	label_resultado.position = Vector2(100, 180)
	botao_reiniciar.position = Vector2(100, 255)

	# Botão de rolar em destaque
	botao_rolar.text = "ROLAR"
	botao_rolar.custom_minimum_size = Vector2(190, 60)
	botao_rolar.size = Vector2(190, 60)
	botao_rolar.position = Vector2(100, 95)
	botao_rolar.pivot_offset = Vector2(95, 30)
	botao_rolar.add_theme_font_size_override("font_size", 28)
	var escuro := Color(0.12, 0.08, 0.02)
	for cor_fonte in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		botao_rolar.add_theme_color_override(cor_fonte, escuro)
	botao_rolar.add_theme_stylebox_override("normal", _estilo_botao(Color(0.95, 0.7, 0.15)))
	botao_rolar.add_theme_stylebox_override("hover", _estilo_botao(Color(1.0, 0.82, 0.35)))
	botao_rolar.add_theme_stylebox_override("pressed", _estilo_botao(Color(0.8, 0.55, 0.1)))
	botao_rolar.add_theme_stylebox_override("disabled", _estilo_botao(Color(0.4, 0.4, 0.45)))


func _estilo_botao(cor: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = cor
	s.border_color = cor.lightened(0.35)
	s.set_border_width_all(3)
	s.set_corner_radius_all(12)
	s.shadow_color = Color(cor, 0.4)
	s.shadow_size = 8
	return s


func _pulsar_botao(ativo: bool) -> void:
	if tween_botao:
		tween_botao.kill()
	botao_rolar.scale = Vector2.ONE
	if ativo:
		tween_botao = botao_rolar.create_tween().set_loops()
		tween_botao.tween_property(botao_rolar, "scale", Vector2(1.06, 1.06), 0.5).set_trans(Tween.TRANS_SINE)
		tween_botao.tween_property(botao_rolar, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)


func _criar_dado_visual() -> void:
	dado_visual = ColorRect.new()
	dado_visual.size = Vector2(72, 72)
	dado_visual.pivot_offset = Vector2(36, 36)
	dado_visual.position = DADO_POS
	dado_visual.color = COR_DADO
	$UI.add_child(dado_visual)

	face_dado = Label.new()
	face_dado.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face_dado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face_dado.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	face_dado.add_theme_font_size_override("font_size", 40)
	face_dado.add_theme_color_override("font_color", Color(0.1, 0.1, 0.15))
	face_dado.text = "?"
	dado_visual.add_child(face_dado)


func _criar_painel_status() -> void:
	painel_status = PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0, 0, 0, 0.45)
	estilo.set_corner_radius_all(10)
	estilo.set_content_margin_all(12)
	painel_status.add_theme_stylebox_override("panel", estilo)

	label_status = Label.new()
	label_status.add_theme_font_size_override("font_size", 16)
	painel_status.add_child(label_status)

	painel_status.position = Vector2(850, 20)
	$UI.add_child(painel_status)


func _atualizar_status() -> void:
	var texto := "MODIFICADORES\n"
	texto += "Dado: d%d\n" % dado.lados
	texto += "Vida máxima: %d\n" % vida_maxima
	texto += "Armadura: +%d\n" % reducao_dano
	texto += "Regeneração: +%d a cada %d casas\n" % [regen_valor, CASAS_PARA_REGEN]
	texto += "Bônus de repetição: +%d" % dado.bonus_repeticao
	label_status.text = texto


func _criar_dica() -> void:
	dica_rolar = _novo_label("Role o dado!", 36, Color(1.0, 0.85, 0.3))
	dica_rolar.autowrap_mode = TextServer.AUTOWRAP_OFF
	dica_rolar.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	dica_rolar.position = DICA_POS
	dica_rolar.modulate.a = 0.0
	$UI.add_child(dica_rolar)


func _mostrar_dica() -> void:
	if tween_dica:
		tween_dica.kill()
	dica_rolar.modulate.a = 0.0
	dica_rolar.position = DICA_POS + Vector2(-20, 0)
	tween_dica = create_tween()
	tween_dica.set_parallel(true)
	tween_dica.tween_property(dica_rolar, "modulate:a", 1.0, 0.25)
	tween_dica.tween_property(dica_rolar, "position:x", DICA_POS.x, 0.25)
	tween_dica.tween_property(dica_rolar, "modulate:a", 0.0, 0.4).set_delay(1.25)


func _esconder_dica() -> void:
	if tween_dica:
		tween_dica.kill()
	dica_rolar.modulate.a = 0.0


func _on_timer_dica() -> void:
	if not ocupado and not jogo_terminou and not escolha_ativa:
		_mostrar_dica()


func _novo_label(texto: String, tamanho: int, cor := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	return l


# ---------- Dados (Resources) ----------

func _carregar_buffs() -> void:
	for arquivo in DirAccess.get_files_at(PASTA_BUFFS):
		# Em jogos exportados os arquivos ganham o sufixo .remap
		var nome := arquivo.trim_suffix(".remap")
		if nome.ends_with(".tres"):
			var recurso = load(PASTA_BUFFS + nome)
			if recurso is Buff:
				todos_buffs.append(recurso)
	print("Buffs carregados: ", todos_buffs.size())


# Um buff só é oferecido se fizer sentido agora (ex.: não existe dado maior que d20)
func _buff_disponivel(buff: Buff) -> bool:
	if buff.id_efeito == "mais_lados":
		return dado.pode_evoluir(buff.valor)
	return true


func _descricao_do_buff(buff: Buff) -> String:
	if buff.id_efeito == "mais_lados":
		return "Seu dado evolui:\nd%d → d%d" % [dado.lados, dado.proximo_lados(buff.valor)]
	return buff.descricao


func _sortear_raridade() -> String:
	var total: int = 0
	for r in RARIDADES:
		total += RARIDADES[r]["peso"]
	var sorteio := randi_range(1, total)
	for r in RARIDADES:
		sorteio -= RARIDADES[r]["peso"]
		if sorteio <= 0:
			return r
	return "Comum"


func _sortear_opcoes(quantidade := 3) -> Array[Buff]:
	var pool: Array[Buff] = []
	for b in todos_buffs:
		if _buff_disponivel(b):
			pool.append(b)
	pool.shuffle()

	var opcoes: Array[Buff] = []
	while opcoes.size() < quantidade and not pool.is_empty():
		var raridade_alvo := _sortear_raridade()
		var escolhido: Buff = null
		for b in pool:
			if b.raridade == raridade_alvo:
				escolhido = b
				break
		# Se não existe buff dessa raridade, pega qualquer um
		if escolhido == null:
			escolhido = pool[0]
		opcoes.append(escolhido)
		pool.erase(escolhido)

	return opcoes


# ---------- Tabuleiro e níveis ----------

func _montar_nivel() -> void:
	for casa in tabuleiro.get_children():
		casa.queue_free()

	tipos_casas.clear()
	posicao_atual = 0
	casas_andadas = 0

	_criar_tabuleiro()
	marcador.position = _posicao_do_marcador(0)
	_atualizar_camera(false)
	_atualizar_vida()


func _criar_tabuleiro() -> void:
	for i in total_casas:
		# Primeira e última casas sempre neutras
		var tipo: int = TipoCasa.NEUTRA
		if i != 0 and i != total_casas - 1:
			tipo = _sortear_tipo()
		tipos_casas.append(tipo)

		var casa := ColorRect.new()
		casa.size = Vector2(TAMANHO_CASA, TAMANHO_CASA)
		casa.position = ORIGEM + Vector2(i * (TAMANHO_CASA + ESPACO), 0)
		casa.color = CORES[tipo]
		tabuleiro.add_child(casa)


func _sortear_tipo() -> int:
	var chance_debuff := minf(
		CHANCE_DEBUFF_BASE + CHANCE_DEBUFF_POR_NIVEL * (nivel - 1),
		CHANCE_DEBUFF_MAX
	)
	var sorteio := randf()
	if sorteio < CHANCE_BUFF:
		return TipoCasa.BUFF
	elif sorteio < CHANCE_BUFF + chance_debuff:
		return TipoCasa.DEBUFF
	return TipoCasa.NEUTRA


func _posicao_do_marcador(indice: int) -> Vector2:
	var margem := (TAMANHO_CASA - marcador.size.x) / 2
	return ORIGEM + Vector2(indice * (TAMANHO_CASA + ESPACO) + margem, margem)


func _dano_do_nivel() -> int:
	return DANO_BASE + (nivel - 1)


func _transicao_de_nivel() -> void:
	var tela := ColorRect.new()
	tela.color = Color(0, 0, 0, 0)
	tela.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(tela)

	var titulo := Label.new()
	titulo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 56)
	titulo.modulate.a = 0.0
	tela.add_child(titulo)

	# Escurece a tela
	var t := create_tween()
	t.tween_property(tela, "color:a", 1.0, 0.5)
	await t.finished

	# Troca de nível enquanto a tela está preta
	nivel += 1
	total_casas += 2
	vida = mini(vida + 2, vida_maxima)

	_montar_nivel()

	label_resultado.text = "Nível %d! Os perigos aumentaram." % nivel
	titulo.text = "Nível %d" % nivel

	# Mostra o título e clareia a tela
	t = create_tween()
	t.tween_property(titulo, "modulate:a", 1.0, 0.4)
	t.tween_interval(0.8)
	t.tween_property(titulo, "modulate:a", 0.0, 0.3)
	t.tween_property(tela, "color:a", 0.0, 0.5)
	await t.finished

	tela.queue_free()


# ---------- Turno ----------

func _on_botao_rolar_pressed() -> void:
	if ocupado or jogo_terminou:
		return
	ocupado = true
	botao_rolar.disabled = true
	_pulsar_botao(false)
	_esconder_dica()
	timer_dica.stop()

	var resultado := dado.rolar()
	await _animar_dado()

	label_resultado.text = "Você tirou %d!" % resultado
	if dado.teve_bonus:
		label_resultado.text += " (bônus de repetição)"

	# Anda casa por casa
	for i in resultado:
		if posicao_atual >= total_casas - 1:
			break
		posicao_atual += 1
		await _mover_um_passo(posicao_atual)
		_checar_regeneracao()

	await _resolver_casa()

	if not jogo_terminou:
		ocupado = false
		botao_rolar.disabled = false
		_pulsar_botao(true)
		timer_dica.start()


func _animar_dado() -> void:
	dado_visual.color = COR_DADO

	var t := create_tween().set_parallel(true)
	t.tween_property(dado_visual, "rotation", TAU * 2.0, 0.55).from(0.0)
	t.tween_property(dado_visual, "position:y", DADO_POS.y - 45.0, 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(dado_visual, "position:y", DADO_POS.y, 0.25) \
		.set_delay(0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Troca o número várias vezes enquanto o dado gira
	t.tween_method(_face_aleatoria, 0.0, 1.0, 0.55)
	await t.finished

	dado_visual.rotation = 0.0
	face_dado.text = str(dado.ultimo)
	if dado.teve_bonus:
		dado_visual.color = COR_DADO_BONUS

	# "Pop" ao pousar
	var p := create_tween()
	p.tween_property(dado_visual, "scale", Vector2(1.35, 1.35), 0.08)
	p.tween_property(dado_visual, "scale", Vector2.ONE, 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await p.finished


func _face_aleatoria(_progresso: float) -> void:
	if randf() < 0.3:
		face_dado.text = str(randi_range(1, dado.lados))


func _mover_um_passo(indice: int) -> void:
	var destino := _posicao_do_marcador(indice)

	# A câmera começa a andar junto com o marcador
	_atualizar_camera(true, destino.x)

	var tween := create_tween()
	tween.set_parallel(true)
	# Desliza no eixo X enquanto sobe e desce no Y (o "pulinho")
	tween.tween_property(marcador, "position:x", destino.x, 0.2)
	tween.tween_property(marcador, "position:y", destino.y - 30, 0.1)
	tween.tween_property(marcador, "position:y", destino.y, 0.1).set_delay(0.1)
	await tween.finished


func _checar_regeneracao() -> void:
	casas_andadas += 1
	if regen_valor > 0 and casas_andadas % CASAS_PARA_REGEN == 0 and vida < vida_maxima:
		vida = mini(vida + regen_valor, vida_maxima)
		label_resultado.text += "\nRegeneração: +%d PV" % regen_valor
		_atualizar_vida()


func _resolver_casa() -> void:
	var tipo := tipos_casas[posicao_atual]

	if tipo == TipoCasa.DEBUFF:
		var dano := maxi(_dano_do_nivel() - reducao_dano, 1)
		vida = maxi(vida - dano, 0)
		label_resultado.text += "\nCasa de debuff! -%d PV" % dano
		_tremer()
		_piscar()
		_atualizar_vida()

	if vida <= 0:
		_fim_de_jogo("Você morreu no nível %d..." % nivel)
		return

	if tipo == TipoCasa.BUFF:
		label_resultado.text += "\nCasa de buff! Escolha uma melhoria."
		await _escolher_buff()

	if posicao_atual == total_casas - 1:
		await _transicao_de_nivel()


# ---------- Escolha de buff ----------

func _escolher_buff() -> void:
	var opcoes := _sortear_opcoes()
	if opcoes.is_empty():
		label_resultado.text += "\n(Nenhum buff disponível em dados/buffs)"
		return

	escolha_ativa = true

	# Fundo escuro cobrindo a tela inteira
	overlay_escolha = ColorRect.new()
	overlay_escolha.color = Color(0, 0, 0, 0)
	overlay_escolha.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$UI.add_child(overlay_escolha)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_escolha.add_child(centro)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 28)
	centro.add_child(coluna)

	coluna.add_child(_novo_label("Escolha uma melhoria", 40))

	var fileira := HBoxContainer.new()
	fileira.add_theme_constant_override("separation", 24)
	coluna.add_child(fileira)

	var fade := create_tween()
	fade.tween_property(overlay_escolha, "color:a", 0.82, 0.25)

	# Cards entram um depois do outro
	var i := 0
	for buff in opcoes:
		var card := _criar_card(buff)
		card.modulate.a = 0.0
		card.scale = Vector2(0.8, 0.8)
		fileira.add_child(card)
		var t := card.create_tween().set_parallel(true)
		t.tween_property(card, "modulate:a", 1.0, 0.25).set_delay(0.1 * i)
		t.tween_property(card, "scale", Vector2.ONE, 0.3).set_delay(0.1 * i) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		i += 1

	await escolha_feita


func _criar_card(buff: Buff) -> Button:
	var info: Dictionary = RARIDADES.get(buff.raridade, RARIDADES["Comum"])
	var cor: Color = info["cor"]

	var card := Button.new()
	card.custom_minimum_size = Vector2(230, 330)
	card.pivot_offset = Vector2(115, 165)
	card.focus_mode = Control.FOCUS_NONE
	card.add_theme_stylebox_override("normal", _estilo_card(cor, false, buff.raridade))
	card.add_theme_stylebox_override("hover", _estilo_card(cor, true, buff.raridade))
	card.add_theme_stylebox_override("pressed", _estilo_card(cor, true, buff.raridade))

	var caixa := VBoxContainer.new()
	caixa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.alignment = BoxContainer.ALIGNMENT_CENTER
	caixa.add_theme_constant_override("separation", 14)
	card.add_child(caixa)

	caixa.add_child(_novo_label(info["nome"].to_upper(), 16, cor))
	caixa.add_child(_novo_label(buff.nome, 26))
	caixa.add_child(_novo_label(_descricao_do_buff(buff), 18, Color(0.85, 0.85, 0.9)))

	card.pressed.connect(_on_buff_escolhido.bind(buff))
	card.mouse_entered.connect(func(): card.create_tween().tween_property(card, "scale", Vector2(1.06, 1.06), 0.1))
	card.mouse_exited.connect(func(): card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.1))

	# Lendária "respira"
	if buff.raridade == "Lendaria":
		var brilho := card.create_tween().set_loops()
		brilho.tween_property(card, "self_modulate", Color(0.72, 0.72, 0.72), 0.7)
		brilho.tween_property(card, "self_modulate", Color.WHITE, 0.7)

	return card


func _estilo_card(cor: Color, destacado: bool, raridade: String) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.09, 0.09, 0.13).lerp(cor, 0.28 if destacado else 0.14)
	s.border_color = cor

	var espessura := 3
	match raridade:
		"Rara":
			espessura = 4
		"Epica":
			espessura = 5
		"Lendaria":
			espessura = 6
	s.set_border_width_all(espessura)
	s.set_corner_radius_all(16)

	# Épica e Lendária têm um brilho maior ao redor
	var brilho_forte := raridade == "Epica" or raridade == "Lendaria"
	s.shadow_color = Color(cor, 0.55 if destacado else 0.3)
	s.shadow_size = 24 if brilho_forte else 10
	return s


func _on_buff_escolhido(buff: Buff) -> void:
	if not escolha_ativa:
		return
	escolha_ativa = false

	_aplicar_buff(buff)
	label_resultado.text += "\nEscolheu: %s" % buff.nome

	var t := create_tween()
	t.tween_property(overlay_escolha, "modulate:a", 0.0, 0.2)
	await t.finished
	overlay_escolha.queue_free()
	escolha_feita.emit()


func _aplicar_buff(buff: Buff) -> void:
	match buff.id_efeito:
		"mais_lados":
			dado.evoluir(buff.valor)
		"bonus_repetido":
			dado.bonus_repeticao += buff.valor
		"cura":
			vida = mini(vida + buff.valor, vida_maxima)
		"reduz_dano":
			reducao_dano += buff.valor
		"low_regen":
			regen_valor += buff.valor
		"low_health":
			vida_maxima += buff.valor
			vida += buff.valor
		_:
			push_warning("Efeito desconhecido: " + buff.id_efeito)
	_atualizar_vida()


# ---------- Vida e fim de jogo ----------

func _atualizar_vida() -> void:
	label_vida.text = "Nível %d   |   Vida: %d/%d   |   Dado: d%d" % [nivel, vida, vida_maxima, dado.lados]
	barra_vida.max_value = vida_maxima

	var tween := create_tween()
	tween.tween_property(barra_vida, "value", vida, 0.25)

	_atualizar_status()


func _fim_de_jogo(texto: String) -> void:
	jogo_terminou = true
	botao_rolar.disabled = true
	_pulsar_botao(false)
	timer_dica.stop()
	label_resultado.text = texto
	botao_reiniciar.show()


func _on_botao_reiniciar_pressed() -> void:
	get_tree().reload_current_scene()


# ---------- Câmera ----------

func _atualizar_camera(animado := true, x_marcador := -1.0) -> void:
	if x_marcador < 0.0:
		x_marcador = marcador.position.x

	# Limite: não mostrar espaço vazio depois do fim do tabuleiro
	var fim_do_tabuleiro := ORIGEM.x + total_casas * (TAMANHO_CASA + ESPACO)
	var alvo_x := minf(x_marcador + 200.0, fim_do_tabuleiro - METADE_LARGURA + 36.0)
	# Limite: não passar do início
	var alvo := Vector2(maxf(alvo_x, METADE_LARGURA), METADE_ALTURA)

	if tween_camera:
		tween_camera.kill()

	if animado:
		tween_camera = create_tween()
		tween_camera.tween_property(camera, "position", alvo, 0.2)
	else:
		camera.position = alvo


# ---------- Juice ----------

func _tremer(intensidade := 8.0) -> void:
	var tween := create_tween()
	for i in 6:
		var desvio := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * intensidade
		tween.tween_property(camera, "offset", desvio, 0.03)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.03)


func _piscar() -> void:
	marcador.color = Color.WHITE
	var tween := create_tween()
	tween.tween_property(marcador, "color", Color.RED, 0.25)
