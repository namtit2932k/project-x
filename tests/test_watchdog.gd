extends Node
class_name TestWatchdog
## Every headless test / tool run must end. A parse error in the test script (or in anything it
## depends on) used to leave the root node without a script, so nothing ever called quit() and
## the runner hung; a coroutine that never resumes did the same. This node sits under the root
## of each test scene: it fails the run at once when the root script did not load, and after
## `timeout_sec` otherwise. Exit code 1 and a "FAIL:" line either way.

@export var timeout_sec: float = 600.0


func _ready() -> void:
	var problem := root_problem(get_parent())
	if problem != "":
		_fail(problem)
		return
	# process_always: still fires while the tree is paused; ignore_time_scale: real seconds.
	get_tree().create_timer(timeout_sec, true, false, true).timeout.connect(func() -> void:
		_fail("the run did not finish within %d s (an await that never returned?)" % int(timeout_sec)))


## "" when the test root has a usable script, else what is wrong.
static func root_problem(root: Node) -> String:
	if root == null:
		return "the watchdog has no test node above it"
	var script: Script = root.get_script()
	if script == null:
		return "the script of %s did not load - look for a Parse Error above" % root.name
	if not script.can_instantiate():
		return "the script of %s cannot run - look for a Parse Error above" % root.name
	return ""


func _fail(reason: String) -> void:
	print("FAIL: watchdog: %s" % reason)
	push_error("TestWatchdog: %s" % reason)
	get_tree().quit(1)
