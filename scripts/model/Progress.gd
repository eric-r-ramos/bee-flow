class_name BFProgress
extends RefCounted

## Progresso do jogador, em disco.
##
## Guarda quais níveis já foram limpos e o melhor resultado de cada um. É o
## único estado do jogo que sobrevive ao fechar o app - e é o que permite
## rejogar um nível vencido sem perder o desbloqueio do seguinte.

const PATH := "user://progress.json"

var cleared: Dictionary = {}   ## id do nível -> true
var best: Dictionary = {}      ## id do nível -> {"honey": int, "bees": int}


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


func record(id: String, honey: int, bees: int) -> void:
	cleared[id] = true
	var prev: Dictionary = best.get(id, {})
	# Rejogar um nível nunca piora o registro dele.
	if not prev.has("honey") or int(prev["honey"]) < honey:
		best[id] = {"honey": honey, "bees": bees}
	save()


func best_honey(id: String) -> int:
	return int((best.get(id, {}) as Dictionary).get("honey", 0))
