class_name CarProfileModal
extends Control

## Modal Interativo de Criação e Edição de Perfis de Carros
## Permite ao jogador ajustar a física do motor e as características dos sensores.

signal profile_saved(profile_id: String)
signal closed()

var _opt_profiles: OptionButton
var _line_id: LineEdit
var _line_name: LineEdit

# Campos de Física
var _spin_speed: SpinBox
var _spin_accel: SpinBox
var _spin_brake: SpinBox
var _spin_steer: SpinBox

# Campos de Sensores
var _spin_sensor_count: SpinBox
var _spin_sensor_range: SpinBox
var _spin_sensor_spread: SpinBox
var _spin_sensor_off_y: SpinBox
var _spin_sensor_off_z: SpinBox

var _btn_delete: Button
var _status_label: Label
var _current_editing_id: String = "standard"


static func open_modal(parent: Node, on_saved: Callable = Callable()) -> CarProfileModal:
	var modal := CarProfileModal.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(modal)
	if on_saved.is_valid():
		modal.profile_saved.connect(on_saved)
	return modal


func _ready() -> void:
	_build_ui()
	_load_profile_into_ui("standard")


func _build_ui() -> void:
	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.02, 0.03, 0.06, 0.8)
	add_child(dimmer)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 500)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.15, 0.98)
	style.set_corner_radius_all(10)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.0, 0.8, 1.0, 0.8)
	style.content_margin_left = 20
	style.content_margin_top = 16
	style.content_margin_right = 20
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# --- CABEÇALHO ---
	var header_hbox := HBoxContainer.new()
	vbox.add_child(header_hbox)

	var title := Label.new()
	title.text = "🏎️ GARAGEM & PERFIS DE CARROS"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title)

	var btn_close := Button.new()
	btn_close.text = "✕"
	btn_close.flat = true
	btn_close.pressed.connect(_close)
	header_hbox.add_child(btn_close)

	vbox.add_child(HSeparator.new())

	# --- SELETOR DE PERFIL E AÇÕES RÁPIDAS ---
	var selector_hbox := HBoxContainer.new()
	selector_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(selector_hbox)

	var lbl_sel := Label.new()
	lbl_sel.text = "Perfil Ativo:"
	lbl_sel.add_theme_font_size_override("font_size", 12)
	selector_hbox.add_child(lbl_sel)

	_opt_profiles = OptionButton.new()
	_opt_profiles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_opt_profiles.item_selected.connect(_on_profile_dropdown_selected)
	selector_hbox.add_child(_opt_profiles)

	var btn_new := Button.new()
	btn_new.text = "➕ Novo"
	btn_new.pressed.connect(_on_btn_new_pressed)
	selector_hbox.add_child(btn_new)

	var btn_dup := Button.new()
	btn_dup.text = "📋 Duplicar"
	btn_dup.pressed.connect(_on_btn_duplicate_pressed)
	selector_hbox.add_child(btn_dup)

	_btn_delete = Button.new()
	_btn_delete.text = "🗑️ Excluir"
	_btn_delete.pressed.connect(_on_btn_delete_pressed)
	selector_hbox.add_child(_btn_delete)

	# --- FORMULÁRIO SCROLLÁVEL ---
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 320)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var form_vbox := VBoxContainer.new()
	form_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(form_vbox)

	# Informações Básicas
	var meta_grid := GridContainer.new()
	meta_grid.columns = 2
	meta_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_grid.add_theme_constant_override("h_separation", 12)
	meta_grid.add_theme_constant_override("v_separation", 6)
	form_vbox.add_child(meta_grid)

	meta_grid.add_child(_create_label("Identificador (ID):"))
	_line_id = LineEdit.new()
	_line_id.placeholder_text = "ex: sport_turbo"
	_line_id.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_grid.add_child(_line_id)

	meta_grid.add_child(_create_label("Nome de Exibição:"))
	_line_name = LineEdit.new()
	_line_name.placeholder_text = "ex: Esportivo Turbo"
	_line_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_grid.add_child(_line_name)

	# Seção de Física
	var lbl_sec_phy := Label.new()
	lbl_sec_phy.text = "⚡ DINÂMICA E FÍSICA DO VEÍCULO"
	lbl_sec_phy.add_theme_font_size_override("font_size", 12)
	lbl_sec_phy.add_theme_color_override("font_color", Color(0.2, 0.9, 0.7))
	form_vbox.add_child(lbl_sec_phy)

	var phy_grid := GridContainer.new()
	phy_grid.columns = 2
	phy_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phy_grid.add_theme_constant_override("h_separation", 12)
	phy_grid.add_theme_constant_override("v_separation", 6)
	form_vbox.add_child(phy_grid)

	phy_grid.add_child(_create_label("Velocidade Máxima (m/s):"))
	_spin_speed = _create_spinbox(10.0, 2000.0, 0.1, 300.0)
	phy_grid.add_child(_spin_speed)

	phy_grid.add_child(_create_label("Aceleração do Motor:"))
	_spin_accel = _create_spinbox(1.0, 2000.0, 0.1, 200.0)
	phy_grid.add_child(_spin_accel)

	phy_grid.add_child(_create_label("Força dos Freios:"))
	_spin_brake = _create_spinbox(1.0, 2000.0, 0.1, 100.0)
	phy_grid.add_child(_spin_brake)

	phy_grid.add_child(_create_label("Velocidade Esterçamento:"))
	_spin_steer = _create_spinbox(0.1, 100.0, 0.01, 2.5)
	phy_grid.add_child(_spin_steer)

	# Seção de Sensores
	var lbl_sec_sen := Label.new()
	lbl_sec_sen.text = "📡 SENSORES E PERCEPÇÃO DA IA"
	lbl_sec_sen.add_theme_font_size_override("font_size", 12)
	lbl_sec_sen.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	form_vbox.add_child(lbl_sec_sen)

	var sen_grid := GridContainer.new()
	sen_grid.columns = 2
	sen_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sen_grid.add_theme_constant_override("h_separation", 12)
	sen_grid.add_theme_constant_override("v_separation", 6)
	form_vbox.add_child(sen_grid)

	sen_grid.add_child(_create_label("Quantidade de Sensores:"))
	_spin_sensor_count = _create_spinbox(1, 15, 1, 5)
	sen_grid.add_child(_spin_sensor_count)

	sen_grid.add_child(_create_label("Alcance Máximo (m):"))
	_spin_sensor_range = _create_spinbox(0.2, 50.0, 0.1, 1.5)
	sen_grid.add_child(_spin_sensor_range)

	sen_grid.add_child(_create_label("Abertura Angular (graus):"))
	_spin_sensor_spread = _create_spinbox(10.0, 180.0, 1.0, 90.0)
	sen_grid.add_child(_spin_sensor_spread)

	sen_grid.add_child(_create_label("Altura Offset Y (m):"))
	_spin_sensor_off_y = _create_spinbox(-1.0, 2.0, 0.01, 0.05)
	sen_grid.add_child(_spin_sensor_off_y)

	sen_grid.add_child(_create_label("Posição Frontal Z (m):"))
	_spin_sensor_off_z = _create_spinbox(-2.0, 2.0, 0.01, 0.15)
	sen_grid.add_child(_spin_sensor_off_z)

	vbox.add_child(HSeparator.new())

	# --- RODAPÉ COM AÇÕES ---
	var footer_hbox := HBoxContainer.new()
	footer_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(footer_hbox)

	var btn_save := Button.new()
	btn_save.text = "💾 Salvar Perfil"
	btn_save.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
	btn_save.pressed.connect(_save_current_profile)
	footer_hbox.add_child(btn_save)

	var btn_default := Button.new()
	btn_default.text = "🔄 Restaurar Padrões"
	btn_default.pressed.connect(_restore_defaults)
	footer_hbox.add_child(btn_default)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	footer_hbox.add_child(_status_label)

	var btn_close_footer := Button.new()
	btn_close_footer.text = "Fechar"
	btn_close_footer.pressed.connect(_close)
	footer_hbox.add_child(btn_close_footer)

	_refresh_profiles_dropdown()


func _create_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	return lbl


func _create_spinbox(min_val: float, max_val: float, step_val: float, def_val: float) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = min_val
	sb.max_value = max_val
	sb.step = step_val
	sb.allow_greater = true
	sb.value = def_val
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return sb


func _refresh_profiles_dropdown() -> void:
	_opt_profiles.clear()
	var profiles := CarProfileManager.list_profiles()
	var sel_idx := 0

	for i in range(profiles.size()):
		var p: Dictionary = profiles[i]
		_opt_profiles.add_item(p["name"], i)
		_opt_profiles.set_item_metadata(i, p["id"])
		if p["id"] == _current_editing_id:
			sel_idx = i

	_opt_profiles.select(sel_idx)
	_btn_delete.disabled = (_current_editing_id == "standard")


func _on_profile_dropdown_selected(idx: int) -> void:
	var prof_id: String = _opt_profiles.get_item_metadata(idx)
	_load_profile_into_ui(prof_id)


func _load_profile_into_ui(prof_id: String) -> void:
	_current_editing_id = prof_id
	var prof := CarProfileManager.get_profile(prof_id)

	_line_id.text = prof.get("id", prof_id)
	_line_id.editable = (prof_id != "standard")
	_line_name.text = prof.get("name", prof_id.capitalize())

	_spin_speed.value = float(prof.get("max_speed", 300.0))
	_spin_accel.value = float(prof.get("acceleration", 200.0))
	_spin_brake.value = float(prof.get("brake_force", 100.0))
	_spin_steer.value = float(prof.get("steering_speed", 2.5))

	_spin_sensor_count.value = int(prof.get("sensor_count", 5))
	_spin_sensor_range.value = float(prof.get("sensor_range", 1.5))
	_spin_sensor_spread.value = float(prof.get("sensor_spread_angle", 90.0))
	_spin_sensor_off_y.value = float(prof.get("sensors", {}).get("sensor_offset_y", 0.05))
	_spin_sensor_off_z.value = float(prof.get("sensors", {}).get("sensor_offset_z", 0.15))

	_btn_delete.disabled = (prof_id == "standard")
	_status_label.text = ""


func _save_current_profile() -> void:
	var new_id := _line_id.text.strip_edges().to_lower().replace(" ", "_")
	if new_id == "":
		new_id = "custom_car"

	var prof_data := {
		"id": new_id,
		"name": _line_name.text.strip_edges() if _line_name.text.strip_edges() != "" else new_id.capitalize(),
		"physics": {
			"max_speed": _spin_speed.value,
			"acceleration": _spin_accel.value,
			"brake_force": _spin_brake.value,
			"steering_speed": _spin_steer.value
		},
		"sensors": {
			"sensor_count": int(_spin_sensor_count.value),
			"sensor_range": _spin_sensor_range.value,
			"sensor_spread_angle": _spin_sensor_spread.value,
			"sensor_offset_y": _spin_sensor_off_y.value,
			"sensor_offset_z": _spin_sensor_off_z.value
		}
	}

	CarProfileManager.save_profile(prof_data)
	_current_editing_id = new_id

	# Se for o perfil atualmente selecionado no jogo, atualiza o AppState
	var app_state: Node = get_node_or_null("/root/AppState")
	if app_state and app_state.current_car_profile_id == new_id:
		app_state.set_current_car_profile(new_id)

	_refresh_profiles_dropdown()
	_status_label.text = "✅ Perfil salvo!"
	emit_signal("profile_saved", new_id)


func _on_btn_new_pressed() -> void:
	var count := CarProfileManager.list_profiles().size()
	var new_id := "custom_car_%d" % count
	_current_editing_id = new_id
	_line_id.text = new_id
	_line_id.editable = true
	_line_name.text = "Novo Carro %d" % count
	_status_label.text = "Novo perfil pronto para configurar."


func _on_btn_duplicate_pressed() -> void:
	var source_id := _current_editing_id
	var new_id := source_id + "_copia"
	_current_editing_id = new_id
	_line_id.text = new_id
	_line_id.editable = true
	_line_name.text = _line_name.text + " (Cópia)"
	_save_current_profile()
	_status_label.text = "Cópia criada com sucesso!"


func _on_btn_delete_pressed() -> void:
	if _current_editing_id == "standard":
		return
	CarProfileManager.delete_profile(_current_editing_id)
	_current_editing_id = "standard"
	_refresh_profiles_dropdown()
	_load_profile_into_ui("standard")
	_status_label.text = "Perfil removido."


func _restore_defaults() -> void:
	var def := CarProfileManager.get_default_profile()
	_spin_speed.value = def["physics"]["max_speed"]
	_spin_accel.value = def["physics"]["acceleration"]
	_spin_brake.value = def["physics"]["brake_force"]
	_spin_steer.value = def["physics"]["steering_speed"]
	_spin_sensor_count.value = def["sensors"]["sensor_count"]
	_spin_sensor_range.value = def["sensors"]["sensor_range"]
	_spin_sensor_spread.value = def["sensors"]["sensor_spread_angle"]
	_spin_sensor_off_y.value = def["sensors"]["sensor_offset_y"]
	_spin_sensor_off_z.value = def["sensors"]["sensor_offset_z"]
	_status_label.text = "Valores padrão carregados no formulário."


func _close() -> void:
	emit_signal("closed")
	queue_free()
