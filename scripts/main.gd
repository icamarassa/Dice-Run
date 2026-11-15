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
const CURA_POR_NIVEL := 0.5          # o curativo melhora 0,5 PV por nível

const CASAS_PARA_REGEN := 4
const CASAS_PARA_ESCUDO := 10        # Benção do Rei Arthur
const CHANCE_DEBUFF_BASE := 0.25
const CHANCE_DEBUFF_POR_NIVEL := 0.03
const CHANCE_DEBUFF_MAX := 0.45
const CHANCE_BUFF := 0.25

const PASTA_BUFFS := "res://dados/buffs/"

# ---------- Interface ----------
const DADO_POS := Vector2(330, 95)
const DICA_POS := Vector2(430, 100)
const BARRA_POS := Vector2(100, 50)
const BARRA_TAM := Vector2(220, 26)
const COR_DADO := Color(0.95, 0.95, 0.9)
const COR_DADO_BONUS := Color(1.0, 0.85, 0.35)
const SEGUNDOS_PARA_DICA := 7.0

const COR_AVISO := Color(1.0, 0.9, 0.4)
const COR_AVISO_MAL := Color(1.0, 0.5, 0.45)
const COR_AVISO_BOM := Color(0.5, 1.0, 0.6)
const DURACAO_AVISO := 2.8

const COR_VIDA_BOA := Color(0.25, 0.8, 0.35)
const COR_VIDA_MEDIA := Color(0.95, 0.8, 0.2)
const COR_VIDA_BAIXA := Color(0.9, 0.2, 0.2)

const CORES := {
	TipoCasa.NEUTRA: Color(0.319, 0.267, 0.45, 1.0),
	TipoCasa.BUFF: Color(0.2, 0.65, 0.3),
	TipoCasa.DEBUFF: Color(0.75, 0.2, 0.2),
}

# ---------- Raridades ----------
const RARIDADES := {
	"Comum": {"nome": "Comum", "cor": Color(0.72, 0.72, 0.78)},
	"Rara": {"nome": "Rara", "cor": Color(0.3, 0.6, 1.0)},
	"Epica": {"nome": "Épica", "cor": Color(0.72, 0.38, 0.95)},
	"Lendaria": {"nome": "Lendária", "cor": Color(1.0, 0.72, 0.15)},
}

# Chances (pesos) no nível 1 e no nível NIVEL_TETO. Entre os dois, o jogo faz a média.
const NIVEL_TETO := 30
const PESOS_INICIAIS := {"Comum": 87.0, "Rara": 10.0, "Epica": 2.0, "Lendaria": 1.0}
const PESOS_NIVEL_MAX := {"Comum": 45.0, "Rara": 30.0, "Epica": 18.0, "Lendaria": 7.0}

# A frase mostrada é a do maior nível que já foi alcançado
const FRASES_NIVEL := {
	2: "Os perigos aumentaram...",
	3: "A batalha não é mais uma escolha, é uma obrigação.",
	5: "Não há lugar seguro",
	10: "As trevas surgem",
	15: "Tem certeza que quer continuar?",
	20: "Quando se olha para o abismo, ele te olha de volta",
	25: "Cada passo pode ser o último",
}
const COR_FRASE_INICIAL := Color(0.85, 0.85, 0.9)
const COR_FRASE_FINAL := Color(0.9, 0.15, 0.15)

# ---------- Estado do jogo ----------
var dado := Dado.new()
var nivel := 1
var posicao_atual := 0
var vida := VIDA_INICIAL
var vida_maxima := VIDA_INICIAL
var reducao_dano := 0
var regen_valor := 0
var escudo_max := 0
var escudo_cargas := 0
var passos_totais := 0
var tipos_casas: Array[int] = []
var todos_buffs: Array[Buff] = []
var ocupado := false
var jogo_terminou := false
var escolha_ativa := false
var buffs_pegos := 0

# ---------- Nós criados por código ----------
var overlay_atual: ColorRect
var dado_visual: ColorRect
var face_dado: Label
var dica_rolar: Label
var painel_status: PanelContainer
var label_status: Label
var caixa_avisos: VBoxContainer
var barra_dano: ProgressBar
var estilo_fill: StyleBoxFlat
var timer_dica: Timer
var tween_camera: Tween
var tween_dica: Tween
var tween_botao: Tween
var tween_barra: Tween

@onready var tabuleiro: Node2D = $Tabuleiro
@onready var marcador: ColorRect = $Marcador
@onready var camera: Camera2D = $Camera2D
@onready var botao_rolar: Button = $UI/BotaoRolar
@onready var label_vida: Label = $UI/LabelVida
@onready var barra_vida: ProgressBar = $UI/BarraVida


func _ready() -> void:
	randomize()
	_esconder_nos_antigos()
	_organizar_interface()
	_criar_barras()
	_criar_dado_visual()
	_criar_painel_status()
	_criar_avisos()
	_criar_dica()

	_carregar_buffs()
	_montar_nivel()
	botao_rolar.pressed.connect(_on_botao_rolar_pressed)

	timer_dica = Timer.new()
	timer_dica.wait_time = SEGUNDOS_PARA_DICA
	timer_dica.timeout.connect(_on_timer_dica)
	add_child(timer_dica)
	timer_dica.start()

	_pulsar_botao(true)
	_mostrar_dica()


# ======================================================
#  INTERFACE
# ======================================================

# O LabelResultado e o BotaoReiniciar foram substituídos por avisos e pela tela de morte.
# Você pode apagá-los da cena; enquanto isso, só escondemos.
func _esconder_nos_antigos() -> void:
	for nome in ["LabelResultado", "BotaoReiniciar"]:
		if $UI.has_node(nome):
			($UI.get_node(nome) as CanvasItem).hide()


func _organizar_interface() -> void:
	label_vida.position = Vector2(100, 20)

	botao_rolar.text = "ROLAR"
	botao_rolar.custom_minimum_size = Vector2(190, 60)
	botao_rolar.size = Vector2(190, 60)
	botao_rolar.position = Vector2(100, 95)
	botao_rolar.pivot_offset = Vector2(95, 30)
	_estilizar_botao_dourado(botao_rolar)


func _estilizar_botao_dourado(botao: Button, tamanho_fonte := 28) -> void:
	botao.add_theme_font_size_override("font_size", tamanho_fonte)
	var escuro := Color(0.12, 0.08, 0.02)
	for nome_cor in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		botao.add_theme_color_override(nome_cor, escuro)
	botao.add_theme_stylebox_override("normal", _estilo_botao(Color(0.95, 0.7, 0.15)))
	botao.add_theme_stylebox_override("hover", _estilo_botao(Color(1.0, 0.82, 0.35)))
	botao.add_theme_stylebox_override("pressed", _estilo_botao(Color(0.8, 0.55, 0.1)))
	botao.add_theme_stylebox_override("disabled", _estilo_botao(Color(0.4, 0.4, 0.45)))


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


func _novo_label(texto: String, tamanho: int, cor := Color.WHITE, quebra_linha := true) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if quebra_linha:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	return l


# Fundo escuro cobrindo a tela. Devolve a coluna central onde colocamos o conteúdo.
func _criar_overlay(opacidade := 0.82) -> VBoxContainer:
	overlay_atual = ColorRect.new()
	overlay_atual.color = Color(0, 0, 0, 0)
	overlay_atual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$UI.add_child(overlay_atual)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_atual.add_child(centro)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 28)
	centro.add_child(coluna)

	var fade := overlay_atual.create_tween()
	fade.tween_property(overlay_atual, "color:a", opacidade, 0.3)
	return coluna


# ---------- Barra de vida ----------

func _estilo_barra(cor: Color, com_borda := false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = cor
	s.set_corner_radius_all(8)
	if com_borda:
		s.border_color = Color(0.85, 0.85, 0.9, 0.9)
		s.set_border_width_all(2)
	return s


func _criar_barras() -> void:
	# Barra de TRÁS: a parte vermelha que "demora" para descer quando tomamos dano
	barra_dano = ProgressBar.new()
	barra_dano.show_percentage = false
	barra_dano.position = BARRA_POS
	barra_dano.size = BARRA_TAM
	barra_dano.add_theme_stylebox_override("background", _estilo_barra(Color(0.08, 0.06, 0.1), true))
	barra_dano.add_theme_stylebox_override("fill", _estilo_barra(Color(0.95, 0.3, 0.2)))
	$UI.add_child(barra_dano)
	$UI.move_child(barra_dano, barra_vida.get_index())

	# Barra da FRENTE: a vida de verdade (sem fundo, para a de trás aparecer)
	barra_vida.show_percentage = false
	barra_vida.position = BARRA_POS
	barra_vida.size = BARRA_TAM
	barra_vida.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	estilo_fill = _estilo_barra(COR_VIDA_BOA)
	barra_vida.add_theme_stylebox_override("fill", estilo_fill)


func _atualizar_barras() -> void:
	barra_vida.max_value = vida_maxima
	barra_dano.max_value = vida_maxima

	# A cor da barra muda conforme a vida baixa
	var proporcao := float(vida) / float(vida_maxima)
	if proporcao > 0.5:
		estilo_fill.bg_color = COR_VIDA_BOA
	elif proporcao > 0.25:
		estilo_fill.bg_color = COR_VIDA_MEDIA
	else:
		estilo_fill.bg_color = COR_VIDA_BAIXA

	if tween_barra:
		tween_barra.kill()
	tween_barra = create_tween()

	if vida < barra_vida.value:
		# Dano: o verde cai rápido, o vermelho espera um instante e "come" o resto
		tween_barra.tween_property(barra_vida, "value", vida, 0.12)
		tween_barra.tween_interval(0.35)
		tween_barra.tween_property(barra_dano, "value", vida, 0.5)
	else:
		# Cura: as duas sobem juntas
		tween_barra.set_parallel(true)
		tween_barra.tween_property(barra_vida, "value", vida, 0.25)
		tween_barra.tween_property(barra_dano, "value", vida, 0.25)


# ---------- Dado visual, painel, avisos e dica ----------

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
	if escudo_max > 0:
		texto += "\nEscudo de Arthur: %d/%d (a cada %d casas)" % [escudo_cargas, escudo_max, CASAS_PARA_ESCUDO]
	label_status.text = texto


# Avisos discretos no centro de baixo. Somem sozinhos depois de alguns segundos.
func _criar_avisos() -> void:
	caixa_avisos = VBoxContainer.new()
	caixa_avisos.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caixa_avisos.offset_bottom = -30
	caixa_avisos.alignment = BoxContainer.ALIGNMENT_END
	caixa_avisos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa_avisos.add_theme_constant_override("separation", 4)
	$UI.add_child(caixa_avisos)


func _aviso(texto: String, cor := COR_AVISO) -> void:
	var l := _novo_label(texto, 22, cor, false)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.modulate.a = 0.0
	caixa_avisos.add_child(l)

	# No máximo 4 avisos ao mesmo tempo
	while caixa_avisos.get_child_count() > 4:
		var antigo := caixa_avisos.get_child(0)
		caixa_avisos.remove_child(antigo)
		antigo.queue_free()

	var t := l.create_tween()
	t.tween_property(l, "modulate:a", 1.0, 0.15)
	t.tween_interval(DURACAO_AVISO)
	t.tween_property(l, "modulate:a", 0.0, 0.5)
	t.tween_callback(l.queue_free)


func _criar_dica() -> void:
	dica_rolar = _novo_label("Role o dado!", 36, Color(1.0, 0.85, 0.3), false)
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


# ======================================================
#  BUFFS
# ======================================================

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
	if buff.id_efeito == "cura":
		return vida < vida_maxima
	return true


# O curativo acompanha o nível, para não ficar inútil nas fases altas
func _cura_do_buff(buff: Buff) -> int:
	return buff.valor + int((nivel - 1) * CURA_POR_NIVEL)


func _descricao_do_buff(buff: Buff) -> String:
	match buff.id_efeito:
		"mais_lados":
			return "Seu dado evolui:\nd%d → d%d" % [dado.lados, dado.proximo_lados(buff.valor)]
		"cura":
			return "Cura %d PV" % _cura_do_buff(buff)
	return buff.descricao


func _peso_raridade(raridade: String) -> float:
	var progresso := clampf(float(nivel - 1) / float(NIVEL_TETO - 1), 0.0, 1.0)
	return lerpf(PESOS_INICIAIS[raridade], PESOS_NIVEL_MAX[raridade], progresso)


func _sortear_raridade() -> String:
	var total := 0.0
	for r in RARIDADES:
		total += _peso_raridade(r)
	var sorteio := randf() * total
	for r in RARIDADES:
		sorteio -= _peso_raridade(r)
		if sorteio <= 0.0:
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


func _escolher_buff() -> void:
	var opcoes := _sortear_opcoes()
	if opcoes.is_empty():
		_aviso("Nenhum buff disponível em dados/buffs", COR_AVISO_MAL)
		return

	escolha_ativa = true
	var coluna := _criar_overlay(0.82)
	coluna.add_child(_novo_label("Escolha uma melhoria", 40, Color.WHITE, false))

	var fileira := HBoxContainer.new()
	fileira.add_theme_constant_override("separation", 24)
	coluna.add_child(fileira)

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

	var t := create_tween()
	t.tween_property(overlay_atual, "modulate:a", 0.0, 0.2)
	await t.finished
	overlay_atual.queue_free()
	_aviso("Você escolheu: %s" % buff.nome)
	escolha_feita.emit()


func _aplicar_buff(buff: Buff) -> void:
	buffs_pegos += 1
	match buff.id_efeito:
		"mais_lados":
			dado.evoluir(buff.valor)
		"bonus_repetido":
			dado.bonus_repeticao += buff.valor
		"cura":
			var cura := _cura_do_buff(buff)
			vida = mini(vida + cura, vida_maxima)
		"reduz_dano":
			reducao_dano += buff.valor
		"low_regen":
			regen_valor += buff.valor
		"low_health":
			vida_maxima += buff.valor
			vida += buff.valor
		"escudo_arthur":
			escudo_max += buff.valor
			escudo_cargas += buff.valor   # já começa carregado
		_:
			push_warning("Efeito desconhecido: " + buff.id_efeito)
	_atualizar_vida()


# ======================================================
#  TABULEIRO E NÍVEIS
# ======================================================

func _montar_nivel() -> void:
	for casa in tabuleiro.get_children():
		casa.queue_free()

	tipos_casas.clear()
	posicao_atual = 0

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
	return DANO_BASE + int((nivel - 1) * 0.6)


func _frase_do_nivel(n: int) -> String:
	var frase := ""
	for nivel_minimo in FRASES_NIVEL:
		if n >= nivel_minimo:
			frase = FRASES_NIVEL[nivel_minimo]
	return frase


func _transicao_de_nivel() -> void:
	var tela := ColorRect.new()
	tela.color = Color(0, 0, 0, 0)
	tela.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(tela)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tela.add_child(centro)

	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 16)
	caixa.modulate.a = 0.0
	centro.add_child(caixa)

	var titulo := _novo_label("", 64, Color.WHITE, false)
	var subtitulo := _novo_label("", 28, Color.WHITE, false)
	caixa.add_child(titulo)
	caixa.add_child(subtitulo)

	# Escurece a tela
	var t := create_tween()
	t.tween_property(tela, "color:a", 1.0, 0.5)
	await t.finished

	# Troca de nível enquanto a tela está preta
	nivel += 1
	total_casas += 2
	vida = mini(vida + 2, vida_maxima)
	_montar_nivel()

	titulo.text = "NÍVEL %d" % nivel
	subtitulo.text = _frase_do_nivel(nivel)
	# Quanto mais fundo, mais vermelha a frase
	var profundidade := clampf(float(nivel) / float(NIVEL_TETO), 0.0, 1.0)
	subtitulo.add_theme_color_override("font_color", COR_FRASE_INICIAL.lerp(COR_FRASE_FINAL, profundidade))

	# Mostra o título e clareia a tela
	t = create_tween()
	t.tween_property(caixa, "modulate:a", 1.0, 0.4)
	t.tween_interval(1.4)
	t.tween_property(caixa, "modulate:a", 0.0, 0.3)
	t.tween_property(tela, "color:a", 0.0, 0.5)
	await t.finished

	tela.queue_free()
	_aviso("Você descansou: +2 PV", COR_AVISO_BOM)


# ======================================================
#  TURNO
# ======================================================

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

	if dado.teve_bonus:
		_aviso("Você tirou %d! (bônus de repetição)" % resultado)
	else:
		_aviso("Você tirou %d!" % resultado)

	# Anda casa por casa
	for i in resultado:
		if posicao_atual >= total_casas - 1:
			break
		posicao_atual += 1
		await _mover_um_passo(posicao_atual)
		_contar_passo()

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


# Tudo que acontece "a cada X casas" é contado aqui
func _contar_passo() -> void:
	passos_totais += 1

	if regen_valor > 0 and passos_totais % CASAS_PARA_REGEN == 0 and vida < vida_maxima:
		vida = mini(vida + regen_valor, vida_maxima)
		_aviso("Regeneração: +%d PV" % regen_valor, COR_AVISO_BOM)
		_atualizar_vida()

	if escudo_max > 0 and passos_totais % CASAS_PARA_ESCUDO == 0 and escudo_cargas < escudo_max:
		escudo_cargas += 1
		_aviso("Benção do Rei Arthur: escudo recarregado!", COR_AVISO_BOM)
		_atualizar_status()


func _resolver_casa() -> void:
	var tipo := tipos_casas[posicao_atual]

	if tipo == TipoCasa.DEBUFF:
		if escudo_cargas > 0:
			escudo_cargas -= 1
			_aviso("A Benção do Rei Arthur bloqueou o dano!", COR_AVISO_BOM)
			_atualizar_status()
		else:
			var dano := maxi(_dano_do_nivel() - reducao_dano, 1)
			vida = maxi(vida - dano, 0)
			_aviso("Casa de debuff! -%d PV" % dano, COR_AVISO_MAL)
			_tremer()
			_piscar()
			_atualizar_vida()

	if vida <= 0:
		_fim_de_jogo()
		return

	if tipo == TipoCasa.BUFF:
		await _escolher_buff()

	if posicao_atual == total_casas - 1:
		await _transicao_de_nivel()


# ======================================================
#  VIDA E FIM DE JOGO
# ======================================================

func _atualizar_vida() -> void:
	label_vida.text = "Nível %d   |   Vida: %d/%d" % [nivel, vida, vida_maxima]
	_atualizar_barras()
	_atualizar_status()


func _fim_de_jogo() -> void:
	jogo_terminou = true
	botao_rolar.disabled = true
	_pulsar_botao(false)
	timer_dica.stop()

	# Um instante para o jogador ver o golpe final
	await get_tree().create_timer(0.7).timeout

	var coluna := _criar_overlay(0.88)
	var titulo := _novo_label("VOCÊ MORREU", 64, Color(0.9, 0.2, 0.2), false)
	var detalhe := _novo_label(
	"Você chegou ao nível %d" % nivel,
	26,
	Color(0.85, 0.85, 0.9),
	false
)
	var estatisticas := _novo_label(
	"Buffs obtidos: %d" % buffs_pegos,
	22,
	Color(0.85, 0.85, 0.9),
	false
)

	var botao := Button.new()
	botao.text = "JOGAR DE NOVO"
	botao.custom_minimum_size = Vector2(300, 70)
	botao.pivot_offset = Vector2(150, 35)
	botao.focus_mode = Control.FOCUS_NONE
	_estilizar_botao_dourado(botao, 28)
	botao.pressed.connect(_reiniciar)

	coluna.add_child(titulo)
	coluna.add_child(detalhe)
	coluna.add_child(botao)
	coluna.add_child(estatisticas)

	# Os três aparecem em sequência
	var i := 0
	for item in [titulo, detalhe, botao]:
		item.modulate.a = 0.0
		item.create_tween().tween_property(item, "modulate:a", 1.0, 0.4).set_delay(0.25 * i)
		i += 1

	# O botão pulsa, igual ao ROLAR
	var pulso := botao.create_tween().set_loops()
	pulso.tween_property(botao, "scale", Vector2(1.06, 1.06), 0.5).set_trans(Tween.TRANS_SINE)
	pulso.tween_property(botao, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)


func _reiniciar() -> void:
	get_tree().reload_current_scene()


# ======================================================
#  CÂMERA E JUICE
# ======================================================

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
