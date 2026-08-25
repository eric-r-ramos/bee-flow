class_name BFHud
extends CanvasLayer

## Barra de status, botao de velocidade e o cartaz de fim de nivel.

var game: Node

var _title: Label
var _blocks: Label
var _honey: Label
var _speed: Button
var _veil: ColorRect
var _banner: Label
var _again: Button


func build(owner_game: Node) -> void:
	game = owner_game

	var band := ColorRect.new()
	band.color = Color(0.796, 0.776, 0.729)
	band.size = Vector2(1080, 156)
	add_child(band)

	_title = _make_label(Vector2(30, 18), Vector2(560, 52), 40, HORIZONTAL_ALIGNMENT_LEFT)
	_blocks = _make_label(Vector2(30, 76), Vector2(560, 40), 27, HORIZONTAL_ALIGNMENT_LEFT)
	_honey = _make_label(Vector2(500, 76), Vector2(340, 40), 27, HORIZONTAL_ALIGNMENT_RIGHT)

	_speed = Button.new()
	_speed.position = Vector2(870, 18)
	_speed.size = Vector2(180, 58)
	_speed.text = "x1"
	_speed.pressed.connect(_on_speed)
	add_child(_speed)

	var restart := Button.new()
	restart.position = Vector2(870, 84)
	restart.size = Vector2(180, 50)
	restart.text = "reiniciar"
	restart.pressed.connect(func(): game.restart())
	add_child(restart)

	_veil = ColorRect.new()
	_veil.color = Color(0.05, 0.04, 0.02, 0.62)
	_veil.size = Vector2(1080, 1920)
	_veil.visible = false
	add_child(_veil)

	_banner = _make_label(Vector2(0, 820), Vector2(1080, 120), 68,
		HORIZONTAL_ALIGNMENT_CENTER)
	_banner.visible = false

	_again = Button.new()
	_again.position = Vector2(390, 980)
	_again.size = Vector2(300, 80)
	_again.text = "continuar"
	_again.visible = false
	_again.pressed.connect(func(): game.advance())
	add_child(_again)


func refresh() -> void:
	_title.text = "%d. %s" % [game.level_index + 1, str(game.level.get("name", "Bee Flow"))]
	_blocks.text = "blocos %d   slots livres %d" % [game.board.filled_total, game.free_slots()]
	_honey.text = "mel %d   abelhas %d" % [game.honey, game.bees_dispatched]
	_speed.text = "x2" if Engine.time_scale > 1.5 else "x1"


func show_banner(text: String, action_label := "continuar") -> void:
	_veil.visible = true
	_banner.text = text
	_again.text = action_label
	_banner.visible = true
	_again.visible = true


func hide_banner() -> void:
	_veil.visible = false
	_banner.visible = false
	_again.visible = false


func _on_speed() -> void:
	Engine.time_scale = 1.0 if Engine.time_scale > 1.5 else 2.0
	refresh()


func _make_label(at: Vector2, size: Vector2, font_size: int, align: int) -> Label:
	var l := Label.new()
	l.position = at
	l.size = size
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(0.20, 0.16, 0.08))
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(l)
	return l
