extends CanvasLayer

const TOTAL_TIME := 45.0
const SIGNATURE_LINE_WIDTH := 2.0
const TIMER_WARNING_SECONDS := 15.0

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

@onready var form_panel: PanelContainer = $FormPanel
@onready var questions_container: VBoxContainer = $FormPanel/Margin/RootVBox/QuestionsVBox
@onready var timer_label: Label = $FormPanel/Margin/RootVBox/HeaderHBox/TimerLabel
@onready var status_label: Label = $FormPanel/Margin/RootVBox/StatusLabel
@onready var signature_frame: PanelContainer = $FormPanel/Margin/RootVBox/SignatureFrame
@onready var signature_box: Control = $FormPanel/Margin/RootVBox/SignatureFrame/SignatureBox
@onready var submit_button: Button = $FormPanel/Margin/RootVBox/FooterHBox/SubmitButton
@onready var clear_button: Button = $FormPanel/Margin/RootVBox/FooterHBox/ClearButton
@onready var rejection_overlay: ColorRect = $FormPanel/RejectionOverlay
@onready var rejection_reason_label: Label = $FormPanel/RejectionOverlay/Dialog/Margin/VBox/ReasonLabel
@onready var rejection_extra_label: Label = $FormPanel/RejectionOverlay/Dialog/Margin/VBox/ExtraLabel

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
	form_panel.visible = true
	if submit_button and not submit_button.pressed.is_connected(_on_submit_button_pressed):
		submit_button.pressed.connect(_on_submit_button_pressed)
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
	if _time_remaining <= 0.0:
		_submit_form(true)

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
		var box: PanelContainer = get_node(path)
		box.add_theme_stylebox_override("panel", _default_box_style)
	signature_frame.add_theme_stylebox_override("panel", _default_box_style)
	$FormPanel/RejectionOverlay/Dialog.add_theme_stylebox_override("panel", _rejection_style)

func _reset_form_state():
	_is_resolved = false
	_closed_with_end_call = false
	_time_remaining = TOTAL_TIME
	_update_timer_label()
	rejection_overlay.hide()
	rejection_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

func _submit_form(from_timeout: bool = false):
	if _is_resolved:
		return
	var empty_fields: Array[LineEdit] = []
	for field in input_fields:
		var empty := field.text.strip_edges() == ""
		field.add_theme_stylebox_override("normal", _empty_field_style if empty else _default_line_edit_style)
		if empty:
			empty_fields.append(field)

	if not empty_fields.is_empty():
		if from_timeout:
			_show_rejection("Tiden er ute. Søknaden avvist.", "Tips: Skriv raskere neste gang.")
			return
		status_label.text = "Søknaden er ufullstendig."
		return

	if signature_out_of_bounds:
		var extra := "Tips: Skriv raskere neste gang." if from_timeout else ""
		_show_rejection("Signaturen er utenfor boksen.\nSøknaden er avvist.", extra)
		return

	if not signature_has_content:
		if from_timeout:
			_show_rejection("Tiden er ute. Søknaden avvist.", "Tips: Skriv raskere neste gang.")
			return
		signature_frame.add_theme_stylebox_override("panel", _signature_error_style)
		status_label.text = "Signatur mangler."
		return

	status_label.text = "Søknaden er godkjent!"
	await get_tree().create_timer(1.5).timeout
	_finish_success()

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

func _show_rejection(reason: String, extra: String = ""):
	rejection_reason_label.text = reason
	rejection_extra_label.text = extra
	rejection_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	rejection_overlay.show()
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

func _on_submit_button_pressed():
	print("Send button pressed")
	_submit_form(false)

func _on_clear_button_pressed():
	signature_points.clear()
	signature_break_indices.clear()
	signature_has_content = false
	signature_out_of_bounds = false
	_is_drawing_signature = false
	signature_frame.add_theme_stylebox_override("panel", _default_box_style)
	signature_box.queue_redraw()
	status_label.text = ""

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
