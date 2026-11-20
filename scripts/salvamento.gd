class_name Salvamento
extends RefCounted
# Guarda o progresso permanente (ouro, melhorias, classes) e as opções.
# Tudo é "static": fica disponível em qualquer cena sem precisar criar um objeto.

const ARQUIVO := "user://salvamento.cfg"
const PASTA_CLASSES := "res://dados/classes/"
const PASTA_MELHORIAS := "res://dados/melhorias/"
const RESOLUCOES: Array[Vector2i] = [
	Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)
]

static var ouro := 0
static var melhorias := {}                       # id da melhoria -> nível comprado
static var classes_desbloqueadas := ["cavaleiro"]
static var classe_atual := "cavaleiro"
static var melhor_nivel := 0

static var tela_cheia := false
static var indice_resolucao := 0
static var volume := 0.8

static var _carregado := false
static var _classes: Array[ClasseJogador] = []
static var _melhorias: Array[Melhoria] = []


# ---------- Salvar e carregar ----------

static func carregar() -> void:
	if _carregado:
		return
	_carregado = true

	var cfg := ConfigFile.new()
	if cfg.load(ARQUIVO) == OK:
		ouro = int(cfg.get_value("progresso", "ouro", 0))
		melhorias = cfg.get_value("progresso", "melhorias", {})
		classes_desbloqueadas = cfg.get_value("progresso", "classes", ["cavaleiro"])
		classe_atual = str(cfg.get_value("progresso", "classe_atual", "cavaleiro"))
		melhor_nivel = int(cfg.get_value("progresso", "melhor_nivel", 0))
		tela_cheia = bool(cfg.get_value("opcoes", "tela_cheia", false))
		indice_resolucao = clampi(int(cfg.get_value("opcoes", "indice_resolucao", 0)), 0, RESOLUCOES.size() - 1)
		volume = float(cfg.get_value("opcoes", "volume", 0.8))
	aplicar_opcoes()


static func salvar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progresso", "ouro", ouro)
	cfg.set_value("progresso", "melhorias", melhorias)
	cfg.set_value("progresso", "classes", classes_desbloqueadas)
	cfg.set_value("progresso", "classe_atual", classe_atual)
	cfg.set_value("progresso", "melhor_nivel", melhor_nivel)
	cfg.set_value("opcoes", "tela_cheia", tela_cheia)
	cfg.set_value("opcoes", "indice_resolucao", indice_resolucao)
	cfg.set_value("opcoes", "volume", volume)
	cfg.save(ARQUIVO)


static func resetar_progresso() -> void:
	ouro = 0
	melhorias = {}
	classes_desbloqueadas = ["cavaleiro"]
	classe_atual = "cavaleiro"
	melhor_nivel = 0
	salvar()


static func aplicar_opcoes() -> void:
	if tela_cheia:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var tamanho: Vector2i = RESOLUCOES[indice_resolucao]
		DisplayServer.window_set_size(tamanho)
		# Centraliza a janela na tela
		var tela := DisplayServer.screen_get_size()
		var folga := ((tela - tamanho) / 2).max(Vector2i.ZERO)
		DisplayServer.window_set_position(DisplayServer.screen_get_position() + folga)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))


# ---------- Carregar os Resources ----------

static func _carregar_pasta(pasta: String) -> Array:
	var resultado: Array = []
	var arquivos := Array(DirAccess.get_files_at(pasta))
	arquivos.sort()    # por isso os arquivos têm prefixo numérico (01_, 02_...)
	for arquivo in arquivos:
		var nome: String = arquivo.trim_suffix(".remap")
		if nome.ends_with(".tres"):
			var recurso = load(pasta + nome)
			if recurso != null:
				resultado.append(recurso)
	return resultado


static func todas_classes() -> Array[ClasseJogador]:
	if _classes.is_empty():
		for r in _carregar_pasta(PASTA_CLASSES):
			if r is ClasseJogador:
				_classes.append(r)
	return _classes


static func todas_melhorias() -> Array[Melhoria]:
	if _melhorias.is_empty():
		for r in _carregar_pasta(PASTA_MELHORIAS):
			if r is Melhoria:
				_melhorias.append(r)
	return _melhorias


static func classe(id: String) -> ClasseJogador:
	for c in todas_classes():
		if c.id == id:
			return c
	return null


static func melhoria_por_id(id: String) -> Melhoria:
	for m in todas_melhorias():
		if m.id == id:
			return m
	return null


# ---------- Classes ----------

static func classe_desbloqueada(id: String) -> bool:
	return id in classes_desbloqueadas


static func desbloquear_classe(c: ClasseJogador) -> bool:
	if classe_desbloqueada(c.id) or ouro < c.custo_desbloqueio:
		return false
	ouro -= c.custo_desbloqueio
	classes_desbloqueadas.append(c.id)
	salvar()
	return true


# ---------- Melhorias ----------

static func nivel_melhoria(id: String) -> int:
	return int(melhorias.get(id, 0))


static func custo_melhoria(m: Melhoria) -> int:
	return m.custo_base + m.custo_por_nivel * nivel_melhoria(m.id)


# Devolve "" se pode comprar; senão, o motivo
static func motivo_bloqueio(m: Melhoria) -> String:
	if nivel_melhoria(m.id) >= m.nivel_max:
		return "Nível máximo"
	if m.requisito_id != "" and nivel_melhoria(m.requisito_id) < m.requisito_nivel:
		var req := melhoria_por_id(m.requisito_id)
		var nome := req.nome if req else m.requisito_id
		return "Requer %s (nível %d)" % [nome, m.requisito_nivel]
	if ouro < custo_melhoria(m):
		return "Ouro insuficiente"
	return ""


static func comprar_melhoria(m: Melhoria) -> bool:
	if motivo_bloqueio(m) != "":
		return false
	ouro -= custo_melhoria(m)
	melhorias[m.id] = nivel_melhoria(m.id) + 1
	salvar()
	return true


# Soma o efeito de todas as melhorias compradas que valem para esta classe
static func efeito_total(id_efeito: String, id_classe: String) -> float:
	var total := 0.0
	for m in todas_melhorias():
		if m.id_efeito == id_efeito and (m.classe == "" or m.classe == id_classe):
			total += m.valor * nivel_melhoria(m.id)
	return total


# ---------- Fim da partida ----------

static func registrar_run(nivel: int, ouro_ganho: int) -> void:
	ouro += ouro_ganho
	melhor_nivel = maxi(melhor_nivel, nivel)
	salvar()
