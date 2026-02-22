extends Control
class_name CashboxGameUI

signal action_pressed
signal answer_pressed(slot: int)

@onready var first_answer_button: Button = $MainMarginContainer/ButtonsMarginContainer/AnswerVBoxContainer/FirstAnswerButton
@onready var second_answer_button: Button = $MainMarginContainer/ButtonsMarginContainer/AnswerVBoxContainer/SecondAnswerButton

@onready var bubble: DialogueBubble = $DialogueBubbleMarginContainer/DialogueBubble


func _ready() -> void:
	first_answer_button.pressed.connect(func(): _on_answer_button_pressed(0))
	second_answer_button.pressed.connect(func(): _on_answer_button_pressed(1))
	pass

func _on_answer_button_pressed(slot: int) -> void:
	print("[UI] answer pressed slot:", slot)
	answer_pressed.emit(slot)


func _on_action_button_pressed() -> void:
	print("[UI] action pressed")
	action_pressed.emit()


func set_answers(answers: Array):
	first_answer_button.text = answers[0].get("text")
	second_answer_button.text = answers[1].get("text")

func set_answer_page(text0: String, text1: String, enabled0: bool, enabled1: bool) -> void:
	first_answer_button.text = text0
	second_answer_button.text = text1
	first_answer_button.disabled = not enabled0
	second_answer_button.disabled = not enabled1


func set_dialogue(speaker_name: String, text: String) -> void:
	bubble.set_dialogue(speaker_name, text)
