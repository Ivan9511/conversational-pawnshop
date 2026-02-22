extends Node

var _dere_threshold := 15


var dere := {
	"tsundere": 25,
	"deredere": 25,
	"kudere": 25,
	"dandere": 25
}


func change_dere_score(dere_type: String, value: int):
	if dere.has(dere_type):
		dere[dere_type] = clamp(dere[dere_type] + value, 0, 100)


func current_dere() -> String:
	var sorted := dere.keys()
	sorted.sort_custom(func(a, b): return dere[a] > dere[b])

	var first = sorted[0]
	var second = sorted[1]

	if dere[first] - dere[second] >= _dere_threshold:
		return first

	return "neutral"
