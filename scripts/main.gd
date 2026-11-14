extends Node2D

enum TipoCasa { NEUTRA, BUFF, DEBUFF }

const TOTAL_CASAS := 15	
const TAMANHO_CASA := 64
const ESPACO := 8
const ORIGEM := Vector2(100, 300)

const VIDA_MAXIMA := 10
const VALOR_CURA := 2
const VALOR_DANO := 4

const CORES := {
	TipoCasa.NEUTRA: Color(0.3, 0.3, 0.35),
	TipoCasa.BUFF: Color(0.2, 0.65, 0.3),
	TipoCasa.DEBUFF: Color(0.75, 0.2, 0.2),
}

var dado := Dado.new()
var posicao_atual := 0
var vida := VIDA_MAXIMA
var tipos_casas: Array[int] = []
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
	_criar_tabuleiro()
	marcador.position = _posicao_do_marcador(0)
	_atualizar_vida()
	botao_reiniciar.hide()
	botao_rolar.pressed.connect(_on_botao_rolar_pressed)
	botao_reiniciar.pressed.connect(_on_botao_reiniciar_pressed)


# ---------- Tabuleiro ----------

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
	var sorteio := randf()
	if sorteio < 0.25:
		return TipoCasa.BUFF
	elif sorteio < 0.5:
		return TipoCasa.DEBUFF
	return TipoCasa.NEUTRA


func _posicao_do_marcador(indice: int) -> Vector2:
	var margem := (TAMANHO_CASA - marcador.size.x) / 2
	return ORIGEM + Vector2(indice * (TAMANHO_CASA + ESPACO) + margem, margem)


# ---------- Turno ----------

func _on_botao_rolar_pressed() -> void:
	if ocupado or jogo_terminou:
		return
	ocupado = true
	botao_rolar.disabled = true

	var resultado := dado.rolar()
	label_resultado.text = "Você tirou %d!" % resultado

	# Anda casa por casa
	for i in resultado:
		if posicao_atual >= TOTAL_CASAS - 1:
			break
		posicao_atual += 1
		await _mover_um_passo(posicao_atual)

	_resolver_casa()

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


func _resolver_casa() -> void:
	var mensagem := label_resultado.text

	match tipos_casas[posicao_atual]:
		TipoCasa.BUFF:
			vida = min(vida + VALOR_CURA, VIDA_MAXIMA)
			mensagem += "\nCasa de buff! +%d PV" % VALOR_CURA
		TipoCasa.DEBUFF:
			vida = max(vida - VALOR_DANO, 0)
			mensagem += "\nCasa de debuff! -%d PV" % VALOR_DANO
			_tremer()
			_piscar()

	label_resultado.text = mensagem
	_atualizar_vida()

	if vida <= 0:
		_fim_de_jogo("Você morreu...")
	elif posicao_atual == TOTAL_CASAS - 1:
		_fim_de_jogo("Você chegou ao fim!")

# ---------- Vida e fim de jogo ----------

func _atualizar_vida() -> void:
	label_vida.text = "Vida: %d/%d" % [vida, VIDA_MAXIMA]
	barra_vida.max_value = VIDA_MAXIMA

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
