extends Node2D

const TOTAL_CASAS := 10
const TAMANHO_CASA := 64
const ESPACO := 8
const ORIGEM := Vector2(100, 300)

var dado := Dado.new()
var posicao_atual := 0
var jogo_terminou := false

@onready var tabuleiro: Node2D = $Tabuleiro
@onready var marcador: ColorRect = $Marcador
@onready var botao_rolar: Button = $UI/BotaoRolar
@onready var label_resultado: Label = $UI/LabelResultado


func _ready() -> void:
	_criar_tabuleiro()
	marcador.position = _posicao_do_marcador(0)
	botao_rolar.pressed.connect(_on_botao_rolar_pressed)


func _criar_tabuleiro() -> void:
	for i in TOTAL_CASAS:
		var casa := ColorRect.new()
		casa.size = Vector2(TAMANHO_CASA, TAMANHO_CASA)
		casa.position = ORIGEM + Vector2(i * (TAMANHO_CASA + ESPACO), 0)
		casa.color = Color(0.3, 0.3, 0.35)
		tabuleiro.add_child(casa)


func _posicao_do_marcador(indice: int) -> Vector2:
	# Centraliza o marcador (40x40) dentro da casa (64x64)
	var margem := (TAMANHO_CASA - marcador.size.x) / 2
	return ORIGEM + Vector2(indice * (TAMANHO_CASA + ESPACO) + margem, margem)


func _on_botao_rolar_pressed() -> void:
	if jogo_terminou:
		return

	var resultado := dado.rolar()
	posicao_atual = min(posicao_atual + resultado, TOTAL_CASAS - 1)
	label_resultado.text = "Você tirou %d! Casa %d/%d" % [resultado, posicao_atual + 1, TOTAL_CASAS]

	# Anima o movimento e bloqueia o botão enquanto anda
	botao_rolar.disabled = true
	var tween := create_tween()
	tween.tween_property(marcador, "position", _posicao_do_marcador(posicao_atual), 0.3)
	await tween.finished
	botao_rolar.disabled = false

	if posicao_atual == TOTAL_CASAS - 1:
		jogo_terminou = true
		botao_rolar.disabled = true
		label_resultado.text = "Você chegou ao fim!"
