extends Node2D

signal escolha_feita

enum TipoCasa { NEUTRA, BUFF, ESPINHOS, VENENO, FOGO, ALCAPAO, GELO, BAU }

const CENA_MENU := "res://scenes/menu.tscn"

var total_casas := 15
const TAMANHO_CASA := 64
const ESPACO := 8
const ORIGEM := Vector2(36, 380)

# Metade da janela (1152x648)
const METADE_LARGURA := 576.0
const METADE_ALTURA := 324.0

const VIDA_INICIAL := 10
const DANO_BASE := 5                 # golpe mínimo
const DANO_PCT_BASE := 0.31          # os golpes também tiram uma % da vida máxima...
const DANO_PCT_POR_NIVEL := 0.028    # ...que sobe 2,8 pontos percentuais por nível
const CURA_POR_NIVEL := 0.5          # o curativo melhora 0,5 PV por nível

const CASAS_PARA_REGEN := 4
const REGEN_MAX := 2                 # a regeneração nunca passa de +2
const REGEN_BASE_POR_NIVEL := 3.0    # e cura no máximo isto (+0,3 por nível) a cada nível
const REGEN_EXTRA_POR_NIVEL := 0.3
const DESCANSO_PCT := 0.4            # ao subir de nível, você recupera 40% da vida máxima
const PENALIDADE_ABANDONO := 0.5     # quem abandona a partida perde metade do ouro

# ---------- Ouro ----------
const OURO_BAU_BASE := 8
const OURO_BAU_POR_NIVEL := 3
const OURO_POR_NIVEL_FINAL := 6      # bônus ao fim da partida, por nível alcançado
const OURO_VITORIA := 150            # bônus por zerar o jogo

# ---------- Fim do jogo ----------
const NIVEL_MAXIMO := 30
const TOTAL_CASAS_MAX := 27          # o tabuleiro para de crescer aqui (senão o nível 30 teria 73 casas)

# ---------- Geração do tabuleiro ----------
# O número de casas de cada tipo é FIXO por nível (em vez de sorteado casa a casa),
# o que evita fases impossíveis e fases fáceis demais. No nível 1: 4 perigos e 4 buffs.
const DENSIDADE_PERIGO_BASE := 0.28   # menos perigos, mas cada um pesa mais
const DENSIDADE_PERIGO_POR_NIVEL := 0.008
const DENSIDADE_PERIGO_MAX := 0.38
const DENSIDADE_BUFF_INICIAL := 0.30   # buffs ficam mais raros conforme você avança
const DENSIDADE_BUFF_FINAL := 0.20
const NIVEL_BUFF_FINAL := 15
const DENSIDADE_BAU := 0.08

# ---------- Armadilhas ----------
const MULT_FOGO := 1.5               # o fogo bate mais forte que os espinhos
const FOGO_PISO := 0.20              # ...e nunca tira menos que 20% da vida máxima
const PASSAGEM_ESPINHOS := 0.35      # passando por espinhos: 35% do dano normal
const VENENO_TURNOS := 4
const VENENO_TURNOS_MAX := 6
const VENENO_FRACAO := 0.4           # dano do veneno por turno = 40% do dano do nível
const VENENO_PISO := 0.03            # ...e nunca menos que 3% da vida máxima
const RECUO_ALCAPAO := 2

# nivel_min: nível em que a armadilha aparece pela primeira vez
# peso_ini -> peso_fim: a chance dela ser sorteada muda até o nivel_pleno
const ARMADILHAS := {
	TipoCasa.ESPINHOS: {"nome": "Espinhos", "sigla": "ESP", "cor": Color(0.75, 0.25, 0.25),
		"nivel_min": 1, "nivel_pleno": 15, "peso_ini": 100.0, "peso_fim": 30.0},
	TipoCasa.VENENO: {"nome": "Veneno", "sigla": "VEN", "cor": Color(0.55, 0.72, 0.12),
		"nivel_min": 3, "nivel_pleno": 12, "peso_ini": 25.0, "peso_fim": 60.0},
	TipoCasa.FOGO: {"nome": "Fogo", "sigla": "FOGO", "cor": Color(0.95, 0.5, 0.1),
		"nivel_min": 3, "nivel_pleno": 15, "peso_ini": 20.0, "peso_fim": 55.0},
	TipoCasa.ALCAPAO: {"nome": "Alçapão", "sigla": "QUEDA", "cor": Color(0.22, 0.22, 0.28),
		"nivel_min": 3, "nivel_pleno": 15, "peso_ini": 15.0, "peso_fim": 30.0},
	TipoCasa.GELO: {"nome": "Gelo", "sigla": "GELO", "cor": Color(0.45, 0.78, 0.95),
		"nivel_min": 5, "nivel_pleno": 18, "peso_ini": 15.0, "peso_fim": 40.0},
}

# Casas que não são armadilhas nem buffs
const CASAS_ESPECIAIS := {
	TipoCasa.BAU: {"nome": "Baú", "sigla": "BAÚ", "cor": Color(0.85, 0.62, 0.12)},
}

# ---------- Defesa ----------
# Armadura: quanto mais você acumula, menos ela rende (nunca chega a 100%)
const ARMADURA_K := 6.0
const ARMADURA_K_POR_NIVEL := 0.6
const REDUCAO_MAX := 0.6
const RESIST_MAX := 0.6

# O dado só pode evoluir para o tamanho X a partir do nível Y
const NIVEL_MIN_DADO := {4: 3, 6: 6, 8: 10, 10: 14, 12: 18, 20: 24}

const PASTA_BUFFS := "res://dados/buffs/"

# ---------- Interface ----------
const MESA_POS := Vector2(376, 76)    # mesa do dado, centralizada na tela de 1152
const DICA_POS := Vector2(0, 576)
const BARRA_POS := Vector2(74, 18)
const BARRA_TAM := Vector2(250, 28)
const SEGUNDOS_PARA_DICA := 7.0

const COR_AVISO := Color(1.0, 0.9, 0.4)
const COR_AVISO_MAL := Color(1.0, 0.5, 0.45)
const COR_AVISO_BOM := Color(0.5, 1.0, 0.6)
const COR_OURO := Color(1.0, 0.85, 0.3)
const COR_PLIM := Color(1.0, 0.9, 0.4)
const DURACAO_AVISO := 2.8

const COR_VIDA_BOA := Color(0.25, 0.8, 0.35)
const COR_VIDA_MEDIA := Color(0.95, 0.8, 0.2)
const COR_VIDA_BAIXA := Color(0.9, 0.2, 0.2)

const CORES := {
	TipoCasa.NEUTRA: Color(0.319, 0.267, 0.45, 1.0),
	TipoCasa.BUFF: Color(0.2, 0.65, 0.3),
}

# Nome e cor do "tema" mostrado no topo da tela, conforme o nível (depois serão os mundos)
const TEMAS_NIVEL := [
	{"ate": 5, "nome": "Campo de Treinamento", "cor": Color(0.6, 0.95, 0.6)},
	{"ate": 10, "nome": "Catacumbas", "cor": Color(0.95, 0.9, 0.5)},
	{"ate": 15, "nome": "Vulcão", "cor": Color(1.0, 0.6, 0.3)},
	{"ate": 20, "nome": "Tundra Congelante", "cor": Color(0.6, 0.85, 1.0)},
	{"ate": 25, "nome": "Abismo", "cor": Color(0.75, 0.5, 0.95)},
	{"ate": 999, "nome": "Trono do Dragão", "cor": Color(0.95, 0.3, 0.3)},
]

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
var classe_jogador: ClasseJogador
var cor_marcador := Color.RED
var nivel := 1
var posicao_atual := 0
var vida := VIDA_INICIAL
var vida_maxima := VIDA_INICIAL
var armadura := 0
var resist_veneno := 0.0
var resist_fogo := 0.0
var regen_valor := 0
var regen_orcamento := 0.0           # quanto a regeneração ainda pode curar neste nível
var escudo_max := 0
var escudo_cargas := 0
var escudo_temp := 0                 # bloqueios da Postura de Ferro
var veneno_turnos := 0
var veneno_dano := 0
var lentidao := 0                    # casas a menos na próxima jogada (gelo)
var bonus_movimento := 0             # casas a mais na próxima jogada (Impulso)
var ignora_passagem := false
var esquiva := 0.0                   # chance de evitar dano físico e de fogo (Ladino)
var bonus_cura := 0                  # Medicina
var veneno_menos := 0                # Sobrevivência
var descanso_pct_bonus := 0.0        # Dados de Vida
var hp_a_cada_3 := 0                 # Robustez Anã
var folego_pct := 0.0                # Retomar o Fôlego (Cavaleiro)
var folego_usado := false
var uncanny := 0.0                   # Esquiva Sobrenatural (Ladino)
var uncanny_usado := false
var meio_escudo := 0                 # próximo golpe causa metade do dano
var meio_escudo_prece := 0           # Escudo da Fé (Sacerdote)
var ignora_gelo := false
var reducao_queda := 0
var renascimentos := 0
var sorte := 0.0
var bonus_descanso := 0
var opcoes_extra := 0
var bonus_ouro := 0.0
var ouro_run := 0
var hab_usos := 0
var hab_usos_max := 0
var hab_forca := 0
var passos_totais := 0
var passos_para_escudo := 0
var tipos_casas: Array[int] = []
var todos_buffs: Array[Buff] = []
var unicos_pegos: Array[String] = []
var ocupado := false
var jogo_terminou := false
var escolha_ativa := false
var buffs_pegos := 0

# ---------- Nós criados por código ----------
var overlay_atual: ColorRect
var dado_fisico: DadoFisico
var botao_habilidade: BotaoIcone
var botao_status: BotaoIcone
var dica_ui: PainelDica
var label_hp: Label
var label_nivel: Label
var label_ouro_hud: Label
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
	Salvamento.carregar()
	_esconder_nos_antigos()
	_criar_fundo()
	_organizar_interface()
	_criar_barras()
	_criar_hud()
	_criar_painel_status()
	_criar_dado_fisico()
	_criar_avisos()
	_criar_dica()

	_carregar_buffs()
	_aplicar_classe_e_melhorias()
	_criar_botao_habilidade()
	_montar_nivel()
	botao_rolar.pressed.connect(_on_botao_rolar_pressed)

	timer_dica = Timer.new()
	timer_dica.wait_time = SEGUNDOS_PARA_DICA
	timer_dica.timeout.connect(_on_timer_dica)
	add_child(timer_dica)
	timer_dica.start()

	dado_fisico.habilitado = true
	_pulsar_botao(true)
	_mostrar_dica()


func _input(event: InputEvent) -> void:
	# F11 alterna tela cheia
	var tecla := event as InputEventKey
	if tecla and tecla.pressed and not tecla.echo and tecla.keycode == KEY_F11:
		Salvamento.tela_cheia = not Salvamento.tela_cheia
		Salvamento.aplicar_opcoes()
		Salvamento.salvar()

	# TAB mostra ou esconde a lista de modificadores
	if tecla and tecla.pressed and not tecla.echo and tecla.keycode == KEY_TAB and not get_tree().paused:
		_alternar_status()
		get_viewport().set_input_as_handled()

	# ESC abre o menu de pausa
	if event.is_action_pressed("ui_cancel") and not get_tree().paused and not jogo_terminou:
		_abrir_pausa()
		get_viewport().set_input_as_handled()


# ======================================================
#  PAUSA
# ======================================================

func _calcular_ouro_total() -> int:
	var ouro_nivel := roundi((nivel - 1) * OURO_POR_NIVEL_FINAL * (1.0 + bonus_ouro))
	return ouro_run + ouro_nivel


func _abrir_pausa() -> void:
	get_tree().paused = true      # congela tweens, timers e o dado
	var pausa := MenuPausa.new()
	pausa.configurar(_calcular_ouro_total(), PENALIDADE_ABANDONO)
	pausa.continuar.connect(_on_pausa_continuar.bind(pausa))
	pausa.abandonar.connect(_on_pausa_abandonar)
	pausa.sair.connect(_on_pausa_sair)
	$UI.add_child(pausa)


func _on_pausa_continuar(pausa: Control) -> void:
	pausa.queue_free()
	get_tree().paused = false


# Abandonar: você volta ao menu levando só parte do ouro da partida
func _encerrar_partida_abandonada() -> void:
	jogo_terminou = true
	var ouro_levado := roundi(_calcular_ouro_total() * (1.0 - PENALIDADE_ABANDONO))
	Salvamento.registrar_run(nivel, ouro_levado, false, false)
	get_tree().paused = false


func _on_pausa_abandonar() -> void:
	_encerrar_partida_abandonada()
	get_tree().change_scene_to_file(CENA_MENU)


func _on_pausa_sair() -> void:
	_encerrar_partida_abandonada()
	get_tree().quit()


# ======================================================
#  CLASSE E MELHORIAS PERMANENTES
# ======================================================

# Junta tudo que o jogador começa tendo: classe + melhorias compradas no menu
func _aplicar_classe_e_melhorias() -> void:
	var classe := Salvamento.classe(Salvamento.classe_atual)
	if classe == null and not Salvamento.todas_classes().is_empty():
		classe = Salvamento.todas_classes()[0]
	classe_jogador = classe
	var id := classe.id if classe else ""

	var vida_base := VIDA_INICIAL
	if classe:
		vida_base = classe.vida_inicial
		armadura = classe.armadura_inicial
		resist_veneno = classe.resist_veneno
		resist_fogo = classe.resist_fogo
		dado.lados = classe.dado_inicial
		dado.rerrola_ate = classe.rerrola_inicial
		cor_marcador = classe.cor
		hab_usos_max = classe.usos_habilidade
		for passiva in classe.passiva.split(",", false):
			match passiva.strip_edges():
				"regen":
					regen_valor += 1
				"pes_leves":
					ignora_passagem = true
				"esquiva":
					esquiva = 0.40
				"sorte":
					sorte += 0.05
				"gelo":
					ignora_gelo = true

	vida_maxima = vida_base + int(Salvamento.efeito_total("vida_inicial", id))
	vida = vida_maxima
	armadura += int(Salvamento.efeito_total("armadura_inicial", id))

	var elemental := Salvamento.efeito_total("resist_elemental_inicial", id) / 100.0
	resist_veneno = _somar_resist(resist_veneno, Salvamento.efeito_total("resist_veneno_inicial", id) / 100.0)
	resist_veneno = _somar_resist(resist_veneno, elemental)
	resist_fogo = _somar_resist(resist_fogo, Salvamento.efeito_total("resist_fogo_inicial", id) / 100.0)
	resist_fogo = _somar_resist(resist_fogo, elemental)

	dado.rerrola_ate += int(Salvamento.efeito_total("rerrola_inicial", id))
	sorte += Salvamento.efeito_total("sorte_inicial", id) / 100.0
	bonus_descanso += int(Salvamento.efeito_total("descanso_inicial", id))
	opcoes_extra += int(Salvamento.efeito_total("opcoes_extra_inicial", id))
	bonus_ouro = Salvamento.efeito_total("bonus_ouro", id) / 100.0
	hab_usos_max += int(Salvamento.efeito_total("habilidade_usos", id))
	hab_forca = int(Salvamento.efeito_total("habilidade_forca", id))
	hab_usos = hab_usos_max

	# Melhorias permanentes inspiradas em D&D
	bonus_cura = int(Salvamento.efeito_total("bonus_cura", id))
	veneno_menos = int(Salvamento.efeito_total("veneno_menos_turnos", id))
	reducao_queda = mini(reducao_queda + int(Salvamento.efeito_total("queda_menos", id)), RECUO_ALCAPAO - 1)
	descanso_pct_bonus = Salvamento.efeito_total("descanso_pct_extra", id) / 100.0
	hp_a_cada_3 = int(Salvamento.efeito_total("vida_a_cada_3_niveis", id))
	folego_pct = Salvamento.efeito_total("segundo_folego", id) / 100.0
	esquiva = minf(esquiva + Salvamento.efeito_total("evasao", id) / 100.0, 0.6)
	uncanny = Salvamento.efeito_total("esquiva_sobrenatural", id) / 100.0
	meio_escudo_prece = int(Salvamento.efeito_total("escudo_da_fe", id))

	marcador.color = cor_marcador


# ======================================================
#  HABILIDADE ATIVA
# ======================================================

func _criar_botao_habilidade() -> void:
	botao_habilidade = BotaoIcone.new()

	# Cada habilidade tem seu ícone
	var tipo_icone := "estrela"
	var cor_icone := Color(1.0, 0.85, 0.3)
	if classe_jogador:
		match classe_jogador.id_habilidade:
			"postura_ferro":
				tipo_icone = "escudo"
				cor_icone = Color(0.6, 0.72, 0.92)
			"impulso":
				tipo_icone = "seta"
				cor_icone = Color(0.5, 0.95, 0.6)
			"prece":
				tipo_icone = "cruz"
				cor_icone = Color(1.0, 0.9, 0.5)

	botao_habilidade.configurar(tipo_icone, cor_icone, 60.0)
	botao_habilidade.position = Vector2(663, 502)
	botao_habilidade.pressionado.connect(_usar_habilidade)
	botao_habilidade.dica_pedida.connect(_on_dica_habilidade)
	botao_habilidade.visible = classe_jogador != null
	$UI.add_child(botao_habilidade)


func _atualizar_botao_habilidade() -> void:
	if botao_habilidade == null or classe_jogador == null:
		return
	var bloqueada := ocupado or jogo_terminou or escolha_ativa
	botao_habilidade.atualizar(bloqueada or hab_usos <= 0, hab_usos, hab_usos > 0 and not bloqueada)


# Descrição da habilidade com os números já ajustados pelas melhorias
func _descricao_habilidade() -> String:
	match classe_jogador.id_habilidade:
		"postura_ferro":
			var texto_postura := "Bloqueia o próximo golpe sofrido."
			if hab_forca > 0:
				texto_postura += " Ao bloquear, você recupera %d PV." % (2 * hab_forca)
			return texto_postura
		"impulso":
			return "Sua próxima jogada anda +%d casas." % (2 + hab_forca)
		"prece":
			var texto := "Cura %d%% da vida máxima e remove veneno e gelo." % roundi((0.25 + 0.10 * hab_forca) * 100.0)
			if meio_escudo_prece > 0:
				texto += " O próximo golpe causa metade do dano."
			return texto
	return classe_jogador.descricao_habilidade


func _on_dica_habilidade(mostrar: bool, no: Control) -> void:
	if not mostrar:
		dica_ui.esconder()
		return
	dica_ui.mostrar(classe_jogador.nome_habilidade, _descricao_habilidade(),
		"Usos neste nível: %d / %d" % [hab_usos, hab_usos_max],
		botao_habilidade.cor, COR_OURO, no.get_global_rect())


func _on_dica_status(mostrar: bool, no: Control) -> void:
	if not mostrar:
		dica_ui.esconder()
		return
	dica_ui.mostrar("Modificadores", "Atributos, resistências e efeitos ativos da sua partida.",
		"Clique (ou Tab) para abrir a lista", Color.WHITE, COR_OURO, no.get_global_rect())


func _usar_habilidade() -> void:
	if classe_jogador == null or ocupado or jogo_terminou or escolha_ativa or hab_usos <= 0:
		return
	hab_usos -= 1

	match classe_jogador.id_habilidade:
		"postura_ferro":
			escudo_temp += 1
			_aviso("Postura de Ferro: o próximo golpe será bloqueado!", COR_AVISO_BOM)
		"impulso":
			bonus_movimento += 2 + hab_forca
			_aviso("Impulso! Sua próxima jogada anda +%d casas." % bonus_movimento, COR_AVISO_BOM)
		"prece":
			var porcentagem := 0.25 + 0.10 * hab_forca
			var cura := maxi(int(vida_maxima * porcentagem), 1)
			vida = mini(vida + cura, vida_maxima)
			veneno_turnos = 0
			veneno_dano = 0
			lentidao = 0
			_aviso("Prece: +%d PV, e você se purificou." % cura, COR_AVISO_BOM)
			if meio_escudo_prece > 0:
				meio_escudo += meio_escudo_prece
				_aviso("Escudo da Fé: o próximo golpe causará metade do dano.", COR_AVISO_BOM)
		_:
			push_warning("Habilidade desconhecida: " + classe_jogador.id_habilidade)
	_atualizar_vida()


# ======================================================
#  INTERFACE
# ======================================================

# O LabelResultado e o BotaoReiniciar foram substituídos por avisos e pela tela de morte.
# Você pode apagá-los da cena; enquanto isso, só escondemos.
func _esconder_nos_antigos() -> void:
	for nome in ["LabelResultado", "BotaoReiniciar", "LabelVida"]:
		if $UI.has_node(nome):
			($UI.get_node(nome) as CanvasItem).hide()


func _organizar_interface() -> void:
	# Barra de ação centralizada embaixo: [ ROLAR ] [habilidade]
	botao_rolar.text = "ROLAR"
	botao_rolar.custom_minimum_size = Vector2(220, 64)
	botao_rolar.size = Vector2(220, 64)
	botao_rolar.position = Vector2(429, 500)
	botao_rolar.pivot_offset = Vector2(110, 32)
	_estilizar_botao_dourado(botao_rolar, 30)


# Estas três funções agora só repassam para o arquivo estilo.gd (usado também pelo menu)
func _estilizar_botao_dourado(botao: Button, tamanho_fonte := 28) -> void:
	Estilo.botao_dourado(botao, tamanho_fonte)


func _novo_label(texto: String, tamanho: int, cor := Color.WHITE, quebra_linha := true) -> Label:
	return Estilo.novo_label(texto, tamanho, cor, quebra_linha)


func _pulsar_botao(ativo: bool) -> void:
	if tween_botao:
		tween_botao.kill()
	botao_rolar.scale = Vector2.ONE
	if ativo:
		tween_botao = botao_rolar.create_tween().set_loops()
		tween_botao.tween_property(botao_rolar, "scale", Vector2(1.06, 1.06), 0.5).set_trans(Tween.TRANS_SINE)
		tween_botao.tween_property(botao_rolar, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)


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


# ---------- Dado, painel, avisos e dica ----------

func _criar_dado_fisico() -> void:
	dado_fisico = DadoFisico.new()
	dado_fisico.position = MESA_POS
	dado_fisico.lancado.connect(_on_dado_lancado)
	$UI.add_child(dado_fisico)


func _criar_painel_status() -> void:
	painel_status = PanelContainer.new()
	painel_status.add_theme_stylebox_override("panel", Estilo.painel(Color(0.04, 0.03, 0.09, 0.95), 12, 14))

	label_status = Label.new()
	label_status.add_theme_font_size_override("font_size", 16)
	painel_status.add_child(label_status)

	# Fica escondido: abre ao clicar no ícone de lista (ou com a tecla Tab)
	painel_status.position = Vector2(get_viewport_rect().size.x - 350.0, 78)
	painel_status.visible = false
	$UI.add_child(painel_status)


func _alternar_status() -> void:
	painel_status.visible = not painel_status.visible
	if painel_status.visible:
		_atualizar_status()


# Barra de vida com coração (canto superior esquerdo), nível no centro, ouro à direita
func _criar_hud() -> void:
	dica_ui = PainelDica.new()
	$UI.add_child(dica_ui)

	# Faixa escura no topo, que amarra todos os elementos do HUD
	var faixa := ColorRect.new()
	faixa.color = Color(0.04, 0.03, 0.09, 0.82)
	faixa.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	faixa.offset_bottom = 64.0
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(faixa)
	$UI.move_child(faixa, 0)
	var friso := ColorRect.new()
	friso.color = Color(0.6, 0.48, 0.25, 0.9)
	friso.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	friso.offset_top = 64.0
	friso.offset_bottom = 66.0
	friso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(friso)
	$UI.move_child(friso, 1)

	# Esquerda: coração + barra de vida
	var coracao := BotaoIcone.new()
	coracao.configurar("coracao", Color(0.95, 0.35, 0.42), 44.0)
	coracao.position = Vector2(22, 10)
	$UI.add_child(coracao)
	coracao.mouse_filter = Control.MOUSE_FILTER_IGNORE      # só enfeite

	label_hp = _novo_label("", 18, Color.WHITE, false)
	label_hp.add_theme_constant_override("outline_size", 5)
	label_hp.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label_hp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_hp.position = BARRA_POS
	label_hp.custom_minimum_size = BARRA_TAM
	label_hp.size = BARRA_TAM
	$UI.add_child(label_hp)

	# Centro: nível, com cor e nome do tema
	label_nivel = _novo_label("", 26, Color.WHITE, false)
	label_nivel.add_theme_constant_override("outline_size", 6)
	label_nivel.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label_nivel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label_nivel.offset_top = 14.0
	label_nivel.offset_bottom = 50.0
	$UI.add_child(label_nivel)

	# Direita: [lista de modificadores] [moeda] [ouro]
	var caixa_direita := HBoxContainer.new()
	caixa_direita.add_theme_constant_override("separation", 10)
	caixa_direita.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 22)
	caixa_direita.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	caixa_direita.offset_top = 9.0
	caixa_direita.offset_bottom = 55.0
	$UI.add_child(caixa_direita)

	botao_status = BotaoIcone.new()
	botao_status.configurar("lista", Color(0.75, 0.8, 1.0), 46.0)
	botao_status.pressionado.connect(_alternar_status)
	botao_status.dica_pedida.connect(_on_dica_status)
	caixa_direita.add_child(botao_status)

	var espaco := Control.new()
	espaco.custom_minimum_size = Vector2(14, 0)
	caixa_direita.add_child(espaco)

	var moeda := BotaoIcone.new()
	moeda.configurar("moeda", Color(1.0, 0.85, 0.3), 38.0)
	moeda.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	caixa_direita.add_child(moeda)
	moeda.mouse_filter = Control.MOUSE_FILTER_IGNORE

	label_ouro_hud = _novo_label("0", 26, COR_OURO, false)
	label_ouro_hud.add_theme_constant_override("outline_size", 5)
	label_ouro_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label_ouro_hud.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_ouro_hud.custom_minimum_size = Vector2(40, 0)
	caixa_direita.add_child(label_ouro_hud)


# Fundo do jogo: degradê, estrelas e uma faixa de "chão" sob o tabuleiro
func _criar_fundo() -> void:
	var camada := CanvasLayer.new()
	camada.layer = -10
	add_child(camada)

	var gradiente := Gradient.new()
	gradiente.colors = PackedColorArray([Color(0.11, 0.08, 0.2), Color(0.04, 0.03, 0.09)])
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
	camada.add_child(fundo)

	for i in 40:
		var e := ColorRect.new()
		var lado := randf_range(2.0, 4.0)
		e.size = Vector2(lado, lado)
		e.position = Vector2(randf() * 1152.0, randf() * 648.0)
		e.color = Color(1.0, 0.9, 0.6, randf_range(0.12, 0.4))
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		camada.add_child(e)
		var t := e.create_tween().set_loops()
		t.tween_property(e, "modulate:a", 0.15, randf_range(1.5, 3.5))
		t.tween_property(e, "modulate:a", 1.0, randf_range(1.5, 3.5))

	var chao := ColorRect.new()
	chao.color = Color(0, 0, 0, 0.28)
	chao.position = Vector2(0, ORIGEM.y - 18.0)
	chao.size = Vector2(1152, TAMANHO_CASA + 36.0)
	chao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(chao)


func _tema_do_nivel() -> Dictionary:
	for tema in TEMAS_NIVEL:
		if nivel <= tema["ate"]:
			return tema
	return TEMAS_NIVEL[TEMAS_NIVEL.size() - 1]


func _atualizar_status() -> void:
	if dado_fisico:
		dado_fisico.lados = dado.lados
	_atualizar_botao_habilidade()

	var texto := ""
	if classe_jogador:
		texto += "%s\n" % classe_jogador.nome.to_upper()
	texto += "Dado: d%d\n" % dado.lados
	texto += "Vida máxima: %d\n" % vida_maxima
	texto += "Armadura: %d (-%d%% físico)\n" % [armadura, roundi(_reducao_armadura() * 100.0)]
	texto += "Resist. veneno: %d%%\n" % roundi(resist_veneno * 100.0)
	texto += "Resist. fogo: %d%%\n" % roundi(resist_fogo * 100.0)
	texto += "Regeneração: +%d a cada %d casas\n" % [regen_valor, CASAS_PARA_REGEN]
	texto += "Bônus de repetição: +%d" % dado.bonus_repeticao
	if dado.rerrola_ate > 0:
		texto += "\nRerrola se tirar até %d" % dado.rerrola_ate
	if sorte > 0.0:
		texto += "\nSorte: +%d%% cartas raras" % roundi(sorte * 100.0)
	if esquiva > 0.0:
		texto += "\nEsquiva: %d%%" % roundi(esquiva * 100.0)
	if meio_escudo > 0:
		texto += "\nProteção divina: próximo golpe pela metade"
	if renascimentos > 0:
		texto += "\nFênix: pronta"
	if escudo_max > 0:
		texto += "\nEscudo: %d/%d" % [escudo_cargas, escudo_max]
		if escudo_cargas < escudo_max:
			texto += " (recarga: %d casas)" % (_casas_para_escudo() - passos_para_escudo)
	if escudo_temp > 0:
		texto += "\nPostura: %d bloqueios" % escudo_temp
	if bonus_movimento > 0:
		texto += "\nIMPULSO: próxima jogada +%d" % bonus_movimento
	if veneno_turnos > 0:
		texto += "\nENVENENADO: -%d PV por %d turnos" % [_dano_reduzido(veneno_dano, "veneno"), veneno_turnos]
	if lentidao > 0:
		texto += "\nCONGELADO: próxima jogada -%d" % lentidao
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


# O "plim": o resultado sobe da mesa, acima do dado, e some
func _plim(casas: int) -> void:
	var texto := ("%d casa" if casas == 1 else "%d casas") % casas
	if dado.teve_bonus:
		texto += " (bônus!)"

	var l := _novo_label(texto, 34, COR_PLIM, false)
	l.custom_minimum_size = Vector2(260, 0)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	var base := MESA_POS + dado_fisico.pos
	l.position = base + Vector2(-130, -DadoFisico.RAIO - 70)
	$UI.add_child(l)

	var t := l.create_tween().set_parallel(true)
	t.tween_property(l, "position:y", l.position.y - 40.0, 0.9) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.5)
	t.chain().tween_callback(l.queue_free)


func _criar_dica() -> void:
	dica_rolar = _novo_label("Role o dado!", 34, Color(1.0, 0.85, 0.3), false)
	dica_rolar.custom_minimum_size = Vector2(1152, 0)     # ocupa a largura toda, texto centralizado
	dica_rolar.size = Vector2(1152, 44)
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
#  DANO, ARMADURA E RESISTÊNCIAS
# ======================================================

# Armadura com retorno decrescente: 0 -> 0%, e quanto mais pontos, menos cada um rende.
# O "K" sobe com o nível, então a armadura precisa crescer junto com o perigo.
func _reducao_armadura() -> float:
	var k := ARMADURA_K + ARMADURA_K_POR_NIVEL * nivel
	return minf(float(armadura) / (float(armadura) + k), REDUCAO_MAX)


func _dano_reduzido(base: int, elemento: String) -> int:
	var reducao := 0.0
	match elemento:
		"fisico":
			reducao = _reducao_armadura()
		"veneno":
			reducao = resist_veneno
		"fogo":
			reducao = resist_fogo
	return maxi(roundi(base * (1.0 - reducao)), 1)


# Resistências se somam de forma "multiplicativa": cada nova resistência só age sobre o
# dano que ainda restava. 25% + 25% dá 44% (e não 50%), e o teto é RESIST_MAX.
func _somar_resist(atual: float, novo: float) -> float:
	return minf(1.0 - (1.0 - atual) * (1.0 - novo), RESIST_MAX)


# Aplica um dano. "bloqueavel" diz se escudos e posturas podem absorvê-lo.
func _receber_dano(base: int, elemento: String, nome: String, bloqueavel := true, forte := true) -> void:
	if bloqueavel and escudo_temp > 0:
		escudo_temp -= 1
		_aviso("A Postura de Ferro bloqueou o dano de %s!" % nome, COR_AVISO_BOM)
		# Postura Firme (melhoria): bloquear também cura
		if hab_forca > 0 and classe_jogador and classe_jogador.id_habilidade == "postura_ferro":
			var cura_postura := 2 * hab_forca
			vida = mini(vida + cura_postura, vida_maxima)
			_aviso("Postura Firme: +%d PV" % cura_postura, COR_AVISO_BOM)
			_atualizar_vida()
		_atualizar_status()
		return
	if bloqueavel and escudo_cargas > 0:
		escudo_cargas -= 1
		_aviso("A Benção do Rei Arthur bloqueou o dano de %s!" % nome, COR_AVISO_BOM)
		_atualizar_status()
		return

	# Esquiva (Ladino): como um teste de Destreza bem-sucedido, evita o golpe
	if bloqueavel and esquiva > 0.0 and (elemento == "fisico" or elemento == "fogo") and randf() < esquiva:
		_aviso("Você se esquivou de %s!" % nome, COR_AVISO_BOM)
		return

	var dano := _dano_reduzido(base, elemento)
	if bloqueavel and meio_escudo > 0:
		meio_escudo -= 1
		dano = maxi(roundi(dano * 0.5), 1)
	if bloqueavel and uncanny > 0.0 and not uncanny_usado and (elemento == "fisico" or elemento == "fogo"):
		uncanny_usado = true
		dano = maxi(roundi(dano * (1.0 - uncanny)), 1)
	vida = maxi(vida - dano, 0)
	_aviso("%s! -%d PV" % [nome, dano], COR_AVISO_MAL)
	_tremer(8.0 if forte else 3.0)
	_piscar()
	_atualizar_vida()
	_checar_folego()


# Retomar o Fôlego (Cavaleiro): uma vez por nível, ao ficar com pouca vida, você se cura
func _checar_folego() -> void:
	if folego_pct > 0.0 and not folego_usado and vida > 0 and vida <= vida_maxima * 0.4:
		folego_usado = true
		var cura := maxi(roundi(vida_maxima * folego_pct), 1)
		vida = mini(vida + cura, vida_maxima)
		_aviso("Retomar o Fôlego: +%d PV!" % cura, COR_AVISO_BOM)
		_atualizar_vida()


# Devolve true se o jogo acabou. A Pena de Fênix salva uma vez.
func _checar_morte() -> bool:
	if vida <= 0 and not jogo_terminou:
		if renascimentos > 0:
			renascimentos -= 1
			vida = maxi(int(vida_maxima * 0.5), 1)
			veneno_turnos = 0
			veneno_dano = 0
			_aviso("A Pena de Fênix te trouxe de volta!", COR_AVISO_BOM)
			_atualizar_vida()
		else:
			_fim_de_jogo()
	return jogo_terminou


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


# Benção do Rei Arthur: o escudo demora mais a recarregar nas fases altas
func _casas_para_escudo() -> int:
	return 10 + nivel


# Um buff só é oferecido se fizer sentido agora
func _buff_disponivel(buff: Buff) -> bool:
	if buff.unico and buff.nome in unicos_pegos:
		return false

	match buff.id_efeito:
		"mais_lados":
			if not dado.pode_evoluir(buff.valor):
				return false
			# O dado só evolui quando o nível permite
			return nivel >= NIVEL_MIN_DADO.get(dado.proximo_lados(buff.valor), 0)
		"cura":
			return vida < vida_maxima
		"antidoto":
			return veneno_turnos > 0
		"pes_leves":
			return not ignora_passagem
		"ignora_gelo":
			return not ignora_gelo
		"reduz_queda":
			return reducao_queda < RECUO_ALCAPAO - 1    # o alçapão sempre derruba pelo menos 1 casa
		"low_regen":
			return regen_valor < REGEN_MAX
	return true


# O curativo acompanha o nível, para não ficar inútil nas fases altas
func _cura_do_buff(buff: Buff) -> int:
	return buff.valor + int((nivel - 1) * CURA_POR_NIVEL) + bonus_cura


# Descrições montadas na hora, para sempre mostrarem os números reais
func _descricao_do_buff(buff: Buff) -> String:
	match buff.id_efeito:
		"mais_lados":
			return "Seu dado evolui:\nd%d → d%d" % [dado.lados, dado.proximo_lados(buff.valor)]
		"cura":
			return "Cura %d PV" % _cura_do_buff(buff)
		"reduz_dano":
			return "Armadura +%d\n(reduz dano físico)" % buff.valor
		"resist_veneno":
			return "Resistência a veneno +%d%%" % buff.valor
		"resist_fogo":
			return "Resistência a fogo +%d%%" % buff.valor
		"resist_elemental":
			return "Resistência a veneno e fogo +%d%%" % buff.valor
		"antidoto":
			return "Remove o veneno e cura %d PV" % buff.valor
		"sorte":
			return "+%d%% de chance de cartas Raras ou melhores" % buff.valor
		"descanso":
			return "Ao subir de nível, você se cura +%d PV a mais" % buff.valor
	return buff.descricao


func _peso_raridade(raridade: String) -> float:
	var progresso := clampf(float(nivel - 1) / float(NIVEL_TETO - 1), 0.0, 1.0)
	var peso := lerpf(PESOS_INICIAIS[raridade], PESOS_NIVEL_MAX[raridade], progresso)
	# A sorte aumenta a chance de tudo que não é Comum
	if raridade != "Comum":
		peso *= 1.0 + sorte
	return peso


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
	# Máximo de 4 cards para caberem na tela
	var opcoes := _sortear_opcoes(mini(3 + opcoes_extra, 4))
	if opcoes.is_empty():
		_aviso("Nenhum buff disponível em dados/buffs", COR_AVISO_MAL)
		return

	escolha_ativa = true
	_atualizar_botao_habilidade()
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

	var etiqueta: String = info["nome"].to_upper()
	if buff.unico:
		etiqueta += " • ÚNICO"
	caixa.add_child(_novo_label(etiqueta, 16, cor))
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
	var espessura := 3
	match raridade:
		"Rara":
			espessura = 4
		"Epica":
			espessura = 5
		"Lendaria":
			espessura = 6
	# Épica e Lendária têm um brilho maior ao redor
	var brilho_forte := raridade == "Epica" or raridade == "Lendaria"
	return Estilo.estilo_card(cor, destacado, espessura, 24 if brilho_forte else 10)


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
	if buff.unico:
		unicos_pegos.append(buff.nome)

	match buff.id_efeito:
		"mais_lados":
			dado.evoluir(buff.valor)
		"bonus_repetido":
			dado.bonus_repeticao += buff.valor
		"rerrola":
			dado.rerrola_ate += buff.valor
		"cura":
			vida = mini(vida + _cura_do_buff(buff), vida_maxima)
		"reduz_dano":
			armadura += buff.valor
		"resist_veneno":
			resist_veneno = _somar_resist(resist_veneno, buff.valor / 100.0)
		"resist_fogo":
			resist_fogo = _somar_resist(resist_fogo, buff.valor / 100.0)
		"resist_elemental":
			resist_veneno = _somar_resist(resist_veneno, buff.valor / 100.0)
			resist_fogo = _somar_resist(resist_fogo, buff.valor / 100.0)
		"antidoto":
			veneno_turnos = 0
			veneno_dano = 0
			vida = mini(vida + buff.valor, vida_maxima)
		"pes_leves":
			ignora_passagem = true
		"ignora_gelo":
			ignora_gelo = true
		"reduz_queda":
			reducao_queda += buff.valor
		"fenix":
			renascimentos += buff.valor
		"sorte":
			sorte = minf(sorte + buff.valor / 100.0, 1.5)
		"descanso":
			bonus_descanso += buff.valor
		"mais_opcoes":
			opcoes_extra += buff.valor
		"low_regen":
			regen_valor = mini(regen_valor + buff.valor, REGEN_MAX)
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
	hab_usos = hab_usos_max      # a habilidade recarrega a cada nível
	regen_orcamento = REGEN_BASE_POR_NIVEL + REGEN_EXTRA_POR_NIVEL * nivel
	folego_usado = false
	uncanny_usado = false

	_criar_tabuleiro()
	marcador.position = _posicao_do_marcador(0)
	_atualizar_camera(false)
	_atualizar_vida()


func _cor_da_casa(tipo: int) -> Color:
	if ARMADILHAS.has(tipo):
		return ARMADILHAS[tipo]["cor"]
	if CASAS_ESPECIAIS.has(tipo):
		return CASAS_ESPECIAIS[tipo]["cor"]
	return CORES[tipo]


func _criar_tabuleiro() -> void:
	tipos_casas = _gerar_tipos()

	for i in total_casas:
		var tipo := tipos_casas[i]

		var casa := ColorRect.new()
		casa.size = Vector2(TAMANHO_CASA, TAMANHO_CASA)
		casa.position = ORIGEM + Vector2(i * (TAMANHO_CASA + ESPACO), 0)
		casa.color = _cor_da_casa(tipo)
		tabuleiro.add_child(casa)

		# Texto no centro da casa para diferenciar os tipos
		var sigla := ""
		var tamanho_fonte := 14
		if ARMADILHAS.has(tipo):
			sigla = ARMADILHAS[tipo]["sigla"]
		elif CASAS_ESPECIAIS.has(tipo):
			sigla = CASAS_ESPECIAIS[tipo]["sigla"]
		elif tipo == TipoCasa.BUFF:
			sigla = "+"
			tamanho_fonte = 32
		if sigla != "":
			var l := _novo_label(sigla, tamanho_fonte, Color(1, 1, 1, 0.9), false)
			l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			casa.add_child(l)


func _densidade_buff() -> float:
	var progresso := clampf(float(nivel - 1) / float(NIVEL_BUFF_FINAL - 1), 0.0, 1.0)
	return lerpf(DENSIDADE_BUFF_INICIAL, DENSIDADE_BUFF_FINAL, progresso)


func _densidade_perigo() -> float:
	return minf(
		DENSIDADE_PERIGO_BASE + DENSIDADE_PERIGO_POR_NIVEL * (nivel - 1),
		DENSIDADE_PERIGO_MAX
	)


# Monta a lista de tipos das casas com quantidades fixas (e não sorteando casa a casa)
func _gerar_tipos() -> Array[int]:
	var n := total_casas
	var interior := n - 2          # a primeira e a última casas são sempre neutras

	var tipos: Array[int] = []
	tipos.resize(n)
	tipos.fill(TipoCasa.NEUTRA)

	var indices: Array = range(1, n - 1)
	indices.shuffle()

	var qtd_buffs := roundi(interior * _densidade_buff())
	var qtd_baus := roundi(interior * DENSIDADE_BAU)
	var qtd_perigos := roundi(interior * _densidade_perigo())
	if nivel >= 3:
		qtd_perigos = maxi(qtd_perigos + randi_range(-1, 1), 0)

	# 1) Um buff garantido logo no começo do tabuleiro
	if qtd_buffs > 0:
		var cedo := randi_range(2, mini(5, n - 2))
		tipos[cedo] = TipoCasa.BUFF
		indices.erase(cedo)
		qtd_buffs -= 1

	# 2) Perigos espalhados. Até o nível 4 nunca ficam colados um no outro.
	var folga := 2 if nivel < 5 else 1
	var colocados: Array[int] = []
	for i in indices.duplicate():
		if colocados.size() >= qtd_perigos:
			break
		if i == 1:
			continue        # a casa logo depois da largada é sempre segura
		var longe := true
		for c in colocados:
			if absi(i - c) < folga:
				longe = false
				break
		if longe:
			colocados.append(i)

	for i in colocados:
		tipos[i] = _sortear_armadilha()
		indices.erase(i)

	# 3) Baús
	for i in indices.duplicate():
		if qtd_baus <= 0:
			break
		tipos[i] = TipoCasa.BAU
		indices.erase(i)
		qtd_baus -= 1

	# 4) O resto dos buffs (nunca dois colados)
	for i in indices:
		if qtd_buffs <= 0:
			break
		if tipos[i - 1] == TipoCasa.BUFF or tipos[i + 1] == TipoCasa.BUFF:
			continue
		tipos[i] = TipoCasa.BUFF
		qtd_buffs -= 1

	return tipos


# A chance de cada armadilha muda com o nível (veja ARMADILHAS)
func _peso_armadilha(tipo: int) -> float:
	var info: Dictionary = ARMADILHAS[tipo]
	if nivel < info["nivel_min"]:
		return 0.0
	var faixa := float(info["nivel_pleno"] - info["nivel_min"])
	var progresso := clampf(float(nivel - info["nivel_min"]) / maxf(faixa, 1.0), 0.0, 1.0)
	return lerpf(info["peso_ini"], info["peso_fim"], progresso)


func _sortear_armadilha() -> int:
	var total := 0.0
	for tipo in ARMADILHAS:
		total += _peso_armadilha(tipo)

	var sorteio := randf() * total
	for tipo in ARMADILHAS:
		var peso := _peso_armadilha(tipo)
		if peso <= 0.0:
			continue
		sorteio -= peso
		if sorteio <= 0.0:
			return tipo
	return TipoCasa.ESPINHOS


func _posicao_do_marcador(indice: int) -> Vector2:
	var margem := (TAMANHO_CASA - marcador.size.x) / 2
	return ORIGEM + Vector2(indice * (TAMANHO_CASA + ESPACO) + margem, margem)


func _dano_do_nivel() -> int:
	# O golpe é o maior entre um valor mínimo e uma % da vida máxima. Assim, empilhar vida
	# não resolve tudo: o que protege é armadura, resistência, esquiva e habilidades.
	var pct := DANO_PCT_BASE + DANO_PCT_POR_NIVEL * (nivel - 1)
	var bruto := maxi(DANO_BASE, roundi(vida_maxima * pct))
	return maxi(roundi(bruto * Salvamento.mult_dificuldade), 1)


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
	# O descanso é uma porcentagem da vida máxima: assim vida máxima importa de verdade
	var descanso := maxi(2, roundi(vida_maxima * (DESCANSO_PCT + descanso_pct_bonus))) + bonus_descanso
	nivel += 1
	total_casas = mini(total_casas + 2, TOTAL_CASAS_MAX)
	if hp_a_cada_3 > 0 and nivel % 3 == 0:
		vida_maxima += hp_a_cada_3     # Robustez Anã
		vida += hp_a_cada_3
	vida = mini(vida + descanso, vida_maxima)
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
	_aviso("Você descansou: +%d PV" % descanso, COR_AVISO_BOM)


# ======================================================
#  TURNO
# ======================================================

# O botão ROLAR só "joga" o dado. O resto do turno começa em _on_dado_lancado,
# que também é chamado quando o jogador solta o dado com o mouse.
func _on_botao_rolar_pressed() -> void:
	if ocupado or jogo_terminou:
		return
	dado_fisico.lancar_automatico()


func _on_dado_lancado() -> void:
	if ocupado or jogo_terminou:
		return
	ocupado = true
	botao_rolar.disabled = true
	dado_fisico.habilitado = false
	_atualizar_botao_habilidade()
	_pulsar_botao(false)
	_esconder_dica()
	timer_dica.stop()

	# A LÓGICA decide o número; o dado visual só o mostra ao pousar
	var resultado := dado.rolar()
	if dado.rerrolou:
		# 1º lançamento: o dado cai no número ruim...
		dado_fisico.definir_resultado(dado.face_descartada, false)
		await dado_fisico.pousou
		_aviso("Tirou %d... o dado rola de novo!" % dado.face_descartada, COR_AVISO)
		await get_tree().create_timer(0.6).timeout
		# ...e é jogado outra vez, agora com o número que vale
		dado_fisico.rejogar(dado.ultimo, dado.teve_bonus)
	else:
		dado_fisico.definir_resultado(dado.ultimo, dado.teve_bonus)
	await dado_fisico.pousou

	# Gelo: a jogada anda menos casas (mas sempre pelo menos 1)
	if lentidao > 0:
		resultado = maxi(resultado - lentidao, 1)
		_aviso("O gelo te atrasou: -%d casa" % lentidao, COR_AVISO_MAL)
		lentidao = 0
	# Impulso: a jogada anda mais casas
	if bonus_movimento > 0:
		resultado += bonus_movimento
		_aviso("Impulso: +%d casas!" % bonus_movimento, COR_AVISO_BOM)
		bonus_movimento = 0
	_atualizar_status()
	_plim(resultado)

	# Anda casa por casa
	for i in resultado:
		if posicao_atual >= total_casas - 1:
			break
		posicao_atual += 1
		await _mover_um_passo(posicao_atual)
		_contar_passo()

		# Casas em que você só PASSA (não é a última do movimento)
		if i < resultado - 1:
			_passar_pela_casa()
			if _checar_morte():
				break

	# Fim do movimento: resolve a casa onde parou, depois o veneno do turno
	if not _checar_morte():
		await _resolver_casa()
	if not _checar_morte():
		_aplicar_veneno()
		_checar_morte()

	if not jogo_terminou:
		ocupado = false
		botao_rolar.disabled = false
		dado_fisico.habilitado = true
		_atualizar_botao_habilidade()
		_pulsar_botao(true)
		timer_dica.start()


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
		# A regeneração tem um "orçamento" por nível, para não anular todo o dano
		var cura := mini(mini(regen_valor, vida_maxima - vida), floori(regen_orcamento))
		if cura > 0:
			vida += cura
			regen_orcamento -= cura
			_aviso("Regeneração: +%d PV" % cura, COR_AVISO_BOM)
			_atualizar_vida()

	# Escudo: conta os passos desde a última recarga (só enquanto não está cheio)
	if escudo_max > 0 and escudo_cargas < escudo_max:
		passos_para_escudo += 1
		if passos_para_escudo >= _casas_para_escudo():
			passos_para_escudo = 0
			escudo_cargas += 1
			_aviso("Benção do Rei Arthur: escudo recarregado!", COR_AVISO_BOM)
		_atualizar_status()


# Espinhos machucam um pouco até quem só passa. Escudos não gastam carga com isso.
func _passar_pela_casa() -> void:
	if tipos_casas[posicao_atual] == TipoCasa.ESPINHOS and not ignora_passagem:
		var dano := maxi(int(_dano_do_nivel() * PASSAGEM_ESPINHOS), 1)
		_receber_dano(dano, "fisico", "Espinhos (de passagem)", false, false)


func _resolver_casa() -> void:
	var tipo := tipos_casas[posicao_atual]

	if tipo == TipoCasa.ALCAPAO:
		await _cair_no_alcapao()
	else:
		_aplicar_efeito_armadilha(tipo)

	if _checar_morte():
		return

	if tipo == TipoCasa.BAU:
		_abrir_bau()

	if tipo == TipoCasa.BUFF:
		await _escolher_buff()

	if posicao_atual == total_casas - 1:
		if nivel >= NIVEL_MAXIMO:
			await _vitoria()
		else:
			await _transicao_de_nivel()


# ---------- Baú ----------

func _abrir_bau() -> void:
	var base := OURO_BAU_BASE + nivel * OURO_BAU_POR_NIVEL
	var ouro := roundi(base * randf_range(0.8, 1.3) * (1.0 + bonus_ouro))
	ouro_run += ouro
	_aviso("Baú! +%d ouro" % ouro, COR_OURO)
	_atualizar_vida()


# ---------- Efeitos das armadilhas ----------

# Efeito de pousar em uma armadilha (o alçapão é tratado à parte)
func _aplicar_efeito_armadilha(tipo: int) -> void:
	match tipo:
		TipoCasa.ESPINHOS:
			_receber_dano(_dano_do_nivel(), "fisico", "Espinhos")
		TipoCasa.FOGO:
			_receber_dano(_dano_fogo(), "fogo", "Fogo")
		TipoCasa.VENENO:
			_envenenar()
		TipoCasa.GELO:
			_congelar()


# Dano bruto do fogo e do veneno: o maior entre a conta do nível e uma % da vida máxima.
# Assim, quem empilha vida máxima continua sentindo o perigo.
func _dano_fogo() -> int:
	return maxi(int(_dano_do_nivel() * MULT_FOGO), roundi(vida_maxima * FOGO_PISO))


func _dano_veneno_base() -> int:
	return maxi(maxi(int(_dano_do_nivel() * VENENO_FRACAO), roundi(vida_maxima * VENENO_PISO)), 1)


func _envenenar() -> void:
	var base := _dano_veneno_base()
	# A resistência também encurta a duração
	var turnos := maxi(ceili(VENENO_TURNOS * (1.0 - resist_veneno)) - veneno_menos, 1)
	veneno_dano = maxi(veneno_dano, base)
	veneno_turnos = mini(veneno_turnos + turnos, VENENO_TURNOS_MAX)
	_aviso("Envenenado! -%d PV por turno (%d turnos)" % [_dano_reduzido(veneno_dano, "veneno"), veneno_turnos], COR_AVISO_MAL)
	_atualizar_status()


# Acontece no fim de cada turno. Escudos não protegem contra veneno.
func _aplicar_veneno() -> void:
	if veneno_turnos <= 0:
		return
	veneno_turnos -= 1
	_receber_dano(veneno_dano, "veneno", "Veneno", false, false)
	if veneno_turnos <= 0:
		veneno_dano = 0
		if vida > 0:
			_aviso("O veneno passou.", COR_AVISO_BOM)
		_atualizar_status()


func _congelar() -> void:
	if ignora_gelo:
		_aviso("Seus calçados térmicos te protegeram do gelo.", COR_AVISO_BOM)
		return
	lentidao = mini(lentidao + 1, 2)
	_aviso("Gelo! Sua próxima jogada anda %d casa a menos." % lentidao, COR_AVISO_MAL)
	_atualizar_status()


func _cair_no_alcapao() -> void:
	var recuo := mini(maxi(RECUO_ALCAPAO - reducao_queda, 1), posicao_atual)
	if recuo <= 0:
		_aviso("Você se segurou na corda e não caiu!", COR_AVISO_BOM)
		return
	_aviso("Alçapão! Você cai %d casas." % recuo, COR_AVISO_MAL)
	_tremer(5.0)

	posicao_atual -= recuo
	var destino := _posicao_do_marcador(posicao_atual)
	_atualizar_camera(true, destino.x)
	var t := create_tween()
	t.tween_property(marcador, "position", destino, 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t.finished

	# Se caiu em cima de outra armadilha, ela também te pega
	# (buffs, baús e outro alçapão não contam)
	var tipo := tipos_casas[posicao_atual]
	if tipo != TipoCasa.ALCAPAO and ARMADILHAS.has(tipo):
		_aviso("Você caiu em cima de: %s!" % ARMADILHAS[tipo]["nome"], COR_AVISO_MAL)
		_aplicar_efeito_armadilha(tipo)


# ======================================================
#  VIDA E FIM DE JOGO
# ======================================================

func _atualizar_vida() -> void:
	label_hp.text = "%d / %d" % [vida, vida_maxima]
	var tema := _tema_do_nivel()
	label_nivel.text = "NÍVEL %d  -  %s" % [nivel, tema["nome"]]
	label_nivel.add_theme_color_override("font_color", tema["cor"])
	label_ouro_hud.text = str(ouro_run)
	_atualizar_barras()
	_atualizar_status()


func _fim_de_jogo() -> void:
	if jogo_terminou:
		return
	jogo_terminou = true
	botao_rolar.disabled = true
	dado_fisico.habilitado = false
	_atualizar_botao_habilidade()
	_pulsar_botao(false)
	timer_dica.stop()

	# O ouro da partida vai para o seu "banco" permanente (ouro dos baús + bônus por nível)
	var ouro_total := _calcular_ouro_total()
	Salvamento.registrar_run(nivel, ouro_total)

	# Um instante para o jogador ver o golpe final
	await get_tree().create_timer(0.7).timeout

	var coluna := _criar_overlay(0.88)
	var titulo := _novo_label("VOCÊ MORREU", 64, Color(0.9, 0.2, 0.2), false)
	var detalhe := _novo_label("Você chegou ao nível %d" % nivel, 26, Color(0.85, 0.85, 0.9), false)
	var estatisticas := _novo_label("Buffs obtidos: %d" % buffs_pegos, 22, Color(0.85, 0.85, 0.9), false)
	var recompensa := _novo_label("Ouro ganho: +%d   (total: %d)" % [ouro_total, Salvamento.ouro], 28, COR_OURO, false)

	var botao := Button.new()
	botao.text = "JOGAR DE NOVO"
	botao.custom_minimum_size = Vector2(300, 70)
	botao.pivot_offset = Vector2(150, 35)
	botao.focus_mode = Control.FOCUS_NONE
	_estilizar_botao_dourado(botao, 28)
	botao.pressed.connect(_reiniciar)

	var botao_menu := Button.new()
	botao_menu.text = "MENU"
	botao_menu.custom_minimum_size = Vector2(300, 54)
	botao_menu.focus_mode = Control.FOCUS_NONE
	Estilo.botao_secundario(botao_menu, 22)
	botao_menu.pressed.connect(_ir_para_menu)

	coluna.add_child(titulo)
	coluna.add_child(detalhe)
	coluna.add_child(estatisticas)
	coluna.add_child(recompensa)
	coluna.add_child(botao)
	coluna.add_child(botao_menu)

	# Tudo aparece em sequência
	var i := 0
	for item in [titulo, detalhe, estatisticas, recompensa, botao, botao_menu]:
		item.modulate.a = 0.0
		item.create_tween().tween_property(item, "modulate:a", 1.0, 0.4).set_delay(0.2 * i)
		i += 1

	# O botão principal pulsa, igual ao ROLAR
	var pulso := botao.create_tween().set_loops()
	pulso.tween_property(botao, "scale", Vector2(1.06, 1.06), 0.5).set_trans(Tween.TRANS_SINE)
	pulso.tween_property(botao, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)


# Tela de vitória: zerou os 30 níveis
func _vitoria() -> void:
	jogo_terminou = true
	botao_rolar.disabled = true
	dado_fisico.habilitado = false
	_atualizar_botao_habilidade()
	_pulsar_botao(false)
	timer_dica.stop()

	var ouro_total := _calcular_ouro_total() + OURO_VITORIA
	Salvamento.registrar_run(nivel, ouro_total, true)

	await get_tree().create_timer(0.8).timeout

	var coluna := _criar_overlay(0.9)
	var titulo := _novo_label("VITÓRIA!", 84, COR_OURO, false)
	var detalhe := _novo_label("Você concluiu os %d níveis!" % NIVEL_MAXIMO, 32, Color.WHITE, false)
	var estatisticas := _novo_label("Buffs obtidos: %d" % buffs_pegos, 22, Color(0.85, 0.85, 0.9), false)
	var recompensa := _novo_label("Ouro ganho: +%d   (total: %d)" % [ouro_total, Salvamento.ouro], 28, COR_OURO, false)

	var botao := Button.new()
	botao.text = "JOGAR DE NOVO"
	botao.custom_minimum_size = Vector2(300, 70)
	botao.pivot_offset = Vector2(150, 35)
	botao.focus_mode = Control.FOCUS_NONE
	_estilizar_botao_dourado(botao, 28)
	botao.pressed.connect(_reiniciar)

	var botao_menu := Button.new()
	botao_menu.text = "MENU"
	botao_menu.custom_minimum_size = Vector2(300, 54)
	botao_menu.focus_mode = Control.FOCUS_NONE
	Estilo.botao_secundario(botao_menu, 22)
	botao_menu.pressed.connect(_ir_para_menu)

	for item in [titulo, detalhe, estatisticas, recompensa, botao, botao_menu]:
		coluna.add_child(item)
	var i := 0
	for item in [titulo, detalhe, estatisticas, recompensa, botao, botao_menu]:
		item.modulate.a = 0.0
		item.create_tween().tween_property(item, "modulate:a", 1.0, 0.5).set_delay(0.25 * i)
		i += 1

	var pulso := botao.create_tween().set_loops()
	pulso.tween_property(botao, "scale", Vector2(1.06, 1.06), 0.5).set_trans(Tween.TRANS_SINE)
	pulso.tween_property(botao, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)


func _reiniciar() -> void:
	get_tree().reload_current_scene()


func _ir_para_menu() -> void:
	get_tree().change_scene_to_file(CENA_MENU)


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


# O marcador pisca em branco e volta à cor da classe
func _piscar() -> void:
	marcador.color = Color.WHITE
	var tween := create_tween()
	tween.tween_property(marcador, "color", cor_marcador, 0.25)
