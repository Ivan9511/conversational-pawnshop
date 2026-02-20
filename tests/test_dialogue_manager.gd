@tool
extends EditorScript

var manager: Node

# ───────────────────────────────
# MOCK DATA
# ───────────────────────────────
class MockNPC:
	var gender := "Male"
	var favorite_dere_type := "tsundere"
	var unique_name := "Franklin"

class MockPlayer:
	var dere := {"tsundere": 50, "deredere": 25, "kudere": 25, "dandere": 25}
	func current_dere() -> String: return "tsundere"
	func change_dere_score(dere_type: String, value: int) -> void:
		dere[dere_type] = dere.get(dere_type, 0) + int(value)


# ───────────────────────────────
# ASSERT HELPERS
# ───────────────────────────────
var _fails := 0
var _passes := 0

func _ok(msg: String) -> void:
	_passes += 1
	print("✔ " + msg)

func _fail(msg: String) -> void:
	_fails += 1
	push_error("❌ " + msg)

func assert_true(condition: bool, msg: String) -> void:
	if condition:
		_ok(msg)
	else:
		_fail(msg)

func assert_not_null(v, msg: String) -> void:
	assert_true(v != null, msg)

func assert_equals(a, b, msg: String) -> void:
	assert_true(a == b, msg + " | got=" + str(a) + " expected=" + str(b))


# ───────────────────────────────
# RUN
# ───────────────────────────────
func _run() -> void:
	print("\n===== DialogueManager EDITOR TESTS (NEW) =====")

	manager = load("res://core/managers/DialogueManager.gd").new()
	manager.initialize()

	test_initialization()
	test_indexes()
	test_requirements_ignore_case()
	test_question_selection()
	test_answer_options()
	test_branch_variant()
	test_effects()

	_print_summary()


func _print_summary() -> void:
	print("===== TESTS FINISHED =====")
	print("Pass:", _passes, " Fail:", _fails)
	if _fails > 0:
		push_error("DialogueManager tests FAILED: " + str(_fails))
	else:
		print("All DialogueManager tests PASSED ✅")


# ───────────────────────────────
# TESTS
# ───────────────────────────────
func test_initialization() -> void:
	assert_true(manager._initialized, "Manager initialized")
	assert_true(manager.questions.size() > 0, "Questions loaded")
	assert_true(manager.answers.size() > 0, "Answers loaded")
	assert_true(manager.branches.size() > 0, "Branches loaded")


func test_indexes() -> void:
	assert_true(manager.questions_by_scene.size() > 0, "questions_by_scene built")
	assert_true(manager.answers_by_question.size() > 0, "answers_by_question built")
	assert_true(manager.branches_by_answer.size() > 0, "branches_by_answer built")


func test_requirements_ignore_case() -> void:
	var npc = MockNPC.new()
	var player = MockPlayer.new()
	var ctx: Dictionary = manager.make_context(npc, player, null)

	var req := {"npc": {"gender": "male"}}
	var ok: bool = manager._check_requirements(req, ctx)
	assert_true(ok, "Requirements ignore case for strings (Male vs male)")


func test_question_selection() -> void:
	var npc = MockNPC.new()
	var player = MockPlayer.new()

	var q = manager.get_question(npc, "cashbox_game", player, null)
	assert_not_null(q, "Question selected for scene cashbox_game")

	assert_true(typeof(q.get("text", null)) == TYPE_STRING, "QuestionDTO.text is String (randomized)")
	print("Question:", q)


func test_answer_options() -> void:
	var npc = MockNPC.new()
	var player = MockPlayer.new()

	var q = manager.get_question(npc, "cashbox_game", player, null)
	if q == null:
		_fail("Answer options: question is null, cannot test")
		return

	var ctx: Dictionary = manager.make_context(npc, player, null)
	var options: Array = manager.get_answer_options(q, ctx, 6)

	assert_true(options.size() > 0, "Answer options generated")
	assert_true(options.size() <= 6, "Answer options <= 6")
	print("Options:")
	for i in range(options.size()):
		print("  [", i, "]", options[i])


func test_branch_variant() -> void:
	var player = MockPlayer.new()
	var v = manager.get_branch_variant("a_test", player)
	assert_not_null(v, "Branch variant selected for a_test")
	assert_true(v.has("dialogue"), "Branch variant has dialogue")
	print("Branch variant:", v)


func test_effects() -> void:
	var npc = MockNPC.new()
	var player = MockPlayer.new()
	var ctx: Dictionary = manager.make_context(npc, player, null)

	var effects := {"player": {"tsundere": 5}}
	manager.apply_effects(effects, ctx)

	assert_equals(player.dere["tsundere"], 55, "Effects applied to player")
