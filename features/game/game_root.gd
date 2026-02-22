extends Node2D

@export_dir var npc_data_dir: String = "res://entities/npc/data"
@export_file("PackedScene") var npc_scene_path: String = "res://entities/npc/npc.tscn"

@onready var npc_spawn_point: Node2D = $NpcSpawnPoint
var npc_scene: PackedScene
var rng := RandomNumberGenerator.new()

@onready var ui_scene: Control = $CanvasLayer/GameRootUi

var current_npc: Node2D = null
var current_question: Dictionary = {}
var current_ctx: Dictionary = {}
var dialogue_flags: Dictionary = {}


func _ready() -> void:
	rng.randomize()

	npc_scene = load(npc_scene_path)
	if npc_scene == null:
		push_error("Not loaded NPC scene: %s" % npc_scene_path)
		return

	spawn_random_npc()
	
	start_dialogue()


func spawn_random_npc() -> void:
	var npc_data: NPCData = get_random_npc_data()
	if npc_data == null:
		push_error("Not found .tres in %s" % npc_data_dir)
		return

	var npc_instance: Node2D = npc_scene.instantiate()
	npc_instance.data = npc_data
	npc_instance.global_position = npc_spawn_point.global_position
	add_child(npc_instance)

	current_npc = npc_instance


func get_random_npc_data() -> NPCData:
	var dir := DirAccess.open(npc_data_dir)
	if dir == null:
		push_error("Error open path: %s" % npc_data_dir)
		return null

	var files: Array[String] = []

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	if files.is_empty():
		return null

	var index := rng.randi_range(0, files.size() - 1)
	var resource_path := "%s/%s" % [npc_data_dir, files[index]]

	var npc_data: NPCData = load(resource_path)
	if npc_data == null:
		push_error("Error loading NPCData: %s" % resource_path)
		return null

	return npc_data


func start_dialogue():
	if current_npc == null:
		push_error("start_dialogue: current_npc == null")
		return {}

	var npc_data: NPCData = current_npc.data

	current_ctx = DialogueManager.make_context(
		npc_data,
		PlayerState,
		dialogue_flags
	)

	var question: Variant = DialogueManager.get_question(
		npc_data,
		PlayerState,
		dialogue_flags
	)

	if question == null:
		print("Dialogue: no suitable question for this NPC")
		current_question = {}
		return {}

	current_question = question

	var answers: Array = DialogueManager.get_answers(current_question, current_ctx)
	
	ui_scene.set_dialogue(current_npc.name, current_question.get("text"))
	ui_scene.set_answers(answers)

	print("--- QUESTION ---")
	print(current_question.get("text", ""))
	print("--- ANSWERS ---")
	for o in answers:
		print("- ", o.get("text", ""))
