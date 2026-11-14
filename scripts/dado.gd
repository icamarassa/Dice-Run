class_name Dado

var lados: int = 3
var bonus_repeticao: int = 0
var ultimo: int = 0
var teve_bonus: bool = false

func rolar() -> int:
	var resultado := randi_range(1, lados)
	teve_bonus = (resultado == ultimo and bonus_repeticao > 0)
	var total := resultado
	if teve_bonus:
		total += bonus_repeticao
	ultimo = resultado
	return total
