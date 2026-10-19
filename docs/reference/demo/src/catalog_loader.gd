class_name CatalogLoader
## Shared catalog-array reader (ADR-0003: "_read_catalog_array() — shared
## helper, reused by every catalog loader"). Flagged as tech debt in this
## session's code review of battle_map.gd (which had hand-rolled this same
## open/parse/guard sequence independently) — extracted here so weapon_item.gd
## is the first caller instead of a fourth duplicate.

## Returns the parsed JSON array on success, or null after calling
## Validate.fatal() on failure — callers must check for null and bail
## themselves (Validate.fatal() only schedules quit(), it does not stop
## execution synchronously).
static func read_array(path: String, context: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		Validate.fatal(context, "cannot open %s" % path)
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Array:
		Validate.fatal(context, "root must be an array")
		return null
	return parsed
