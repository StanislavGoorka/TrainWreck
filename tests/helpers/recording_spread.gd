## A BookSpread that counts how often the book opened it.
extends BookSpread

var opened_count := 0


func opened() -> void:
	opened_count += 1
