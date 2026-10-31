extends CanvasLayer
## Pause tactique : fige le jeu, montre le kit du Ranger (grenade en LB, lanceur en RB) et un clic sur le sol
## fixe une destination. CONSULTATION seulement (décision de cyril, 28 oct) : les capacités viennent de
## l'inventaire et se changent à la Forge de l'Atelier ; le menu du jeu (Vue / Échap) montre le butin.
## Manette : croix gauche/droite pour parcourir les fiches.

var _panel: Control
var _hint: Label
var _marker: MeshInstance3D
var _pending_click = null  # Vector2 position écran à convertir en destination
var _cards: Array = []     # [{panel, style, slot}] une par pouvoir de l'arsenal
var _cursor := 0

const GOLD := Color(0.84, 0.65, 0.25)
const AMORCE := Color(1.0, 0.75, 0.45)
const DETO := Color(0.6, 0.85, 1.0)

@onready var player: CharacterBody3D = get_parent().get_node("Player")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.visible = false
	add_child(_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.09, 0.13, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(dim)
	var box := PanelContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.position = Vector2(-300, 16)
	box.custom_minimum_size = Vector2(600, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.125, 0.15, 0.2, 0.9)
	style.border_color = GOLD
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	box.add_theme_stylebox_override("panel", style)
	_panel.add_child(box)
	var v := VBoxContainer.new()
	box.add_child(v)
	var title := Label.new()
	title.text = "PAUSE TACTIQUE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", GOLD)
	v.add_child(title)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	_hint.add_theme_font_size_override("font_size", 13)
	v.add_child(_hint)
	# Arsenal : une carte par pouvoir, en bas de l'écran
	var arsenal_title := Label.new()
	arsenal_title.text = "KIT DU RANGER   —   grenades en LB / E, lanceurs d'assaut en RB / R   —   croix ← → : parcourir   —   changer de capacité : Forge de l'Atelier"
	arsenal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arsenal_title.add_theme_font_size_override("font_size", 12)
	arsenal_title.add_theme_color_override("font_color", GOLD)
	arsenal_title.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	arsenal_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	arsenal_title.position = Vector2(-400, -262)
	arsenal_title.custom_minimum_size = Vector2(800, 0)
	_panel.add_child(arsenal_title)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.position = Vector2(-536, -240)
	row.add_theme_constant_override("separation", 8)
	_panel.add_child(row)
	for i in Combat.ARSENAL.size():
		var p: Dictionary = Combat.ARSENAL[i]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(170, 118)
		var cs := StyleBoxFlat.new()
		cs.bg_color = Color(0.125, 0.15, 0.2, 0.92)
		cs.border_color = Color(0.34, 0.39, 0.48)
		cs.set_border_width_all(1)
		cs.set_corner_radius_all(6)
		cs.set_content_margin_all(8)
		card.add_theme_stylebox_override("panel", cs)
		card.gui_input.connect(_on_card_input.bind(i))
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 2)
		card.add_child(cv)
		var slot := Label.new()
		slot.add_theme_font_size_override("font_size", 11)
		slot.add_theme_color_override("font_color", GOLD)
		cv.add_child(slot)
		var n := Label.new()
		n.text = p["name"]
		n.add_theme_font_size_override("font_size", 14)
		cv.add_child(n)
		var r := Label.new()
		r.text = p["role"].to_upper() + "   ·   %d s" % int(p["cooldown"])
		r.add_theme_font_size_override("font_size", 10)
		r.add_theme_color_override("font_color", AMORCE if p["role"] == "Amorce" else DETO)
		cv.add_child(r)
		var d := Label.new()
		d.text = p["desc"]
		d.autowrap_mode = TextServer.AUTOWRAP_WORD
		d.add_theme_font_size_override("font_size", 11)
		d.add_theme_color_override("font_color", Color(0.70, 0.74, 0.80))
		cv.add_child(d)
		row.add_child(card)
		_cards.append({ "panel": card, "style": cs, "slot": slot })
	var legend := Label.new()
	legend.text = "Amorce : marque la cible (brûlure, gel).   Détonateur : fait exploser une cible marquée = COMBO.   %s : %s" % [Combat.ULT["key"], Combat.ULT["name"] + ", " + Combat.ULT["desc"]]
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD
	legend.add_theme_font_size_override("font_size", 11)
	legend.add_theme_color_override("font_color", Color(0.70, 0.74, 0.80))
	legend.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	legend.grow_horizontal = Control.GROW_DIRECTION_BOTH
	legend.position = Vector2(-450, -108)
	legend.custom_minimum_size = Vector2(900, 0)
	_panel.add_child(legend)
	# Marqueur de destination dans le monde
	_marker = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.6
	tm.outer_radius = 0.8
	_marker.mesh = tm
	var m := StandardMaterial3D.new()
	m.albedo_color = GOLD
	m.emission_enabled = true
	m.emission = GOLD
	_marker.material_override = m
	_marker.visible = false
	get_parent().add_child.call_deferred(_marker)


func _on_card_input(event: InputEvent, index: int) -> void:
	if not get_tree().paused or not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		_cursor = index
		_refresh_cards()
		_forge_hint()


## En mission on ne change pas d'équipement (comme dans Anthem) : seulement à la Forge.
func _forge_hint() -> void:
	_hint.text = "En mission, les capacités ne se changent pas : passe à la Forge de l'Atelier (ton butin est dans le menu, bouton Vue / Échap)."


func _refresh_cards() -> void:
	var c: Combat = player.combat
	for i in _cards.size():
		var card: Dictionary = _cards[i]
		var txt := ""
		if c.equipped[0] == i:
			txt = "◀ LB / E"
		elif c.equipped[1] == i:
			txt = "RB / R ▶"
		card["slot"].text = txt
		var equipped: bool = c.equipped[0] == i or c.equipped[1] == i
		var st: StyleBoxFlat = card["style"]
		st.border_color = Color.WHITE if i == _cursor else (GOLD if equipped else Color(0.34, 0.39, 0.48))
		st.set_border_width_all(3 if i == _cursor else (2 if equipped else 1))
		st.bg_color = Color(0.2, 0.19, 0.16, 0.95) if equipped else Color(0.125, 0.15, 0.2, 0.92)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle()
		get_viewport().set_input_as_handled()
		return
	if not get_tree().paused:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pending_click = event.position
	elif event.is_action_pressed("menu"):
		_toggle()
	elif event.is_action_pressed("arsenal_prev"):
		_cursor = wrapi(_cursor - 1, 0, _cards.size())
		_refresh_cards()
	elif event.is_action_pressed("arsenal_next"):
		_cursor = wrapi(_cursor + 1, 0, _cards.size())
		_refresh_cards()
	elif event.is_action_pressed("power1") or event.is_action_pressed("power2"):
		_forge_hint()


func _toggle() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	_panel.visible = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.mouse_mode
	if paused:
		_cursor = player.combat.equipped[0]
		_refresh_cards()
		_hint.text = "Le temps est figé. Consulte ton kit, ou clique sur le sol pour fixer une destination, puis reprends (Tab ou Start)."
	elif player.destination != null:
		_marker.visible = true


func _physics_process(_delta: float) -> void:
	if _pending_click == null:
		return
	var pos: Vector2 = _pending_click
	_pending_click = null
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var from := cam.project_ray_origin(pos)
	var to := from + cam.project_ray_normal(pos) * 300.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	player.destination = hit["position"]
	_marker.global_position = hit["position"] + Vector3(0, 0.1, 0)
	_marker.visible = true
	_hint.text = "Destination fixée. Reprends (Tab ou Start) : le Solaris s'y rendra tout seul."


func _process(_delta: float) -> void:
	if _marker.visible and player.destination == null:
		_marker.visible = false
