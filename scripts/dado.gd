class_name Dado

# Dados que existem de verdade, em ordem de evolução
const ESCADA: Array[int] = [3, 4, 6, 8, 10, 12, 20]

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


func indice() -> int:
	return ESCADA.find(lados)


# Ainda existe um dado maior que este, andando "passos" degraus na escada?
func pode_evoluir(passos: int = 1) -> bool:
	return indice() + passos < ESCADA.size()


func proximo_lados(passos: int = 1) -> int:
	return ESCADA[mini(indice() + passos, ESCADA.size() - 1)]


func evoluir(passos: int = 1) -> void:
	lados = proximo_lados(passos)
