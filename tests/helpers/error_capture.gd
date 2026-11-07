## Collects engine and script errors printed while it is installed.
##
## GdUnit4 only fails a test on GDScript runtime errors. Problems such as a scene
## connecting a signal to a missing method, or a missing %UniqueNode, are printed as
## engine errors and would go unnoticed. Use:
##     var capture := ErrorCapture.new()
##     capture.start()
##     ...code under test...
##     var errors := capture.stop()
extends Logger

var _entries: PackedStringArray = []
var _mutex := Mutex.new()
var _installed := false


func start() -> void:
	if not _installed:
		OS.add_logger(self)
		_installed = true


func stop() -> PackedStringArray:
	if _installed:
		OS.remove_logger(self)
		_installed = false
	return _entries


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	var message := rationale if not rationale.is_empty() else code
	_mutex.lock()
	_entries.append("%s  [%s:%d %s]" % [message, file, line, function])
	_mutex.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass
