extends Node2D

signal escolha_feita

enum TipoCasa { NEUTRA, BUFF, DEBUFF }

var TOTAL_CASAS := 15
const TAMANHO_CASA := 64
const ESPACO := 8
const ORIGEM := Vector2(36, 300)

const VIDA_INICIAL := 10
const DANO_BASE := 4
const CHANCE_RARA := 0.15

const CASAS_PARA_REGEN := 4        # regeneração acontece a cada 4 casas andadas
const CHANCE_DEBUFF_BASE := 0.25
const CHANCE_DEBUFF_POR_NIVEL := 0.03
const CHANCE_DEBUFF_MAX := 0.45
const CHANCE_BUFF := 0.25

const PASTA_BUFFS := "res://dados/buffs/"

const CORES := {
	TipoCasa.NEUTRA: Color(0.3, 0.3, 0.35),
	TipoCasa.BUFF: Color(0.2, 0.65, 0.3),
	TipoCasa.DEBUFF: Color(0.75, 0.2, 0.2),
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
var painel_escolha: PanelContainer
var ocupado := false
var jogo_terminou := false

@onready var tabuleiro: Node2D = $Tabuleiro
@onready var marcador: ColorRect = $Marcador
@onready var botao_rolar: Button = $UI/BotaoRolar
@onready var label_resultado: Label = $UI/LabelResultado
@onready var label_vida: Label = $UI/LabelVida
@onready var botao_reiniciar: Button = $UI/BotaoReiniciar
@onready var barra_vida: ProgressBar = $UI/BarraVida


func _ready() -> void:
	randomize()
	barra_vida.position = Vector2(100, 80)
	barra_vida.size = Vector2(200, 24)
	barra_vida.show_percentage = false

	_carregar_buffs()
	_montar_nivel()
	botao_reiniciar.hide()
	botao_rolar.pressed.connect(_on_botao_rolar_pressed)
	botao_reiniciar.pressed.connect(_on_botao_reiniciar_pressed)


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


func _sortear_opcoes(quantidade := 3) -> Array[Buff]:
	var pool := todos_buffs.duplicate()
	pool.shuffle()
	var opcoes: Array[Buff] = []

	while opcoes.size() < quantidade and not pool.is_empty():
		var raridade_alvo := "Rara" if randf() < CHANCE_RARA else "Comum"
		var escolhido: Buff = null
		for b in pool:
			if b.raridade == raridade_alvo:
				escolhido = b
				break
		if escolhido == null:
			escolhido = pool[0]
		opcoes.append(escolhido)
		pool.erase(escolhido)

	return opcoes


# ---------- Tabuleiro e níveis ----------

func _montar_nivel() -> void:
	# Limpa o tabuleiro anterior, se houver
	for casa in tabuleiro.get_children():
		casa.queue_free()
	tipos_casas.clear()
	posicao_atual = 0

	_criar_tabuleiro()
	marcador.position = _posicao_do_marcador(0)
	_atualizar_vida()


func _criar_tabuleiro() -> void:
	for i in TOTAL_CASAS:
		# Primeira e última casas sempre neutras
		var tipo: int = TipoCasa.NEUTRA
		if i != 0 and i != TOTAL_CASAS - 1:
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
	vida = min(vida * 0.2, vida_maxima)
	
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

	# Troca de nível com a tela escura
	nivel += 1
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

	var resultado := dado.rolar()
	label_resultado.text = "Você tirou %d!" % resultado
	if dado.teve_bonus:
		label_resultado.text += " (bônus de repetição)"

	# Anda casa por casa
	for i in resultado:
		if posicao_atual >= TOTAL_CASAS - 1:
			break
		posicao_atual += 1
		await _mover_um_passo(posicao_atual)
		_checar_regeneracao()

	await _resolver_casa()

	if not jogo_terminou:
		ocupado = false
		botao_rolar.disabled = false


func _mover_um_passo(indice: int) -> void:
	var destino := _posicao_do_marcador(indice)
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

	if posicao_atual == TOTAL_CASAS - 1:
		await _transicao_de_nivel()


# ---------- Escolha de buff ----------

func _escolher_buff() -> void:
	var opcoes := _sortear_opcoes()
	if opcoes.is_empty():
		label_resultado.text += "\n(Nenhum buff encontrado em dados/buffs)"
		return

	painel_escolha = PanelContainer.new()
	var caixa := HBoxContainer.new()
	caixa.add_theme_constant_override("separation", 12)
	painel_escolha.add_child(caixa)

	for buff in opcoes:
		var botao := Button.new()
		botao.custom_minimum_size = Vector2(180, 120)
		botao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		botao.text = "%s\n[%s]\n\n%s" % [buff.nome, buff.raridade, buff.descricao]
		if buff.raridade == "Rara":
			botao.modulate = Color(1.0, 0.85, 0.3)
		botao.pressed.connect(_on_buff_escolhido.bind(buff))
		caixa.add_child(botao)

	$UI.add_child(painel_escolha)
	painel_escolha.position = Vector2(400, 80)

	await escolha_feita


func _on_buff_escolhido(buff: Buff) -> void:
	_aplicar_buff(buff)
	label_resultado.text += "\nEscolheu: %s" % buff.nome
	painel_escolha.queue_free()
	escolha_feita.emit()


func _aplicar_buff(buff: Buff) -> void:
	match buff.id_efeito:
		"mais_lados":
			dado.lados += buff.valor
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


func _fim_de_jogo(texto: String) -> void:
	jogo_terminou = true
	botao_rolar.disabled = true
	label_resultado.text = texto
	botao_reiniciar.show()


func _on_botao_reiniciar_pressed() -> void:
	get_tree().reload_current_scene()


# ---------- Juice ----------

func _tremer(intensidade := 8.0) -> void:
	var tween := create_tween()
	for i in 6:
		var desvio := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * intensidade
		tween.tween_property(self, "position", desvio, 0.03)
	tween.tween_property(self, "position", Vector2.ZERO, 0.03)


func _piscar() -> void:
	marcador.color = Color.WHITE
	var tween := create_tween()
	tween.tween_property(marcador, "color", Color.RED, 0.25)
