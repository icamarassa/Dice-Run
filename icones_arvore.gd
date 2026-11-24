class_name IconesArvore
extends RefCounted
# Ícones desenhados por código (formas simples). Depois podem ser trocados por imagens.


# Converte pontos de -1 a 1 em pontos na tela
static func _pontos(c: Vector2, t: float, lista: Array) -> PackedVector2Array:
	var resultado := PackedVector2Array()
	for p in lista:
		resultado.append(c + Vector2(p[0], p[1]) * t)
	return resultado


# Só pode ser chamada de dentro do _draw() do "ci"
static func desenhar(ci: CanvasItem, tipo: String, c: Vector2, t: float, cor: Color) -> void:
	var escura := cor.darkened(0.45)
	var clara := cor.lightened(0.45)

	match tipo:
		"coracao":
			ci.draw_circle(c + Vector2(-0.27, -0.18) * t, 0.33 * t, cor)
			ci.draw_circle(c + Vector2(0.27, -0.18) * t, 0.33 * t, cor)
			ci.draw_colored_polygon(_pontos(c, t, [[-0.58, -0.05], [0.58, -0.05], [0.0, 0.62]]), cor)
			ci.draw_circle(c + Vector2(-0.33, -0.27) * t, 0.09 * t, clara)

		"escudo":
			var forma := [[-0.5, -0.55], [0.5, -0.55], [0.5, 0.08], [0.0, 0.68], [-0.5, 0.08]]
			ci.draw_colored_polygon(_pontos(c, t, forma), cor)
			ci.draw_colored_polygon(_pontos(c + Vector2(0, 0.02) * t, t * 0.62, forma), escura)
			ci.draw_line(c + Vector2(0, -0.35) * t, c + Vector2(0, 0.4) * t, clara, 2.5)

		"gota":
			ci.draw_circle(c + Vector2(0, 0.2) * t, 0.4 * t, cor)
			ci.draw_colored_polygon(_pontos(c, t, [[-0.37, 0.08], [0.37, 0.08], [0.0, -0.68]]), cor)
			ci.draw_circle(c + Vector2(-0.14, 0.18) * t, 0.09 * t, clara)

		"chama":
			var forma := [[0.0, -0.68], [0.28, -0.22], [0.5, 0.1], [0.4, 0.5], [0.0, 0.68], [-0.4, 0.5], [-0.5, 0.1], [-0.28, -0.22]]
			ci.draw_colored_polygon(_pontos(c, t, forma), cor)
			ci.draw_colored_polygon(_pontos(c + Vector2(0, 0.18) * t, t * 0.5, forma), Color(1.0, 0.9, 0.4))

		"moeda":
			ci.draw_circle(c, 0.52 * t, cor)
			ci.draw_arc(c, 0.34 * t, 0.0, TAU, 24, escura, 3.0)
			ci.draw_line(c + Vector2(-0.12, 0.12) * t, c + Vector2(0.12, -0.12) * t, escura, 3.0)

		"estrela":
			var pts: Array = []
			for i in 10:
				var raio := 0.66 if i % 2 == 0 else 0.28
				var ang := -PI / 2.0 + i * PI / 5.0
				pts.append([cos(ang) * raio, sin(ang) * raio])
			ci.draw_colored_polygon(_pontos(c, t, pts), cor)

		"cruz":
			ci.draw_rect(Rect2(c + Vector2(-0.55, -0.18) * t, Vector2(1.1, 0.36) * t), cor)
			ci.draw_rect(Rect2(c + Vector2(-0.18, -0.55) * t, Vector2(0.36, 1.1) * t), cor)

		"olho":
			var cima: Array = []
			var baixo: Array = []
			for i in 9:
				var x := lerpf(-0.7, 0.7, i / 8.0)
				var y := 0.36 * (1.0 - pow(x / 0.7, 2.0))
				cima.append([x, -y])
				baixo.push_front([x, y])
			ci.draw_colored_polygon(_pontos(c, t, cima + baixo), cor)
			ci.draw_circle(c, 0.21 * t, escura)
			ci.draw_circle(c + Vector2(-0.06, -0.06) * t, 0.06 * t, clara)

		"raio":
			ci.draw_colored_polygon(_pontos(c, t, [[0.12, -0.7], [-0.38, 0.1], [-0.03, 0.1], [-0.15, 0.7], [0.4, -0.18], [0.05, -0.18]]), cor)

		"seta":
			ci.draw_colored_polygon(_pontos(c, t, [[-0.62, -0.2], [0.08, -0.2], [0.08, -0.48], [0.62, 0.0], [0.08, 0.48], [0.08, 0.2], [-0.62, 0.2]]), cor)

		"dado":
			ci.draw_rect(Rect2(c - Vector2(0.5, 0.5) * t, Vector2(1.0, 1.0) * t), cor)
			for p in [[-0.24, -0.24], [0.0, 0.0], [0.24, 0.24]]:
				ci.draw_circle(c + Vector2(p[0], p[1]) * t, 0.09 * t, escura)

		"lista":
			for i in 3:
				var y := -0.42 + i * 0.42
				ci.draw_circle(c + Vector2(-0.52, y) * t, 0.08 * t, cor)
				ci.draw_rect(Rect2(c + Vector2(-0.32, y - 0.07) * t, Vector2(0.9, 0.14) * t), cor)

		_:
			ci.draw_circle(c, 0.5 * t, cor)
