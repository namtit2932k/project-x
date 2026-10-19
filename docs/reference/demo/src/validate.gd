class_name Validate
## Project-wide fail-loud-at-load policy (ADR-0004). Static-only, no autoload,
## no instance state — callable from anywhere as Validate.require_field(...).
## Never used for Save/Progression's recoverable load path (ADR-0001) or for
## player-input rejections — authored/static content only.

static func fatal(context: String, message: String) -> void:
	var full_message := "[%s] %s" % [context, message]
	push_error(full_message)
	OS.alert(full_message, "Data Validation Error")
	(Engine.get_main_loop() as SceneTree).quit(1)
	# quit() SCHEDULES an exit at end-of-frame — it does not halt execution
	# synchronously. Every call site must `return` immediately after calling
	# fatal() (direct or via a require_* helper), never assume it already ended.


static func require_field(record: Dictionary, field: String, context: String) -> void:
	if not record.has(field):
		fatal(context, "missing required field: %s" % field)


static func require_range(value, min_v, max_v, field: String, context: String) -> void:
	if value < min_v or value > max_v:
		fatal(context, "%s=%s out of range [%s, %s]" % [field, value, min_v, max_v])


static func require_unique(id: String, seen: Dictionary, context: String) -> void:
	if seen.has(id):
		fatal(context, "duplicate id: %s" % id)
