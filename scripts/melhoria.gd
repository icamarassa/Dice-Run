class_name Melhoria
extends Resource
# Uma melhoria PERMANENTE, comprada com ouro no menu.

@export var id: String
@export var nome: String
@export_multiline var descricao: String
@export var id_efeito: String
@export var valor: float = 1.0          # quanto ela dá POR NÍVEL comprado
@export var nivel_max: int = 3
@export var custo_base: int = 20
@export var custo_por_nivel: int = 15   # o custo sobe a cada nível comprado
@export var classe: String = ""         # "" = vale para todas; senão, o id da classe
@export var requisito_id: String = ""   # melhoria que precisa estar comprada antes
@export var requisito_nivel: int = 1
