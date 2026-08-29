@tool
extends EditorPlugin

const SERVER_URL := "http://127.0.0.1:8765"
const SESSION_ID := "godot-editor"

var dock: VBoxContainer
var output: RichTextLabel
var input: TextEdit
var send_button: Button
var clear_button: Button
var status_label: Label
var http: HTTPRequest


func _enter_tree() -> void:
	dock = VBoxContainer.new()
	dock.name = "OpenAI Assistant"
	dock.custom_minimum_size = Vector2(330, 460)

	var title := Label.new()
	title.text = "OpenAI Assistant"
	title.add_theme_font_size_override("font_size", 18)
	dock.add_child(title)

	status_label = Label.new()
	status_label.text = "Servidor: verificando..."
	dock.add_child(status_label)

	output = RichTextLabel.new()
	output.bbcode_enabled = true
	output.fit_content = false
	output.custom_minimum_size = Vector2(320, 280)
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output.append_text("[b]Assistente pronto.[/b]\nDigite uma mensagem abaixo.\n")
	dock.add_child(output)

	input = TextEdit.new()
	input.placeholder_text = "Ex.: crie um script de player 3D com WASD..."
	input.custom_minimum_size = Vector2(320, 90)
	input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	dock.add_child(input)

	var buttons := HBoxContainer.new()

	send_button = Button.new()
	send_button.text = "Enviar"
	send_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	send_button.pressed.connect(_send_message)
	buttons.add_child(send_button)

	clear_button = Button.new()
	clear_button.text = "Limpar"
	clear_button.pressed.connect(_reset_chat)
	buttons.add_child(clear_button)

	dock.add_child(buttons)

	var tip := Label.new()
	tip.text = "Servidor local: 127.0.0.1:8765"
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dock.add_child(tip)

	http = HTTPRequest.new()
	dock.add_child(http)
	http.request_completed.connect(_on_request_completed)

	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
	_check_health()


func _exit_tree() -> void:
	if is_instance_valid(dock):
		remove_control_from_docks(dock)
		dock.queue_free()


func _check_health() -> void:
	if http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	var err := http.request(SERVER_URL + "/health")
	if err != OK:
		status_label.text = "Servidor: offline (rode LIGAR_IA.bat)"


func _send_message() -> void:
	var message := input.text.strip_edges()
	if message.is_empty():
		return

	if http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		output.append_text("\n[color=yellow]Aguarde a resposta atual terminar.[/color]\n")
		return

	var scene_name := "(nenhuma cena aberta)"
	var root := get_editor_interface().get_edited_scene_root()
	if root != null:
		scene_name = root.scene_file_path
		if scene_name.is_empty():
			scene_name = root.name

	var payload := {
		"message": message,
		"session_id": SESSION_ID,
		"project_name": str(ProjectSettings.get_setting("application/config/name", "Projeto Godot")),
		"scene": scene_name,
		"godot_version": Engine.get_version_info().get("string", "Godot 4")
	}

	output.append_text("\n[b]Você:[/b] " + _escape_bbcode(message) + "\n")
	input.clear()
	send_button.disabled = true
	status_label.text = "Servidor: enviando..."

	var headers := PackedStringArray(["Content-Type: application/json"])
	var err := http.request(
		SERVER_URL + "/chat",
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)

	if err != OK:
		send_button.disabled = false
		status_label.text = "Servidor: erro ao enviar"
		output.append_text("[color=red]Não consegui conectar ao servidor local. Rode LIGAR_IA.bat.[/color]\n")


func _reset_chat() -> void:
	output.clear()
	output.append_text("[b]Conversa limpa.[/b]\n")

	if http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return

	var payload := {"session_id": SESSION_ID}
	var headers := PackedStringArray(["Content-Type: application/json"])
	http.request(
		SERVER_URL + "/reset",
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)


func _on_request_completed(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	send_button.disabled = false

	if result != HTTPRequest.RESULT_SUCCESS:
		status_label.text = "Servidor: offline"
		output.append_text("\n[color=red]Falha de conexão. Rode LIGAR_IA.bat.[/color]\n")
		return

	var raw := body.get_string_from_utf8()
	var data = JSON.parse_string(raw)

	if response_code == 200:
		status_label.text = "Servidor: online"
		if typeof(data) == TYPE_DICTIONARY and data.has("reply"):
			output.append_text("\n[b]IA:[/b]\n" + _escape_bbcode(str(data["reply"])) + "\n")
		elif typeof(data) == TYPE_DICTIONARY and data.has("status"):
			# Resposta do /health.
			pass
	else:
		status_label.text = "Servidor: erro HTTP " + str(response_code)
		var msg := raw
		if typeof(data) == TYPE_DICTIONARY and data.has("detail"):
			msg = str(data["detail"])
		output.append_text("\n[color=red]Erro: " + _escape_bbcode(msg) + "[/color]\n")


func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]")
