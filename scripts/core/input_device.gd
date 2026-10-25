extends Node
## Автозагрузка InputDevice: помнит, чем игрок пользуется сейчас — клавиатурой с мышью
## или геймпадом. При игре на геймпаде прячет курсор мыши.

signal device_changed(device: Device)

enum Device { KEYBOARD_MOUSE, GAMEPAD }

## Насколько надо отклонить стик, чтобы считать, что игрок взял геймпад.
const STICK_THRESHOLD: float = 0.3
## Сдвиг мыши в пикселях, после которого возвращаемся к мыши (защита от дрожания).
const MOUSE_MOVE_THRESHOLD: float = 4.0

var current: Device = Device.KEYBOARD_MOUSE


func is_gamepad() -> bool:
	return current == Device.GAMEPAD


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		_set_device(Device.GAMEPAD)
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > STICK_THRESHOLD:
			_set_device(Device.GAMEPAD)
	elif event is InputEventKey or event is InputEventMouseButton:
		_set_device(Device.KEYBOARD_MOUSE)
	elif event is InputEventMouseMotion:
		if (event as InputEventMouseMotion).relative.length() > MOUSE_MOVE_THRESHOLD:
			_set_device(Device.KEYBOARD_MOUSE)


func _set_device(device: Device) -> void:
	if device == current:
		return
	current = device
	if device == Device.GAMEPAD:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	device_changed.emit(device)
