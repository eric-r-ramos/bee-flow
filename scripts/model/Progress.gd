class_name BFProgress
extends RefCounted

## Progresso do jogador, em disco.
##
## Guarda quais níveis já foram limpos e o melhor resultado de cada um. É o
## único estado do jogo que sobrevive ao fechar o app - e é o que permite
## rejogar um nível vencido sem perder o desbloqueio do seguinte.

const PATH := "user://progress.json"

var cleared: Dictionary = {}   ## id do nível -> true
## id do nível -> {"time": float, "waste": int}
##
## O mel NÃO serve de recorde: pela invariante "todo bloco vira exatamente um
## mel", ele é sempre igual à contagem de blocos do nível - idêntico para todo
## jogador, em toda partida. O que varia com a habilidade é o tempo (colmeia
## bem plantada coleta sem ficar ociosa) e as viagens perdidas (abelha que sai
## e volta vazia porque o alvo saiu do alcance).
var best: Dictionary = {}


func load_from_disk() -> void:
	cleared = {}
	best = {}
	if not FileAccess.file_exists(PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("progresso ilegível em %s; começando do zero" % PATH)
		return
	cleared = data.get("cleared", {})
	best = data.get("best", {})


func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("não consegui gravar o progresso em %s" % PATH)
		return
	f.store_string(JSON.stringify({"cleared": cleared, "best": best}))
	f.close()


func is_cleared(id: String) -> bool:
	return cleared.get(id, false) == true


func record(id: String, seconds: float, waste: int) -> void:
	cleared[id] = true
	var prev: Dictionary = best.get(id, {})
	# Rejogar um nível nunca piora o registro dele - e aqui MENOR é melhor.
	if not prev.has("time") or float(prev["time"]) > seconds:
		best[id] = {"time": seconds, "waste": waste}
	save()


func best_time(id: String) -> float:
	return float((best.get(id, {}) as Dictionary).get("time", 0.0))


func best_waste(id: String) -> int:
	return int((best.get(id, {}) as Dictionary).get("waste", 0))


## "41 s" ou "2:05". O tempo é acumulado em tempo DE JOGO, não de relógio,
## então o botão ×2 não falsifica recorde: ele acelera a exibição, não a
## simulação.
static func format_time(seconds: float) -> String:
	if seconds <= 0.0:
		return ""
	if seconds < 60.0:
		return "%d s" % int(round(seconds))
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
