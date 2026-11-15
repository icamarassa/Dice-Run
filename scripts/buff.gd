class_name Buff
extends Resource

@export var nome: String
@export_enum("Comum", "Rara", "Epica", "Lendaria") var raridade: String = "Comum"
@export var descricao: String
@export var id_efeito: String
@export var valor: int = 1
