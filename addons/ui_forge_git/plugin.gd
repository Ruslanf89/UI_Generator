@tool
extends EditorPlugin

const GitUpdate = preload("res://addons/ui_forge_git/git_update.gd")
var update_button: Button
var confirm: ConfirmationDialog
var message: AcceptDialog
var worker: Thread

func _enter_tree() -> void:
	update_button = Button.new()
	update_button.text = "Update UI Forge"
	update_button.tooltip_text = "Pull origin/main into this Godot source checkout. Requires Git and a clean working tree."
	update_button.pressed.connect(_confirm_update)
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, update_button)
	add_tool_menu_item("Update UI Forge from GitHub", _confirm_update)
	confirm = ConfirmationDialog.new()
	confirm.title = "Update UI Forge from GitHub"
	confirm.dialog_text = "Save your open scripts and scenes before continuing.\n\nThis pulls origin/main into this source checkout. Local disk changes and divergent commits block the update; they are never reset or stashed."
	confirm.ok_button_text = "Pull update"
	confirm.confirmed.connect(_start_update)
	get_editor_interface().get_base_control().add_child(confirm)
	message = AcceptDialog.new()
	get_editor_interface().get_base_control().add_child(message)

func _confirm_update() -> void:
	if worker != null and worker.is_started():
		return
	if get_editor_interface().is_playing_scene():
		message.title = "Stop the running app first"
		message.dialog_text = "Export any HUD design you want to keep, then stop the app with F8 and save your scripts/scenes before updating."
		message.popup_centered(Vector2i(620, 220))
		return
	confirm.popup_centered(Vector2i(620, 220))

func _start_update() -> void:
	if worker != null and worker.is_started():
		return
	update_button.disabled = true
	update_button.text = "Updating…"
	worker = Thread.new()
	var error = worker.start(_update_worker.bind(ProjectSettings.globalize_path("res://").trim_suffix("/")))
	if error != OK:
		worker = null
		_complete_update({"ok": false, "message": "Could not start the Git update job."})

func _update_worker(directory: String) -> void:
	_complete_update.call_deferred(GitUpdate.update_checkout(directory))

func _complete_update(result: Dictionary) -> void:
	if worker != null and worker.is_started():
		worker.wait_to_finish()
	worker = null
	if not is_inside_tree():
		return
	update_button.disabled = false
	update_button.text = "Update UI Forge"
	message.title = "UI Forge updated" if result.ok else "Update needs attention"
	message.dialog_text = result.message
	message.popup_centered(Vector2i(680, 340))
	if result.ok:
		get_editor_interface().get_resource_filesystem().scan()

func _exit_tree() -> void:
	if worker != null and worker.is_started():
		worker.wait_to_finish()
	remove_tool_menu_item("Update UI Forge from GitHub")
	if is_instance_valid(update_button):
		remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, update_button)
		update_button.queue_free()
	if is_instance_valid(confirm):
		confirm.queue_free()
	if is_instance_valid(message):
		message.queue_free()
