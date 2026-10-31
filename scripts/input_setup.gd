extends Node
## Déclare les actions (clavier + manette) au démarrage, pour ne pas dépendre du fichier project.godot.
## Touches : physiques (ZQSD sur AZERTY = WASD physique). Manette : disposition standard (Xbox).

func _ready() -> void:
	_axis("move_left", KEY_A, JOY_AXIS_LEFT_X, -1.0, KEY_LEFT)
	_axis("move_right", KEY_D, JOY_AXIS_LEFT_X, 1.0, KEY_RIGHT)
	_axis("move_forward", KEY_W, JOY_AXIS_LEFT_Y, -1.0, KEY_UP)
	_axis("move_back", KEY_S, JOY_AXIS_LEFT_Y, 1.0, KEY_DOWN)
	_axis("look_left", KEY_NONE, JOY_AXIS_RIGHT_X, -1.0)
	_axis("look_right", KEY_NONE, JOY_AXIS_RIGHT_X, 1.0)
	_axis("look_up", KEY_NONE, JOY_AXIS_RIGHT_Y, -1.0)
	_axis("look_down", KEY_NONE, JOY_AXIS_RIGHT_Y, 1.0)
	_button("fly", KEY_SPACE, [JOY_BUTTON_A])
	_button("land", KEY_CTRL, [JOY_BUTTON_Y])
	_button("dash", KEY_SHIFT, [JOY_BUTTON_B])            # appui court = dash (vrille en vol), maintenu près d'un obstacle = se cacher
	_button("sprint", KEY_Q, [JOY_BUTTON_LEFT_STICK])     # course (bascule) ; Q physique = A sur un clavier AZERTY
	_button("cover", KEY_C, [])                           # se cacher / sortir de la cachette (clavier)
	# Combat
	_axis("fire", KEY_NONE, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_mouse("fire", MOUSE_BUTTON_LEFT)
	_axis("aim", KEY_NONE, JOY_AXIS_TRIGGER_LEFT, 1.0)
	_mouse("aim", MOUSE_BUTTON_RIGHT)
	_button("melee", KEY_V, [JOY_BUTTON_RIGHT_STICK])
	_mouse("melee", MOUSE_BUTTON_MIDDLE)
	_button("reload", KEY_X, [JOY_BUTTON_X])
	# Changer d'arme : Y au sol à la manette (géré par le joueur), T ou molette au clavier
	_button("switch_weapon", KEY_T, [])
	_mouse("switch_weapon", MOUSE_BUTTON_WHEEL_UP)
	_mouse("switch_weapon", MOUSE_BUTTON_WHEEL_DOWN)
	# Pouvoirs (façon Anthem : LB / RB, les deux ensemble = ultime)
	_button("power1", KEY_E, [JOY_BUTTON_LEFT_SHOULDER])
	_button("power2", KEY_R, [JOY_BUTTON_RIGHT_SHOULDER])
	_button("ultimate", KEY_F, [JOY_BUTTON_DPAD_UP])
	_button("pause", KEY_TAB, [JOY_BUTTON_START])
	_button("pause", KEY_P, [])
	_button("confirm", KEY_ENTER, [JOY_BUTTON_A])
	_button("arsenal_prev", KEY_LEFT, [JOY_BUTTON_DPAD_LEFT])
	_button("arsenal_next", KEY_RIGHT, [JOY_BUTTON_DPAD_RIGHT])
	# Menu du jeu (consultation, façon Anthem) : bouton Vue / Échap. « quit » reste déclarée sans touche.
	_button("menu", KEY_ESCAPE, [JOY_BUTTON_BACK])
	_ensure("quit")
	# Emotes du preset d'apparence (en jeu, hors pause)
	_button("emote1", KEY_1, [JOY_BUTTON_DPAD_LEFT])
	_button("emote2", KEY_2, [JOY_BUTTON_DPAD_DOWN])
	_button("emote3", KEY_3, [JOY_BUTTON_DPAD_RIGHT])


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)


func _axis(action: String, key: Key, axis: JoyAxis, value: float, key2: Key = KEY_NONE) -> void:
	_ensure(action)
	for k in [key, key2]:
		if k != KEY_NONE:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	var motion := InputEventJoypadMotion.new()
	motion.axis = axis
	motion.axis_value = value
	InputMap.action_add_event(action, motion)


func _button(action: String, key: Key, buttons: Array) -> void:
	_ensure(action)
	if key != KEY_NONE:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)
	for b in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		InputMap.action_add_event(action, jb)


func _mouse(action: String, button: MouseButton) -> void:
	_ensure(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
