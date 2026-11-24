class_name ArvoreLayout
extends RefCounted
# Onde cada melhoria fica na árvore, e qual melhoria precisa ser comprada antes dela.
# Para criar uma melhoria nova, faça o .tres e (se quiser) adicione uma linha aqui:
#   "id_da_melhoria": {"c": coluna, "l": linha, "pai": "id_do_pai", "nivel_pai": nível exigido}
# Se ela não estiver na lista, aparece numa fileira extra no fim da árvore.
# Uma melhoria só APARECE na árvore quando o "pai" chega ao nível exigido.

const NOS := {
	# ---- Geral ----
	"vitalidade":         {"c": 2, "l": 0, "pai": "", "nivel_pai": 1},
	"bolsa_de_couro":     {"c": 5, "l": 0, "pai": "", "nivel_pai": 1},
	"pele_grossa":        {"c": 1, "l": 1, "pai": "vitalidade", "nivel_pai": 2},
	"robustez_ana":       {"c": 3, "l": 1, "pai": "vitalidade", "nivel_pai": 4},
	"bom_descanso":       {"c": 5, "l": 1, "pai": "bolsa_de_couro", "nivel_pai": 2},
	"sangue_resistente":  {"c": 0, "l": 2, "pai": "pele_grossa", "nivel_pai": 1},
	"pele_ignifuga":      {"c": 2, "l": 2, "pai": "pele_grossa", "nivel_pai": 1},
	"amuleto_da_sorte":   {"c": 4, "l": 2, "pai": "bom_descanso", "nivel_pai": 1},
	"medicina":           {"c": 6, "l": 2, "pai": "bom_descanso", "nivel_pai": 1},
	"sobrevivencia":      {"c": 0, "l": 3, "pai": "sangue_resistente", "nivel_pai": 1},
	"acrobacia":          {"c": 2, "l": 3, "pai": "pele_ignifuga", "nivel_pai": 1},
	"olhar_atento":       {"c": 4, "l": 3, "pai": "amuleto_da_sorte", "nivel_pai": 2},
	"dados_de_vida":      {"c": 6, "l": 3, "pai": "medicina", "nivel_pai": 2},
	# ---- Cavaleiro ----
	"postura_dupla":      {"c": 1, "l": 0, "pai": "", "nivel_pai": 1},
	"postura_firme":      {"c": 0, "l": 1, "pai": "postura_dupla", "nivel_pai": 1},
	"armadura_de_placas": {"c": 2, "l": 1, "pai": "postura_dupla", "nivel_pai": 1},
	"retomar_o_folego":   {"c": 0, "l": 2, "pai": "postura_firme", "nivel_pai": 1},
	# ---- Ladino ----
	"passo_longo":        {"c": 1, "l": 0, "pai": "", "nivel_pai": 1},
	"folego_extra":       {"c": 0, "l": 1, "pai": "passo_longo", "nivel_pai": 1},
	"evasao":             {"c": 2, "l": 1, "pai": "passo_longo", "nivel_pai": 1},
	"dado_afiado":        {"c": 0, "l": 2, "pai": "folego_extra", "nivel_pai": 1},
	"esquiva_sobrenatural": {"c": 2, "l": 2, "pai": "evasao", "nivel_pai": 2},
	# ---- Sacerdote ----
	"prece_maior":        {"c": 1, "l": 0, "pai": "", "nivel_pai": 1},
	"segunda_prece":      {"c": 0, "l": 1, "pai": "prece_maior", "nivel_pai": 1},
	"escudo_da_fe":       {"c": 1, "l": 1, "pai": "prece_maior", "nivel_pai": 2},
	"bencao_elemental":   {"c": 2, "l": 1, "pai": "prece_maior", "nivel_pai": 2},
}

# efeito -> [ícone, cor]
const ESTILO_POR_EFEITO := {
	"vida_inicial": ["coracao", Color(0.95, 0.35, 0.42)],
	"armadura_inicial": ["escudo", Color(0.6, 0.72, 0.92)],
	"resist_veneno_inicial": ["gota", Color(0.55, 0.82, 0.25)],
	"resist_fogo_inicial": ["chama", Color(0.98, 0.55, 0.15)],
	"resist_elemental_inicial": ["estrela", Color(0.75, 0.5, 0.95)],
	"bonus_ouro": ["moeda", Color(1.0, 0.85, 0.3)],
	"sorte_inicial": ["estrela", Color(0.85, 0.6, 1.0)],
	"descanso_inicial": ["cruz", Color(0.5, 0.92, 0.7)],
	"opcoes_extra_inicial": ["olho", Color(0.4, 0.8, 1.0)],
	"habilidade_usos": ["raio", Color(1.0, 0.75, 0.3)],
	"habilidade_forca": ["seta", Color(1.0, 0.6, 0.4)],
	"rerrola_inicial": ["dado", Color(0.92, 0.92, 0.95)],
	# ---- novas (inspiradas em D&D) ----
	"bonus_cura": ["cruz", Color(0.5, 0.92, 0.7)],
	"veneno_menos_turnos": ["gota", Color(0.7, 0.9, 0.4)],
	"queda_menos": ["seta", Color(0.7, 0.75, 0.85)],
	"descanso_pct_extra": ["cruz", Color(0.45, 0.85, 0.95)],
	"vida_a_cada_3_niveis": ["coracao", Color(0.95, 0.55, 0.35)],
	"segundo_folego": ["coracao", Color(1.0, 0.65, 0.5)],
	"evasao": ["seta", Color(0.5, 0.95, 0.6)],
	"esquiva_sobrenatural": ["escudo", Color(0.5, 0.95, 0.6)],
	"escudo_da_fe": ["escudo", Color(1.0, 0.9, 0.5)],
}


static func pai(m: Melhoria) -> String:
	if NOS.has(m.id):
		return NOS[m.id]["pai"]
	return m.requisito_id


static func nivel_pai(m: Melhoria) -> int:
	if NOS.has(m.id):
		return NOS[m.id]["nivel_pai"]
	return m.requisito_nivel


static func posicao(m: Melhoria, indice_auto: int) -> Vector2i:
	if NOS.has(m.id):
		return Vector2i(NOS[m.id]["c"], NOS[m.id]["l"])
	# Melhorias que você criou e ainda não colocou na lista vão para uma fileira extra
	return Vector2i(indice_auto % 6, 5 + floori(indice_auto / 6.0))


static func icone(m: Melhoria) -> String:
	if ESTILO_POR_EFEITO.has(m.id_efeito):
		return ESTILO_POR_EFEITO[m.id_efeito][0]
	return "estrela"


static func cor(m: Melhoria) -> Color:
	if ESTILO_POR_EFEITO.has(m.id_efeito):
		return ESTILO_POR_EFEITO[m.id_efeito][1]
	return Color(0.8, 0.8, 0.9)
