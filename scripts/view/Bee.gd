class_name BFBee
extends Node2D

## Uma abelha: sai da colmeia, pega um bloco da cor dela, volta e entrega.
##
## Se o alvo sumir - outra abelha chegou antes, ou o jogador reposicionou a
## colmeia e o bloco saiu do alcance - ela procura outro. Nao achando nenhum,
## volta vazia e devolve a vaga pra colmeia, pra que reposicionar nunca custe
## abelhas ao jogador.

enum Phase { OUTBOUND, CARRYING, RETURNING }

const SPEED := 470.0

var game: Node
var hive: BFHive
var target_cell := -1
var phase := Phase.OUTBOUND
var carried := Color.WHITE
var _wobble := 0.0


func _process(delta: float) -> void:
	_wobble += delta * 13.0

	var dest := hive.pos
	if phase == Phase.OUTBOUND:
		if not game.is_target_valid(self) and not game.retarget(self):
			phase = Phase.RETURNING
		else:
			dest = game.cell_center(target_cell)

	position = position.move_toward(dest, SPEED * delta)
	queue_redraw()

	if position.distance_squared_to(dest) < 4.0:
		_arrive()


func _arrive() -> void:
	match phase:
		Phase.OUTBOUND:
			carried = game.board.color_at(target_cell)
			game.collect(self)
			phase = Phase.CARRYING
		Phase.CARRYING:
			game.deliver(self)
		Phase.RETURNING:
			game.refund(self)


func _draw() -> void:
	var body := Vector2(0, sin(_wobble) * 2.5)

	var ink := Color(0.15, 0.11, 0.03)

	# Corpo tingido com a cor da colmeia: e assim que o jogador le, de longe,
	# qual abelha carrega qual cor. O contorno escuro garante contraste mesmo
	# quando ela passa por cima de um bloco da mesma cor.
	draw_circle(body, 13.0, ink)
	draw_circle(body, 11.0, hive.color)
	draw_line(body + Vector2(-4.5, -8), body + Vector2(-4.5, 8), ink, 2.5)
	draw_line(body + Vector2(1.5, -9), body + Vector2(1.5, 9), ink, 2.5)

	# Cabeca na frente e asas por cima: e o que separa "abelha" de "bolinha".
	draw_circle(body + Vector2(8, 0), 5.0, ink)
	draw_circle(body + Vector2(-6, -9), 7.5, Color(1, 1, 1, 0.55))
	draw_circle(body + Vector2(5, -10), 7.5, Color(1, 1, 1, 0.55))

	if phase == Phase.CARRYING:
		var s := 19.0
		var at := body + Vector2(-s * 0.5, -26.0)
		draw_rect(Rect2(at, Vector2(s, s)), carried)
		draw_rect(Rect2(at, Vector2(s, s)), Color(0.15, 0.11, 0.03), false, 2.5)
