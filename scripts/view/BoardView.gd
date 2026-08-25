class_name BFBoardView
extends Node2D

## Desenha os blocos da imagem.
##
## O `_draw` fica em cache no canvas item ate alguem chamar `queue_redraw()`,
## entao mesmo com milhares de blocos so ha custo quando algum sai do tabuleiro.

var board: BFBoard
var origin := Vector2.ZERO
var cell := 32.0


func _draw() -> void:
	if board == null:
		return
	var gap := cell * 0.06
	var size := Vector2.ONE * (cell - gap)
	for i in board.cells.size():
		if board.cells[i] == BFBoard.EMPTY:
			continue
		var r := i / board.cols
		var c := i % board.cols
		var at := origin + Vector2(c, r) * cell + Vector2.ONE * gap * 0.5
		var base := board.color_at(i)
		draw_rect(Rect2(at, size), base)
		# Brilho no topo/esquerda e sombra embaixo: da o volume de bloquinho.
		draw_rect(Rect2(at, Vector2(size.x, size.y * 0.18)), base.lightened(0.22))
		draw_rect(Rect2(at + Vector2(0, size.y * 0.82), Vector2(size.x, size.y * 0.18)),
			base.darkened(0.18))
