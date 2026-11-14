class_name Dado

var lados: int = 3

func rolar() -> int:
	return randi_range(1, lados)
