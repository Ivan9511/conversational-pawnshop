extends Control
class_name DialogueBubble

@onready var name_label: Label = $VBoxContainer/NamePanel/MarginContainer/NameLabel
@onready var text_label: RichTextLabel = $VBoxContainer/TextPanel/MarginContainer/RichTextLabel


func set_dialogue(speaker_name: String, text: String) -> void:
	name_label.text = speaker_name
	text_label.text = text
