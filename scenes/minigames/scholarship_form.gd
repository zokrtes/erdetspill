extends CanvasLayer

const TOTAL_TIME := 45.0
const SIGNATURE_LINE_WIDTH := 2.0
const TIMER_WARNING_SECONDS := 15.0
const RESULT_OVERLAY_DURATION := 2.0

const NORMAL_QUESTIONS: Array[String] = [
	"Fullt navn:",
	"Fødselsdato:",
	"Adresse:",
	"Postnummer:",
	"Telefonnummer:",
	"E-postadresse:"
]

const UNUSUAL_QUESTIONS: Array[String] = [
	"Favorittfarge på brød:",
	"Antall ganger du har tenkt på elg denne uken:",
	"Beskriv lukten av en mandag:",
	"Hva er din mening om grus som matvare?",
	"Oppgi din nærmeste nabos bilmerke:"
]

const EXISTENTIAL_QUESTIONS: Array[String] = [
	"Hvorfor er du her?",
	"Hva er egentlig penger?",
	"Hadde du fortjent dette stipendet?",
	"Er du sikker på at dette er riktig valg?",
	"Hva ville mormor ha sagt?"
]

@export var success_sound: AudioStream
@export var fail_sound: AudioStream
@export var approved_sound: AudioStream
@export var rejected_sound: AudioStream
@export var error_sound: AudioStream

@onready var form_panel: PanelContainer = $FormPanel
@onready var questions_container: VBoxContainer = $FormPanel/Margin/RootVBox/QuestionsVBox
@onready var timer_label: Label = $FormPanel/Margin/RootVBox/HeaderHBox/TimerLabel
@onready var status_label: Label = $FormPanel/Margin/RootVBox/StatusLabel
@onready var signature_frame: PanelContainer = $FormPanel/Margin/RootVBox/SignatureFrame
@onready var signature_box: Control = $FormPanel/Margin/RootVBox/SignatureFrame/SignatureBox
@onready var submit_button: Button = $FormPanel/Margin/RootVBox/FooterHBox/SubmitButton
@onready var clear_button: Button = $FormPanel/Margin/RootVBox/FooterHBox/ClearButton
@onready var error_label: Label = $FormPanel/Margin/RootVBox/ErrorLabel
@onready var rejection_overlay: ColorRect = $FormPanel/RejectionOverlay
@onready var rejection_reason_label: Label = $FormPanel/RejectionOverlay/Dialog/Margin/VBox/ReasonLabel
@onready var rejection_extra_label: Label = $FormPanel/RejectionOverlay/Dialog/Margin/VBox/ExtraLabel
@onready var result_overlay: Panel = $ResultOverlay
@onready var result_label: Label = $ResultOverlay/ResultLabel
@onready var success_audio: AudioStreamPlayer = $SuccessAudio
@onready var fail_audio: AudioStreamPlayer = $FailAudio

var question_labels: Array[Label] = []
var input_fields: Array[LineEdit] = []

var signature_points: Array[Vector2] = []
var signature_break_indices: Array[int] = []
var signature_has_content: bool = false
var signature_out_of_bounds: bool = false
var signature_rect: Rect2 = Rect2()
var _is_drawing_signature: bool = false

var _time_remaining: float = TOTAL_TIME
var _is_resolved: bool = false
var _closed_with_end_call: bool = false
var _is_submitting: bool = false

var _default_line_edit_style: StyleBox
var _default_signature_style: StyleBox
var _empty_field_style := _make_border_style(Color(0.9, 0.2, 0.2, 1.0), Color(1, 1, 1, 1), 1)
var _default_form_style := _make_border_style(Color.BLACK, Color.WHITE, 2)
var _default_box_style := _make_border_style(Color.BLACK, Color.WHITE, 1)
var _signature_error_style := _make_border_style(Color(0.9, 0.2, 0.2, 1.0), Color.WHITE, 2)
var _rejection_style := _make_border_style(Color(0.8, 0.1, 0.1, 1.0), Color.WHITE, 2)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cache_fields()
	_apply_visual_style()
	_configure_result_audio()
	form_panel.visible = true
	if submit_button and not submit_button.pressed.is_connected(_on_submit_pressed):
		submit_button.pressed.connect(_on_submit_pressed)
	if clear_button and not clear_button.pressed.is_connected(_on_clear_button_pressed):
		clear_button.pressed.connect(_on_clear_button_pressed)
	call_deferred("_initialize_form_contents")
	_set_player_form_mode(true)

func _initialize_form_contents():
	await get_tree().process_frame
	_reset_form_state()

func _process(delta: float):
	if _is_resolved:
		return
	if get_tree().paused:
		return
	_time_remaining = max(0.0, _time_remaining - delta)
	_update_timer_label()
	if _time_remaining <= 0.0 and not _is_submitting:
		_is_submitting = true
		await _validate_and_submit(true)

func _exit_tree():
	if not _is_resolved:
		_set_player_form_mode(false)

func _cache_fields():
	question_labels = [
		$FormPanel/Margin/RootVBox/QuestionsVBox/Q1Box/VBox/QuestionLabel,
		$FormPanel/Margin/RootVBox/QuestionsVBox/Q2Box/VBox/QuestionLabel,
		$FormPanel/Margin/RootVBox/QuestionsVBox/Q3Box/VBox/QuestionLabel,
		$FormPanel/Margin/RootVBox/QuestionsVBox/Q4Box/VBox/QuestionLabel
	]
	input_fields = [
		$FormPanel/Margin/RootVBox/QuestionsVBox/Q1Box/VBox/Input,
		$FormPanel/Margin/RootVBox/QuestionsVBox/Q2Box/VBox/Input,
		$FormPanel/Margin/RootVBox/QuestionsVBox/Q3Box/VBox/Input,
		$FormPanel/Margin/RootVBox/QuestionsVBox/Q4Box/VBox/Input
	]
	_default_line_edit_style = input_fields[0].get_theme_stylebox("normal")
	_default_signature_style = signature_frame.get_theme_stylebox("panel")
	signature_rect = Rect2(Vector2.ZERO, signature_box.size)

func _apply_visual_style():
	form_panel.add_theme_stylebox_override("panel", _default_form_style)
	for path in [
		"FormPanel/Margin/RootVBox/QuestionsVBox/Q1Box",
		"FormPanel/Margin/RootVBox/QuestionsVBox/Q2Box",
		"FormPanel/Margin/RootVBox/QuestionsVBox/Q3Box",
		"FormPanel/Margin/RootVBox/QuestionsVBox/Q4Box"
	]:
		var box: PanelContainer = get_node_or_null(path) as PanelContainer
		if box == null:
			continue
		box.add_theme_stylebox_override("panel", _default_box_style)
	signature_frame.add_theme_stylebox_override("panel", _default_box_style)
	$FormPanel/RejectionOverlay/Dialog.add_theme_stylebox_override("panel", _rejection_style)

func _reset_form_state():
	_is_resolved = false
	_closed_with_end_call = false
	_is_submitting = false
	_time_remaining = TOTAL_TIME
	_update_timer_label()
	rejection_overlay.hide()
	rejection_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_overlay.hide()
	result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_assign_random_questions()
	for field in input_fields:
		field.text = ""
		field.visible = true
		field.custom_minimum_size = Vector2(0, 30)
		field.add_theme_color_override("font_color", Color.BLACK)
		field.add_theme_stylebox_override("normal", _default_line_edit_style)
	signature_points.clear()
	signature_break_indices.clear()
	signature_has_content = false
	signature_out_of_bounds = false
	_is_drawing_signature = false
	signature_frame.add_theme_stylebox_override("panel", _default_box_style)
	signature_box.queue_redraw()
	status_label.text = ""
	if error_label:
		error_label.text = ""
		error_label.visible = false
	submit_button.disabled = false
	submit_button.text = "Send inn"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _assign_random_questions():
	if questions_container == null:
		push_warning("Questions container is null; cannot assign questions.")
		return
	var existential := EXISTENTIAL_QUESTIONS[randi() % EXISTENTIAL_QUESTIONS.size()]
	var pool: Array[String] = []
	pool.append_array(NORMAL_QUESTIONS)
	pool.append_array(UNUSUAL_QUESTIONS)
	pool.shuffle()
	var selected: Array[String] = [existential]
	for i in range(3):
		selected.append(pool[i])
	selected.shuffle()
	for i in range(question_labels.size()):
		question_labels[i].text = selected[i]
		question_labels[i].visible = true
		question_labels[i].add_theme_color_override("font_color", Color.BLACK)
	print("Questions selected: ", selected.size())
	print("Questions parent: ", questions_container.get_path())
	print("Questions container children: ", questions_container.get_child_count())

func _update_timer_label():
	var secs := int(ceil(_time_remaining))
	var minutes := int(secs / 60)
	var seconds := secs % 60
	timer_label.text = "Tid igjen: %d:%02d" % [minutes, seconds]
	timer_label.add_theme_color_override("font_color", Color(0.85, 0.1, 0.1, 1.0) if _time_remaining <= TIMER_WARNING_SECONDS else Color.BLACK)

func _validate_and_submit(from_timeout: bool = false) -> void:
	if _is_resolved:
		return
	if from_timeout:
		await _show_result_and_close(false, "SØKNAD AVVIST ✗")
		return
	if signature_out_of_bounds:
		_show_field_error("Signaturen er utenfor feltet.")
		submit_button.disabled = false
		submit_button.text = "Send inn"
		_is_submitting = false
		return
	if not signature_has_content:
		signature_frame.add_theme_stylebox_override("panel", _signature_error_style)
		_show_field_error("Du må signere søknaden.")
		submit_button.disabled = false
		submit_button.text = "Send inn"
		_is_submitting = false
		return
	signature_frame.add_theme_stylebox_override("panel", _default_box_style)
	var error := _validate_all_fields()
	if error != "":
		if error.begins_with("HARD_FAIL:"):
			await _show_result_and_close(false, error.replace("HARD_FAIL:", ""))
		else:
			_show_field_error(error)
			submit_button.disabled = false
			submit_button.text = "Send inn"
			_is_submitting = false
		return
	_show_field_error("")
	await _show_result_and_close(true, "SØKNAD GODKJENT ✓")

func _finish_success():
	if _is_resolved:
		return
	_is_resolved = true
	_closed_with_end_call = true
	GameManager.end_minigame("scholarship_form", 1)
	_set_player_form_mode(false)
	queue_free()

func _finish_hard_fail():
	if _is_resolved:
		return
	_is_resolved = true
	_reset_scholarship_minigame_progress()
	_closed_with_end_call = true
	GameManager.end_minigame("scholarship_form", 0)
	_set_player_form_mode(false)
	queue_free()

func _show_rejection(reason: String, extra: String = ""):
	rejection_reason_label.text = reason
	rejection_extra_label.text = extra
	rejection_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	rejection_overlay.show()
	_finish_hard_fail()

func _configure_result_audio() -> void:
	if success_sound == null and ResourceLoader.exists("res://assets/sfx/erdetlyd/success.ogg"):
		success_sound = load("res://assets/sfx/erdetlyd/success.ogg")
	if fail_sound == null and ResourceLoader.exists("res://assets/sfx/erdetlyd/fail.ogg"):
		fail_sound = load("res://assets/sfx/erdetlyd/fail.ogg")
	if success_audio:
		success_audio.stream = success_sound
	if fail_audio:
		fail_audio.stream = fail_sound

func _show_result_and_close(success: bool, text: String) -> void:
	if _is_resolved:
		return
	result_label.text = text
	result_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3, 1.0) if success else Color(0.9, 0.2, 0.2, 1.0))
	result_overlay.show()
	var stream: AudioStream = approved_sound if success else rejected_sound
	if stream == null:
		stream = success_sound if success else fail_sound
	_play_ephemeral_result_sound(stream)
	await get_tree().create_timer(RESULT_OVERLAY_DURATION).timeout
	if success:
		_finish_success()
	else:
		_finish_hard_fail()

func _reset_scholarship_minigame_progress():
	var quest: Quest = GameManager.active_quests.get("SCHOLARSHIP_APPLICATION")
	if quest == null:
		return
	var objective_id := "complete_scholarship_form"
	if not quest.objective_progress.has(objective_id):
		quest.objective_progress[objective_id] = 0
		return
	quest.objective_progress[objective_id] = 0
	GameManager.quest_progress_updated.emit(quest.quest_id, quest.get_total_progress())

func _set_player_form_mode(enabled: bool):
	var player = get_tree().get_first_node_in_group("PlayerCharacter")
	if player and player.has_method("freeze_for_dialogue"):
		player.freeze_for_dialogue(enabled)
	if player and player.has_method("set_weapon_active"):
		player.set_weapon_active(not enabled)
	if enabled:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		if player and player.has_method("should_use_fps_mouse_capture") and player.should_use_fps_mouse_capture():
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_submit_pressed() -> void:
	if _is_submitting:
		return
	_is_submitting = true
	submit_button.disabled = true
	submit_button.text = "Behandler..."
	await get_tree().process_frame
	await _validate_and_submit(false)

func _on_clear_button_pressed():
	signature_points.clear()
	signature_break_indices.clear()
	signature_has_content = false
	signature_out_of_bounds = false
	_is_drawing_signature = false
	signature_frame.add_theme_stylebox_override("panel", _default_box_style)
	signature_box.queue_redraw()
	status_label.text = ""
	_show_field_error("")

func _on_rejection_ok_button_pressed():
	if not _is_resolved:
		_finish_hard_fail()
	_set_player_form_mode(false)
	queue_free()

func _on_signature_box_gui_input(event: InputEvent):
	if _is_resolved:
		return
	var local_rect := Rect2(Vector2.ZERO, signature_box.size)
	signature_rect = local_rect

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_is_drawing_signature = event.pressed
		if _is_drawing_signature:
			if not signature_points.is_empty():
				signature_break_indices.append(signature_points.size())
			var point = event.position
			if local_rect.has_point(point):
				signature_points.append(point)
				signature_has_content = true
			else:
				signature_out_of_bounds = true
				signature_frame.add_theme_stylebox_override("panel", _signature_error_style)
		signature_box.queue_redraw()
		return

	if event is InputEventMouseMotion and _is_drawing_signature:
		var point = event.position
		if local_rect.has_point(point):
			signature_points.append(point)
			signature_has_content = true
		else:
			signature_out_of_bounds = true
			signature_frame.add_theme_stylebox_override("panel", _signature_error_style)
		signature_box.queue_redraw()

func _on_signature_box_mouse_exited():
	_is_drawing_signature = false

func _on_signature_box_draw():
	signature_box.draw_rect(Rect2(Vector2.ZERO, signature_box.size), Color.WHITE, true)
	signature_box.draw_rect(Rect2(Vector2.ZERO, signature_box.size), Color.BLACK, false, 1.0)
	if signature_points.size() < 2:
		return
	for i in range(1, signature_points.size()):
		if signature_break_indices.has(i):
			continue
		signature_box.draw_line(signature_points[i - 1], signature_points[i], Color.BLACK, SIGNATURE_LINE_WIDTH)

func _make_border_style(border_color: Color, bg_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_content_margin_all(6)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	return style


func _signature_valid() -> bool:
	if signature_out_of_bounds:
		return false
	if not signature_has_content:
		signature_frame.add_theme_stylebox_override("panel", _signature_error_style)
		return false
	signature_frame.add_theme_stylebox_override("panel", _default_box_style)
	return true


func _validate_all_fields() -> String:
	if question_labels.size() != input_fields.size():
		return "Skjemafeil: antall spørsmål stemmer ikke."
	for i in range(question_labels.size()):
		var question := question_labels[i].text.strip_edges()
		var value := input_fields[i].text.strip_edges()
		var error := _validate_field_by_question(question, value)
		if error != "":
			return error
	return ""


func _qerr(question: String, detail: String) -> String:
	return "«%s» — %s" % [question, detail]


func _validate_field_by_question(question: String, value: String) -> String:
	var lower := value.to_lower()

	match question:
		"Fullt navn:":
			if value.is_empty():
				return _qerr(question, "feltet kan ikke være tomt.")
			for c in value:
				if c >= "0" and c <= "9":
					return _qerr(question, "navn kan ikke inneholde tall.")
			var name_regex := RegEx.new()
			name_regex.compile("^[A-Za-zÆØÅæøå ]+$")
			if name_regex.search(value) == null:
				return _qerr(question, "navn kan kun inneholde bokstaver og mellomrom.")
			if value != String(GameManager.player_name):
				return _qerr(question, "navnet stemmer ikke med registrert spillernavn.")

		"Fødselsdato:":
			if value.is_empty():
				return _qerr(question, "feltet kan ikke være tomt.")
			for c in value:
				if c != "." and not (c >= "0" and c <= "9"):
					return _qerr(question, "bruk kun tall og punktum (DD.MM.ÅÅÅÅ).")
			var date_regex := RegEx.new()
			date_regex.compile("^\\d{2}\\.\\d{2}\\.\\d{4}$")
			if date_regex.search(value) == null:
				return _qerr(question, "bruk formatet DD.MM.ÅÅÅÅ.")

		"Adresse:":
			if value.is_empty():
				return _qerr(question, "feltet kan ikke være tomt.")
			var has_letter := false
			var has_number := false
			for c in value:
				if c >= "0" and c <= "9":
					has_number = true
				elif c.is_subsequence_of("abcdefghijklmnopqrstuvwxyzæøåABCDEFGHIJKLMNOPQRSTUVWXYZÆØÅ"):
					has_letter = true
			if not has_number:
				return _qerr(question, "adressen må inneholde gatenummer.")
			if not has_letter:
				return _qerr(question, "adressen må inneholde gatenavn.")

		"Postnummer:":
			if value.length() != 4:
				return _qerr(question, "postnummer må være nøyaktig 4 siffer.")
			if not value.is_valid_int():
				return _qerr(question, "postnummer kan kun inneholde tall.")

		"Telefonnummer:":
			if value.length() != 8:
				return _qerr(question, "telefonnummer må være nøyaktig 8 siffer.")
			if not value.is_valid_int():
				return _qerr(question, "telefonnummer kan kun inneholde tall.")

		"E-postadresse:":
			if value.is_empty():
				return _qerr(question, "feltet kan ikke være tomt.")
			if not value.contains("@"):
				return _qerr(question, "e-post må inneholde @.")
			var at_idx := value.find("@")
			var dot_idx := value.rfind(".")
			if at_idx <= 0 or dot_idx <= at_idx + 1 or dot_idx >= value.length() - 1:
				return _qerr(question, "ugyldig e-postadresse.")

		"Favorittfarge på brød:":
			if value.is_empty():
				return _qerr(question, "feltet kan ikke være tomt.")
			var color_regex := RegEx.new()
			color_regex.compile("^[A-Za-zÆØÅæøå ]+$")
			if color_regex.search(value) == null:
				return _qerr(question, "bruk bare bokstaver (ingen tall eller spesialtegn).")

		"Antall ganger du har tenkt på elg denne uken:":
			if value.is_empty():
				return _qerr(question, "feltet kan ikke være tomt.")
			if not value.is_valid_int():
				return _qerr(question, "skriv et heltall (kun tall, ingen bokstaver).")

		"Beskriv lukten av en mandag:":
			if value.length() < 3:
				return _qerr(question, "utdyp svaret (minst tre tegn).")

		"Hva er din mening om grus som matvare?":
			if lower != "ja" and lower != "nei":
				return _qerr(question, "svar «ja» eller «nei».")

		"Oppgi din nærmeste nabos bilmerke:":
			if value.is_empty():
				return _qerr(question, "feltet kan ikke være tomt.")
			var brand_regex := RegEx.new()
			brand_regex.compile("^[A-Za-zÆØÅæøå ]+$")
			if brand_regex.search(value) == null:
				return _qerr(question, "bruk bare bokstaver (ingen tall).")

		"Hvorfor er du her?":
			if value.length() < 5:
				return _qerr(question, "utdyp svaret (minst fem tegn).")

		"Hva er egentlig penger?":
			if value.length() < 3:
				return _qerr(question, "utdyp svaret.")

		"Hadde du fortjent dette stipendet?":
			if lower == "nei":
				return "HARD_FAIL:Søknaden er avvist. Du innrømmet selv at du ikke fortjener det."
			if lower != "ja" and lower != "nei":
				return _qerr(question, "svar «ja» eller «nei».")

		"Er du sikker på at dette er riktig valg?":
			if lower == "nei":
				return "HARD_FAIL:Søknaden er avvist. Du var ikke sikker nok."
			if lower != "ja" and lower != "nei":
				return _qerr(question, "svar «ja» eller «nei».")

		"Hva ville mormor ha sagt?":
			if value.length() < 3:
				return _qerr(question, "utdyp svaret (minst tre tegn).")

	return ""


func _show_field_error(message: String) -> void:
	if error_label == null:
		return
	error_label.text = message
	error_label.modulate = Color(1, 0, 0, 1)
	error_label.visible = not message.is_empty()
	if not message.is_empty():
		_play_ephemeral_result_sound(error_sound)


func _play_ephemeral_result_sound(stream: AudioStream) -> void:
	if stream == null:
		return
	var audio := AudioStreamPlayer.new()
	add_child(audio)
	audio.stream = stream
	audio.play()
	audio.finished.connect(func (): audio.queue_free())
