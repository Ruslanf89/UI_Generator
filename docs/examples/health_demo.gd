extends Node2D
## Attach to a Node2D Game with CanvasLayer > HUD and the Health component.

@onready var health_bar: Range = $CanvasLayer/HUD/Canvas/Viewport/Design/Elements/Health/Value
@onready var health_text: Label = $CanvasLayer/HUD/Canvas/Viewport/Design/Elements/Health/Amount

var maximum_health: float = 100.0
var current_health: float = 100.0

func _ready() -> void:
	update_health_display()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_SPACE:
		current_health = maxf(0.0, current_health - 10.0)
	elif event.keycode == KEY_R:
		current_health = maximum_health
	else:
		return
	update_health_display()
	get_viewport().set_input_as_handled()

func update_health_display() -> void:
	health_bar.max_value = maximum_health
	health_bar.value = current_health
	health_text.text = "%d / %d" % [current_health, maximum_health]
