class_name DadoFisico
extends Node2D
# Dado "2.5D": desenhado em 2D, mas com altura (z), sombra, quique e giro,
# o que dá a impressão de um objeto 3D rolando numa mesa.

signal lancado   # o jogador soltou o dado (ou clicou em ROLAR)
signal pousou    # o dado parou de vez

enum Estado { REPOUSO, SEGURANDO, VOANDO, ASSENTANDO, ALINHANDO }

const AREA := Rect2(0, 0, 400, 220)      # tamanho da mesa
const RAIO := 38.0
const GRAVIDADE := 900.0
const ELASTICIDADE := 0.7
const VEL_MAX := 1000.0
const ALTURA_SEGURANDO := 46.0
const COR_BONUS := Color(1.0, 0.85, 0.35)
const LUZ := Vector2(-0.6, -0.8)         # de onde vem a luz (cima e esquerda)

# lados do dado -> [lados do desenho, rotação inicial]
# Assim o formato muda quando o dado evolui.
const FORMAS := {
	3: [3, -PI / 2.0],
	4: [4, 0.0],
	6: [4, PI / 4.0],
	8: [6, 0.0],
	10: [8, PI / 8.0],
	12: [5, -PI / 2.0],
	20: [10, -PI / 2.0],
}

# Cada dado tem sua cor fixa
const COR_POR_LADOS := {
	3: Color(0.95, 0.95, 0.95),   # branco
	4: Color(0.25, 0.75, 0.35),   # verde
	6: Color(0.25, 0.5, 0.95),    # azul
	8: Color(0.9, 0.25, 0.25),    # vermelho
	10: Color(0.65, 0.35, 0.9),   # roxo
	12: Color(1.0, 0.6, 0.15),    # laranja
	20: Color(1.0, 0.88, 0.2),    # amarelo
}

var lados := 3:
	set(valor):
		if valor == lados:
			return
		lados = valor
		if is_node_ready():
			_esmagar()
		queue_redraw()

var habilitado := false:
	set(valor):
		habilitado = valor
		queue_redraw()

var estado := Estado.REPOUSO
var pos := AREA.get_center()   # posição no "chão" da mesa
var vel := Vector2.ZERO
var z := 0.0                   # altura do dado
var vz := 0.0
var ang := 0.0
var vang := 0.0
var esmagar := Vector2.ONE     # achatamento (squash and stretch)

var texto := "?"
var face_final := 1
var bonus := false

var vel_mouse := Vector2.ZERO
var tempo_troca := 0.0
var quicadas := 0
var tempo := 0.0
var estilo_mesa: StyleBoxFlat
var som_toc: AudioStreamPlayer


func _ready() -> void:
	som_toc = AudioStreamPlayer.new()
	som_toc.stream = preload("res://sons/dado.wav")
	add_child(som_toc)

	estilo_mesa = StyleBoxFlat.new()
	estilo_mesa.bg_color = Color(0.07, 0.06, 0.1, 0.85)
	estilo_mesa.border_color = Color(0.6, 0.48, 0.25)
	estilo_mesa.set_border_width_all(3)
	estilo_mesa.set_corner_radius_all(18)


# ======================================================
#  USO PELO main.gd
# ======================================================

# O main sorteia o número (lógica) e avisa o dado visual qual face mostrar ao pousar
func definir_resultado(face: int, com_bonus: bool) -> void:
	face_final = face
	bonus = com_bonus


# Usado pelo botão ROLAR: joga o dado sozinho
func lancar_automatico() -> void:
	if estado != Estado.REPOUSO:
		return
	var direcao := Vector2.from_angle(randf_range(-0.5, 0.5)) * randf_range(350.0, 600.0)
	if pos.x > AREA.get_center().x:
		direcao.x = -direcao.x
	_lancar(direcao)


# ======================================================
#  MOUSE
# ======================================================

func _input(event: InputEvent) -> void:
	var clique := event as InputEventMouseButton
	if clique == null or clique.button_index != MOUSE_BUTTON_LEFT:
		return

	if clique.pressed:
		if habilitado and estado == Estado.REPOUSO and _mouse_sobre_dado():
			estado = Estado.SEGURANDO
			vel_mouse = Vector2.ZERO
			bonus = false
	elif estado == Estado.SEGURANDO:
		_soltar()


func _mouse_sobre_dado() -> bool:
	var centro := pos + Vector2(0, -z)
	return get_local_mouse_position().distance_to(centro) < RAIO * 1.1


func _soltar() -> void:
	var direcao := vel_mouse
	if direcao.length() < 160.0:
		# Soltou parado: joga para um lado qualquer
		direcao = Vector2.from_angle(randf() * TAU) * randf_range(220.0, 360.0)
	_lancar(direcao.limit_length(VEL_MAX))


func _lancar(velocidade: Vector2) -> void:
	bonus = false
	vel = velocidade
	vz = randf_range(380.0, 520.0)
	vang = randf_range(10.0, 16.0) * (1.0 if randf() < 0.5 else -1.0)
	quicadas = 0
	estado = Estado.VOANDO
	# O main reage a este sinal sorteando o número e chamando definir_resultado()
	lancado.emit()


# ======================================================
#  SIMULAÇÃO
# ======================================================

func _process(delta: float) -> void:
	tempo += delta
	match estado:
		Estado.REPOUSO:
			_processar_repouso(delta)
		Estado.SEGURANDO:
			_processar_segurando(delta)
		Estado.VOANDO:
			_processar_voo(delta)
		Estado.ASSENTANDO:
			_processar_assentando(delta)
	queue_redraw()


func _processar_repouso(delta: float) -> void:
	var alvo_z := 0.0
	if habilitado:
		# Flutua de leve, chamando o jogador para pegar o dado
		alvo_z = 8.0 + sin(tempo * 3.0) * 4.0
		if _mouse_sobre_dado():
			alvo_z += 8.0
	z = lerpf(z, alvo_z, 10.0 * delta)


func _processar_segurando(delta: float) -> void:
	var alvo := _limitar(get_local_mouse_position())
	var antes := pos
	pos = pos.lerp(alvo, 1.0 - exp(-18.0 * delta))

	# Velocidade do mouse (suavizada): é ela que define a força do arremesso
	var vel_bruta := (pos - antes) / delta
	vel_mouse = vel_mouse.lerp(vel_bruta, 0.35)

	z = lerpf(z, ALTURA_SEGURANDO, 12.0 * delta)
	ang = lerp_angle(ang, clampf(vel_mouse.x * 0.0015, -0.6, 0.6), 10.0 * delta)

	# Sacudir o dado embaralha o número
	tempo_troca -= delta
	if vel_mouse.length() > 350.0 and tempo_troca <= 0.0:
		texto = str(randi_range(1, lados))
		tempo_troca = 0.06


func _processar_voo(delta: float) -> void:
	vz -= GRAVIDADE * delta
	z += vz * delta
	pos += vel * delta
	ang += vang * delta
	_quicar_nas_paredes()

	# O número troca enquanto o dado gira
	tempo_troca -= delta
	if tempo_troca <= 0.0:
		texto = str(randi_range(1, lados))
		tempo_troca = 0.07

	# Bateu no chão?
	if z <= 0.0 and vz < 0.0:
		z = 0.0
		quicadas += 1
		if quicadas >= 3 or absf(vz) < 140.0:
			_assentar()
		else:
			_tocar_som()
			vz = -vz * ELASTICIDADE
			vel *= 0.7
			vang *= 0.6
			_esmagar()


func _assentar() -> void:
	estado = Estado.ASSENTANDO
	vz = 0.0
	texto = str(face_final)
	_tocar_som()
	_esmagar()


func _processar_assentando(delta: float) -> void:
	# Desliza um pouquinho no chão até parar
	vel = vel.move_toward(Vector2.ZERO, 900.0 * delta)
	pos += vel * delta
	_quicar_nas_paredes()
	vang = move_toward(vang, 0.0, 25.0 * delta)
	ang += vang * delta

	if vel.length() < 5.0 and absf(vang) < 0.5:
		_alinhar()


func _alinhar() -> void:
	estado = Estado.ALINHANDO
	var alvo := roundf(ang / TAU) * TAU
	var t := create_tween()
	t.tween_property(self, "ang", alvo, 0.15)
	await t.finished
	ang = 0.0
	estado = Estado.REPOUSO
	pousou.emit()


func _limitar(p: Vector2) -> Vector2:
	var margem := Vector2(RAIO, RAIO)
	return p.clamp(AREA.position + margem, AREA.end - margem)


func _quicar_nas_paredes() -> void:
	var minimo := AREA.position + Vector2(RAIO, RAIO)
	var maximo := AREA.end - Vector2(RAIO, RAIO)
	if pos.x < minimo.x:
		pos.x = minimo.x
		vel.x = absf(vel.x) * 0.7
	elif pos.x > maximo.x:
		pos.x = maximo.x
		vel.x = -absf(vel.x) * 0.7
	if pos.y < minimo.y:
		pos.y = minimo.y
		vel.y = absf(vel.y) * 0.7
	elif pos.y > maximo.y:
		pos.y = maximo.y
		vel.y = -absf(vel.y) * 0.7


# Achata o dado e deixa ele voltar ao normal (squash and stretch)
func _esmagar() -> void:
	esmagar = Vector2(1.3, 0.7)
	create_tween().tween_property(self, "esmagar", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# Toca o "toc" com o tom levemente diferente a cada vez (soa menos repetitivo)
func _tocar_som() -> void:
	som_toc.pitch_scale = randf_range(0.9, 1.15)
	som_toc.play()


# ======================================================
#  DESENHO
# ======================================================

func _cor_do_dado() -> Color:
	return COR_POR_LADOS.get(lados, Color.WHITE)


func _contorno() -> PackedVector2Array:
	var forma: Array = FORMAS.get(lados, [4, PI / 4.0])
	var n: int = forma[0]
	var rotacao: float = forma[1]
	var pontos := PackedVector2Array()
	for i in n:
		pontos.append(Vector2.from_angle(rotacao + TAU * i / n) * RAIO)
	return pontos


func _draw() -> void:
	var fonte := ThemeDB.fallback_font
	var cor := _cor_do_dado()

	# Mesa
	draw_style_box(estilo_mesa, AREA)
	if habilitado and estado == Estado.REPOUSO:
		draw_string(fonte, Vector2(0, AREA.end.y - 14), "Segure o dado e arraste para lançar",
			HORIZONTAL_ALIGNMENT_CENTER, AREA.size.x, 16, Color(1, 1, 1, 0.35))

	# Sombra no chão: quanto mais alto o dado, mais fraca e maior ela fica
	var fraca := 1.0 / (1.0 + z / 80.0)
	draw_set_transform(pos + Vector2(0, RAIO * 0.75), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, RAIO * (1.0 + z / 400.0), Color(0, 0, 0, 0.4 * fraca))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Dado: quanto mais alto, maior (mais perto da "câmera")
	var centro := pos + Vector2(0, -z)
	var escala := esmagar * (1.0 + z / 300.0)

	var pontos := PackedVector2Array()
	for p in _contorno():
		pontos.append(centro + p.rotated(ang) * escala)

	# "Espessura": a mesma forma, mais escura, deslocada para baixo
	var lateral := PackedVector2Array()
	for p in pontos:
		lateral.append(p + Vector2(0, 8))
	draw_colored_polygon(lateral, cor.darkened(0.5))

	# Face de cima dividida em FACETAS (triângulos). Cada uma recebe mais ou menos
	# brilho conforme o lado para onde aponta em relação à luz: isso cria volume.
	var n := pontos.size()
	for i in n:
		var a := pontos[i]
		var b := pontos[(i + 1) % n]
		var direcao := ((a + b) / 2.0 - centro).normalized()
		var luz := direcao.dot(LUZ)
		var cor_faceta := cor
		if luz > 0.0:
			cor_faceta = cor.lightened(0.3 * luz)
		else:
			cor_faceta = cor.darkened(0.35 * -luz)
		draw_colored_polygon(PackedVector2Array([centro, a, b]), cor_faceta)

	# Contorno
	var fechado := pontos.duplicate()
	fechado.append(pontos[0])
	draw_polyline(fechado, cor.darkened(0.45), 3.0, true)

	# Número (gira junto com o dado), com contorno para ler em qualquer cor
	var cor_texto := Color(0.08, 0.08, 0.12)
	var cor_borda := Color(1, 1, 1, 0.55)
	if cor.get_luminance() < 0.45:
		cor_texto = Color.WHITE
		cor_borda = Color(0, 0, 0, 0.6)
	draw_set_transform(centro, ang, escala)
	draw_string_outline(fonte, Vector2(-40, 14), texto, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 40, 5, cor_borda)
	draw_string(fonte, Vector2(-40, 14), texto, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 40, cor_texto)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Bônus de repetição: um anel dourado em volta do dado quando ele para
	if bonus and estado == Estado.REPOUSO:
		draw_arc(centro, RAIO * 1.3, 0.0, TAU, 48, COR_BONUS, 4.0, true)
