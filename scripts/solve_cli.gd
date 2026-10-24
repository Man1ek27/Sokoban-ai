extends SceneTree

## Headless entry point; loads no game scene or HUD.
const Solver = preload("res://scripts/astar_solver.gd")
const Level = preload("res://scripts/level_data.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 1 and args[0] == "--help":
		print("solve_cli.gd -- <level.json> [steps|energy] [max_expanded=100000] [time_limit_ms=5000]")
		quit(0)
		return
	if args.is_empty() or args.size() > 4:
		_fail("Podaj plik poziomu oraz opcjonalnie: steps|energy, limit stanow, limit ms.")
		return
	var mode_name := args[1] if args.size() >= 2 else "steps"
	if mode_name not in ["steps", "energy"]:
		_fail("Tryb kosztu musi miec wartosc steps albo energy.")
		return
	var max_expanded := 100000
	var time_limit_ms := 5000
	if args.size() >= 3:
		if not args[2].is_valid_int() or args[2].to_int() <= 0:
			_fail("Limit stanow musi byc dodatnia liczba calkowita.")
			return
		max_expanded = args[2].to_int()
	if args.size() >= 4:
		if not args[3].is_valid_int() or args[3].to_int() <= 0:
			_fail("Limit czasu musi byc dodatnia liczba calkowita.")
			return
		time_limit_ms = args[3].to_int()
	var file := FileAccess.open(args[0], FileAccess.READ)
	if file == null:
		_fail("Nie mozna otworzyc poziomu: %s" % args[0])
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or not data.get("map") is Array:
		_fail("Poziom musi byc obiektem JSON z tablica map.")
		return
	var level := Level.from_dictionary(data)
	var mode := Solver.CostMode.ENERGY if mode_name == "energy" else Solver.CostMode.STEPS
	var result := Solver.new().solve(level, null, mode, Callable(), max_expanded, time_limit_ms)
	# Vector2i and INF do not have standard JSON representations.
	var actions: Array = []
	for direction in result["actions"]:
		actions.append([direction.x, direction.y])
	result["actions"] = actions
	if not is_finite(float(result["cost"])):
		result["cost"] = null
	result["cost_mode"] = mode_name
	result["cost_unit"] = "J" if mode_name == "energy" else "moves"
	print(JSON.stringify(result))
	var exit_code := 0 if result["success"] else 1
	if result["status"] in ["invalid_input", "invalid_heuristic"]:
		exit_code = 2
	quit(exit_code)

func _fail(message: String) -> void:
	print(JSON.stringify({"success": false, "status": "invalid_input", "message": message}))
	quit(2)
