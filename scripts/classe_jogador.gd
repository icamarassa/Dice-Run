class_name ClasseJogador
extends Resource

@export var id: String
@export var nome: String
@export_multiline var descricao: String
@export var cor: Color = Color(0.85, 0.3, 0.3)

@export_group("Atributos iniciais")
@export var vida_inicial: int = 10
@export var armadura_inicial: int = 0
@export_range(0.0, 0.8) var resist_veneno: float = 0.0
@export_range(0.0, 0.8) var resist_fogo: float = 0.0
@export var dado_inicial: int = 3
@export var rerrola_inicial: int = 0

@export_group("Passiva")
@export var passiva: String = ""            # regen, pes_leves, sorte, gelo
@export var passiva_descricao: String

@export_group("Habilidade ativa")
@export var id_habilidade: String           # postura_ferro, impulso, prece
@export var nome_habilidade: String
@export var descricao_habilidade: String
@export var usos_habilidade: int = 1        # usos por nível

@export_group("Desbloqueio")
@export var custo_desbloqueio: int = 0
