extends Node


# CACHE
var questions: Dictionary = {} # id -> Dictionary
var answers: Dictionary = {}   # id -> Dictionary (answer-block)
var branches: Dictionary = {}  # id -> Dictionary (branch)


# INDEXES
var questions_by_scene: Dictionary = {}      # scene -> Array[Dictionary(question)]
var answers_by_question: Dictionary = {}     # question_id -> Array[Dictionary(answer-block)]
var answers_by_id: Dictionary = {}           # answer_id -> Dictionary(answer-block)
var branches_by_answer: Dictionary = {}      # answer_id -> Dictionary(branch)

var _initialized: bool = false


# INIT
func initialize() -> void:
	if _initialized:
		return
	_load_all()
	_build_indexes()
	_initialized = true
	print("DialogueManager initialized")



# PUBLIC: CONTEXT
func make_context(npc: Variant, player: Variant, store: Variant, flags: Dictionary = {}) -> Dictionary:
	var ctx: Dictionary = {}
	ctx["npc"] = npc
	ctx["player"] = player
	ctx["store"] = store
	ctx["flags"] = flags.duplicate(true)
	return ctx



# PUBLIC: QUESTION
# Retuurn ready question-DTO (Dictionary):
# { id, theme, scene, text:String, requirements:Dictionary, answer_id:String }
func get_question(npc: Variant, scene: String, player: Variant = null, store: Variant = null, flags: Dictionary = {}) -> Variant:
	if not _initialized:
		initialize()

	var ctx := make_context(npc, player, store, flags)

	if not questions_by_scene.has(scene):
		return null

	var pool: Array = []
	var scene_questions: Array = questions_by_scene[scene]

	for q in scene_questions:
		var req: Dictionary = q.get("requirements", {})
		if _check_requirements(req, ctx):
			pool.append(q)

	if pool.is_empty():
		return null

	var chosen: Dictionary = pool.pick_random()
	return _make_question_dto(chosen)



# PUBLIC: ANSWER OPTIONS (готовые опции для UI)
# Return Array[Dictionary]:
# { answer_id, dere_type, display_text, effects, is_end }
func get_answer_options(question: Dictionary, ctx: Dictionary, max_options: int = 6) -> Array:
	if not _initialized:
		initialize()

	if question.is_empty():
		return []

	var blocks: Array = _get_answer_blocks_for_question(question)

	# filter by requirements
	var filtered: Array = []
	for ab in blocks:
		var req: Dictionary = ab.get("requirements", {})
		if _check_requirements(req, ctx):
			filtered.append(ab)

	if filtered.is_empty():
		return []

	var result: Array = []
	var player_dere: String = _get_player_dere(ctx.get("player", null))

	for ab in filtered:
		if result.size() >= max_options:
			break

		var variants: Array = ab.get("variants", [])
		if variants.is_empty():
			continue

		# dere -> variant
		var by_dere: Dictionary = {}
		for v in variants:
			var d := str(v.get("dere", ""))
			if d != "":
				by_dere[d] = v

		var used: Array = []
		var first_variant: Variant = _select_first_variant(by_dere, player_dere)

		if first_variant != null:
			result.append(_make_answer_option_dto(ab, first_variant))
			used.append(str(first_variant.get("dere", "")))

		for v in variants:
			if result.size() >= max_options:
				break
			var d2 := str(v.get("dere", ""))
			if d2 == "" or used.has(d2):
				continue
			result.append(_make_answer_option_dto(ab, v))
			used.append(d2)

	if result.is_empty():
		return []

	_shuffle_except_first(result)
	return result



# PUBLIC: BRANCH VARIANT
# Return variant (Dictionary)
func get_branch_variant(answer_id: String, player: Variant = null) -> Variant:
	if not _initialized:
		initialize()

	if not branches_by_answer.has(answer_id):
		return null

	var branch: Dictionary = branches_by_answer[answer_id]

	# поддержка ключей variant/variants (на всякий)
	var variants: Array = []
	if branch.has("variant"):
		variants = branch.get("variant", [])
	else:
		variants = branch.get("variants", [])

	if variants.is_empty():
		return null

	var dere: String = _get_player_dere(player)

	for v in variants:
		if str(v.get("dere", "")) == dere:
			return v

	return variants[0]



# PUBLIC: EFFECTS
# effects = { player:{...}, store:{...}, ... }
func apply_effects(effects: Dictionary, ctx: Dictionary) -> void:
	if effects.is_empty():
		return

	var player: Variant = ctx.get("player", null)
	var store: Variant = ctx.get("store", null)

	if effects.has("player") and player != null:
		var pe: Dictionary = effects["player"]
		for k in pe:
			_apply_player_effect(player, str(k), pe[k])

	if effects.has("store") and store != null:
		var se: Dictionary = effects["store"]
		for k2 in se:
			_apply_numeric_delta(store, str(k2), se[k2])



# LOAD / INDEX
func _load_all() -> void:
	questions = _load_json_as_dict("res://content/dialogues/ru/npc_questions.json")
	answers   = _load_json_as_dict("res://content/dialogues/ru/player_answers.json")
	branches  = _load_json_as_dict("res://content/dialogues/ru/dialogue_branches.json")


func _load_json_as_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("DialogueManager: file not found -> " + path)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DialogueManager: failed to open -> " + path)
		return {}

	var text := file.get_as_text()
	var data = JSON.parse_string(text)

	if typeof(data) != TYPE_ARRAY:
		push_error("DialogueManager: invalid JSON (expected Array) -> " + path)
		return {}

	var dict: Dictionary = {}
	for e in data:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var id := str(e.get("id", ""))
		if id == "":
			continue
		dict[id] = e

	return dict


func _build_indexes() -> void:
	questions_by_scene.clear()
	answers_by_question.clear()
	answers_by_id.clear()
	branches_by_answer.clear()

	for q in questions.values():
		var scene := str(q.get("scene", ""))
		if not questions_by_scene.has(scene):
			questions_by_scene[scene] = []
		questions_by_scene[scene].append(q)

	for a in answers.values():
		var aid := str(a.get("id", ""))
		if aid != "":
			answers_by_id[aid] = a

		var qid := str(a.get("question_id", ""))
		if qid == "":
			continue
		if not answers_by_question.has(qid):
			answers_by_question[qid] = []
		answers_by_question[qid].append(a)

	for b in branches.values():
		var answer_id := str(b.get("answer_id", ""))
		if answer_id == "":
			continue
		branches_by_answer[answer_id] = b


# REQUIREMENTS
func _check_requirements(req: Dictionary, ctx: Dictionary) -> bool:
	if req.is_empty():
		return true

	for group in req.keys():
		var g := str(group)
		match g:
			"npc":
				if not _check_block(req[g], ctx.get("npc", null)):
					return false
			"player":
				if not _check_block(req[g], ctx.get("player", null)):
					return false
			"store":
				if not _check_block(req[g], ctx.get("store", null)):
					return false
			"flags":
				if not _check_block(req[g], ctx.get("flags", {})):
					return false
			_:
				return false

	return true


func _values_equal(expected: Variant, actual: Variant) -> bool:
	if (typeof(expected) == TYPE_STRING or typeof(expected) == TYPE_STRING_NAME) \
	and (typeof(actual) == TYPE_STRING or typeof(actual) == TYPE_STRING_NAME):

		return str(actual).to_lower() == str(expected).to_lower()

	return actual == expected


func _check_block(block: Dictionary, target: Variant) -> bool:
	if block.is_empty():
		return true
	if target == null:
		return false

	for k in block.keys():
		var key := str(k)
		var expected = block[k]
		var actual = _get_prop(target, key)

		if not _values_equal(expected, actual):
			return false

	return true


func _get_prop(target: Variant, key: String) -> Variant:
	if target == null:
		return null

	if typeof(target) == TYPE_DICTIONARY:
		var d: Dictionary = target
		return d.get(key, null)

	if target is Object:
		var obj: Object = target

		if obj.has_method("get"):
			var v = obj.get(key)
			if v != null:
				return v

		# fallback: проверить, что свойство вообще существует
		var props: Array = obj.get_property_list()
		for p in props:
			if str(p.name) == key:
				return obj.get(key)

	return null


# DTO BUILDERS (Dictionary)
func _make_question_dto(q: Dictionary) -> Dictionary:
	var dto: Dictionary = {}
	dto["id"] = str(q.get("id", ""))
	dto["theme"] = str(q.get("theme", ""))
	dto["scene"] = str(q.get("scene", ""))
	dto["requirements"] = q.get("requirements", {}).duplicate(true)
	dto["answer_id"] = str(q.get("answer_id", ""))

	var texts: Array = q.get("text", [])
	dto["text"] = str(texts.pick_random()) if texts.size() > 0 else ""

	return dto


func _make_answer_option_dto(answer_block: Dictionary, variant: Dictionary) -> Dictionary:
	var dto: Dictionary = {}
	dto["answer_id"] = str(answer_block.get("id", ""))
	dto["dere_type"] = str(variant.get("dere", ""))
	dto["is_end"] = bool(answer_block.get("is_end", false))

	var effects: Dictionary = {}
	if variant.has("effects"):
		effects = variant.get("effects", {}).duplicate(true)
	dto["effects"] = effects

	var arr: Array = variant.get("text", [])
	dto["display_text"] = str(arr.pick_random()) if arr.size() > 0 else "[no text]"

	return dto


# ANSWERS: selection rules
func _get_answer_blocks_for_question(question: Dictionary) -> Array:
	# priority 1: question.answer_id
	var aid := str(question.get("answer_id", ""))
	if aid != "":
		if question["answer_id"] is Array:
			var res0: Array = []
			var ids_arr: Array = question["answer_id"]
			for x in ids_arr:
				var id0 := str(x)
				if answers_by_id.has(id0):
					res0.append(answers_by_id[id0])
			if not res0.is_empty():
				return res0

		if aid.find(",") != -1:
			var res1: Array = []
			var parts := aid.split(",", false)
			for s in parts:
				var id1 := s.strip_edges()
				if answers_by_id.has(id1):
					res1.append(answers_by_id[id1])
			if not res1.is_empty():
				return res1

		if answers_by_id.has(aid):
			return [answers_by_id[aid]]

	# fallback: by question_id
	var qid := str(question.get("id", ""))
	if qid != "" and answers_by_question.has(qid):
		return answers_by_question[qid]

	return []


func _select_first_variant(by_dere: Dictionary, player_dere: String) -> Variant:
	# player_dere == neutral -> neutral
	if player_dere == "neutral":
		return by_dere.get("neutral", null)

	var roll := randf()

	# 50% neutral
	if roll < 0.5:
		if by_dere.has("neutral"):
			return by_dere["neutral"]
		return by_dere.get(player_dere, null)

	# 50% player_dere
	if by_dere.has(player_dere):
		return by_dere[player_dere]

	return by_dere.get("neutral", null)


func _shuffle_except_first(options: Array) -> void:
	if options.size() <= 2:
		return
	var sub: Array = []
	for i in range(1, options.size()):
		sub.append(options[i])
	sub.shuffle()
	for j in range(sub.size()):
		options[j + 1] = sub[j]


# DERE / EFFECT APPLY
func _get_player_dere(player: Variant) -> String:
	if player == null:
		return "neutral"
	if player is Object:
		var obj: Object = player
		if obj.has_method("current_dere"):
			return str(obj.call("current_dere"))
	# fallback: if property exists
	var dt = _get_prop(player, "dere_type")
	if dt != null and str(dt) != "":
		return str(dt)
	return "neutral"


func _apply_player_effect(player: Variant, key: String, delta) -> void:
	if player is Object:
		var obj: Object = player
		if obj.has_method("change_dere_score"):
			obj.call("change_dere_score", key, int(delta))
			return

	_apply_numeric_delta(player, key, delta)


func _apply_numeric_delta(target: Variant, key: String, delta) -> void:
	if target == null:
		return

	if typeof(target) == TYPE_DICTIONARY:
		var d: Dictionary = target
		var oldv := float(d.get(key, 0.0))
		d[key] = oldv + float(delta)
		return

	if target is Object:
		var obj: Object = target
		if obj.has_method("get") and obj.has_method("set"):
			var old = obj.get(key)
			if typeof(old) == TYPE_INT:
				obj.set(key, int(old) + int(delta))
				return
			if typeof(old) == TYPE_FLOAT:
				obj.set(key, float(old) + float(delta))
				return
