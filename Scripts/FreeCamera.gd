class_name FreeCamera
extends Camera3D

## Modos de movimentação no espaço
enum MovementMode {
	FLY_3D,  ## Modo Voo 3D: [code]W[/code] move diretamente para onde a [b]câmera/mouse[/b] está apontando (incluindo subida/descida na inclinação).
	PLANAR   ## Modo Plano: [code]W[/code] e [code]S[/code] movem no plano horizontal (XZ), altitude controlada exclusivamente por [code]Espaço[/code] e [code]Shift[/code].
}

## Modos de ativação do controle de visão com mouse
enum MouseControlMode {
	HOLD_RIGHT_CLICK, ## Rotaciona apenas enquanto segurar o Botão Direito do Mouse (estilo editor Godot/Unreal).
	MOUSE_CAPTURED,   ## Cursor sempre capturado (estilo FPS). Pressione [code]ESC[/code] para soltar/recapturar.
	HOLD_LEFT_CLICK,  ## Rotaciona apenas enquanto segurar o Botão Esquerdo do Mouse.
	TOGGLE_KEY        ## Alterna entre capturado e livre ao pressionar uma tecla configurada.
}

# ==============================================================================
# CONFIGURAÇÕES GERAIS
# ==============================================================================
@export_group("Geral")
@export var active: bool = true:
	set(value):
		active = value
		if not active:
			_set_mouse_captured(false)
@export var make_current_on_ready: bool = true

# ==============================================================================
# MODOS DE OPERAÇÃO
# ==============================================================================
@export_group("Modos de Operação")
@export var movement_mode: MovementMode = MovementMode.FLY_3D
@export var mouse_control_mode: MouseControlMode = MouseControlMode.HOLD_RIGHT_CLICK:
	set(value):
		mouse_control_mode = value
		if is_inside_tree() and active:
			_update_initial_mouse_state()
## Se ativado, [code]Espaço[/code] e [code]Shift[/code] sobem e descem no eixo [code]Y global[/code] do mundo (altitude real).
## Se desativado, sobem e descem relativo à orientação local da câmera.
@export var vertical_movement_global: bool = true

# ==============================================================================
# VELOCIDADE E MOVIMENTO
# ==============================================================================
@export_group("Velocidade")
@export var base_speed: float = 20.0
@export var smooth_movement: bool = true
@export_range(1.0, 50.0, 0.5) var smooth_factor: float = 16.0

@export_subgroup("Ajuste por Roda do Mouse (Scroll)")
@export var enable_speed_scroll: bool = true
@export var min_speed: float = 1.0
@export var max_speed: float = 150.0
@export var scroll_speed_step: float = 2.5

@export_subgroup("Turbo / Sprint")
@export var enable_turbo: bool = true
@export var turbo_multiplier: float = 2.5
@export var key_turbo: Key = KEY_CTRL

# ==============================================================================
# CONTROLE DE MOUSE E SENSIBILIDADE
# ==============================================================================
@export_group("Mouse / Rotação")
@export var mouse_sensitivity: float = 0.003
@export var invert_y: bool = false
@export_range(-89.9, 89.9, 0.1) var min_pitch: float = -89.0
@export_range(-89.9, 89.9, 0.1) var max_pitch: float = 89.0

# ==============================================================================
# MAPEAMENTO DE TECLAS
# ==============================================================================
@export_group("Teclas de Controle")
@export var key_forward: Key = KEY_W
@export var key_backward: Key = KEY_S
@export var key_left: Key = KEY_A
@export var key_right: Key = KEY_D
@export var key_up: Key = KEY_SPACE       # Ganhar altitude
@export var key_down: Key = KEY_SHIFT     # Descer altitude
@export var key_toggle_capture: Key = KEY_F

# ==============================================================================
# ESTADO INTERNO
# ==============================================================================
var _yaw: float = 0.0
var _pitch: float = 0.0
var _current_velocity: Vector3 = Vector3.ZERO
var _is_mouse_active: bool = false


func _ready() -> void:
	if make_current_on_ready:
		current = true

	# Inicializa rotações preservando orientação inicial
	_yaw = rotation.y
	_pitch = rotation.x
	rotation.z = 0.0

	if active:
		_update_initial_mouse_state()


func _exit_tree() -> void:
	_set_mouse_captured(false)


func _update_initial_mouse_state() -> void:
	match mouse_control_mode:
		MouseControlMode.MOUSE_CAPTURED:
			_set_mouse_captured(true)
		_:
			_set_mouse_captured(false)


func _set_mouse_captured(capture: bool) -> void:
	_is_mouse_active = capture
	if capture:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return

	# Atalho para alternar captura se configurado
	if mouse_control_mode == MouseControlMode.TOGGLE_KEY:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode == key_toggle_capture or event.keycode == key_toggle_capture:
				_set_mouse_captured(not _is_mouse_active)
				return

	# No modo capturado contínuo, tecla ESC solta/recaptura o mouse
	if mouse_control_mode == MouseControlMode.MOUSE_CAPTURED:
		if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
			_set_mouse_captured(not _is_mouse_active)
			return

	# Eventos de botões do mouse
	if event is InputEventMouseButton:
		# Ajuste de velocidade dinâmico pela roda do mouse
		if enable_speed_scroll:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
				base_speed = clamp(base_speed + scroll_speed_step, min_speed, max_speed)
				return
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
				base_speed = clamp(base_speed - scroll_speed_step, min_speed, max_speed)
				return

		# Modos de segurar botão para olhar
		if mouse_control_mode == MouseControlMode.HOLD_RIGHT_CLICK and event.button_index == MOUSE_BUTTON_RIGHT:
			_set_mouse_captured(event.pressed)
			return
		elif mouse_control_mode == MouseControlMode.HOLD_LEFT_CLICK and event.button_index == MOUSE_BUTTON_LEFT:
			_set_mouse_captured(event.pressed)
			return

	# Movimento do mouse para rotacionar câmera
	if event is InputEventMouseMotion and _is_mouse_active:
		_yaw -= event.relative.x * mouse_sensitivity
		var y_direction: float = 1.0 if invert_y else -1.0
		_pitch += event.relative.y * mouse_sensitivity * y_direction
		_pitch = clamp(_pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))

		rotation = Vector3(_pitch, _yaw, 0.0)


func _process(delta: float) -> void:
	if not active:
		return

	var forward_back := 0.0
	if _is_key_down(key_forward):
		forward_back += 1.0
	if _is_key_down(key_backward):
		forward_back -= 1.0

	var left_right := 0.0
	if _is_key_down(key_right):
		left_right += 1.0
	if _is_key_down(key_left):
		left_right -= 1.0

	var up_down := 0.0
	if _is_key_down(key_up):
		up_down += 1.0
	if _is_key_down(key_down):
		up_down -= 1.0

	var move_dir := Vector3.ZERO
	var forward := Vector3.ZERO
	var right := Vector3.ZERO

	match movement_mode:
		MovementMode.FLY_3D:
			# Move exatamente na direção 3D que a câmera está olhando (W vai na direção do olhar)
			forward = -global_transform.basis.z
			right = global_transform.basis.x
		MovementMode.PLANAR:
			# Move restrito ao plano horizontal (XZ), sem subir/descer com a inclinação do olhar
			forward = -global_transform.basis.z
			forward.y = 0.0
			forward = forward.normalized()

			right = global_transform.basis.x
			right.y = 0.0
			right = right.normalized()

	move_dir += forward * forward_back
	move_dir += right * left_right

	# Movimento vertical (Ganhar/Perder altitude com Espaço / Shift)
	if up_down != 0.0:
		if vertical_movement_global:
			move_dir += Vector3.UP * up_down
		else:
			move_dir += global_transform.basis.y * up_down

	if move_dir.length_squared() > 0.0001:
		move_dir = move_dir.normalized()

	# Cálculo de velocidade (com suporte a Turbo/Sprint)
	var speed := base_speed
	if enable_turbo and _is_key_down(key_turbo):
		speed *= turbo_multiplier

	var target_velocity := move_dir * speed

	if smooth_movement:
		_current_velocity = _current_velocity.lerp(target_velocity, clamp(delta * smooth_factor, 0.0, 1.0))
	else:
		_current_velocity = target_velocity

	global_position += _current_velocity * delta


## Verifica se uma tecla física ou virtual está pressionada
func _is_key_down(key: Key) -> bool:
	return Input.is_physical_key_pressed(key) or Input.is_key_pressed(key)
