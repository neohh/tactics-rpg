extends Node

# BattleStateManager — управляет ТОЛЬКО фазами боя и ресурсами хода.
# Не двигает юнитов, не рисует UI, не считает урон.

enum Phase { DEPLOY, PLAYER_TURN, ENEMY_TURN, RESOLVE_STATUS, GAME_OVER }

var current_phase: int = Phase.DEPLOY
var activations_left: int = 2
var is_busy: bool = false
var game_over: bool = false
var winner: String = ""  # "player" или "enemy"

signal phase_changed(phase: int)
signal activations_changed(left: int)
signal game_over_signal(winner: String)

func _ready():
	pass

func start_deploy():
	current_phase = Phase.DEPLOY
	is_busy = false
	game_over = false
	winner = ""
	activations_left = 2
	phase_changed.emit(current_phase)

func start_player_turn():
	if game_over:
		return
	current_phase = Phase.PLAYER_TURN
	activations_left = 2
	is_busy = false
	phase_changed.emit(current_phase)
	activations_changed.emit(activations_left)

func spend_activation() -> bool:
	if current_phase != Phase.PLAYER_TURN:
		return false
	if activations_left <= 0:
		return false
	activations_left -= 1
	activations_changed.emit(activations_left)
	return true

func end_player_turn() -> bool:
	if is_busy:
		return false
	if current_phase != Phase.PLAYER_TURN:
		return false
	is_busy = true
	current_phase = Phase.ENEMY_TURN
	phase_changed.emit(current_phase)
	return true

func start_enemy_turn():
	if game_over:
		return
	current_phase = Phase.ENEMY_TURN
	is_busy = true
	phase_changed.emit(current_phase)

func end_enemy_turn():
	# Этот метод вызывается ВСЕГДА в конце фазы врага, даже если был ранний return
	current_phase = Phase.RESOLVE_STATUS
	phase_changed.emit(current_phase)
	# Здесь можно вызвать обработку статусов (горение и т.д.)
	# После обработки — возврат к игроку
	current_phase = Phase.PLAYER_TURN
	activations_left = 2
	is_busy = false
	phase_changed.emit(current_phase)
	activations_changed.emit(activations_left)

func check_game_over(players_alive: int, enemies_alive: int) -> String:
	if game_over:
		return winner
	if enemies_alive <= 0:
		game_over = true
		winner = "player"
		current_phase = Phase.GAME_OVER
		phase_changed.emit(current_phase)
		game_over_signal.emit(winner)
		return winner
	if players_alive <= 0:
		game_over = true
		winner = "enemy"
		current_phase = Phase.GAME_OVER
		phase_changed.emit(current_phase)
		game_over_signal.emit(winner)
		return winner
	return ""

func can_act() -> bool:
	return current_phase == Phase.PLAYER_TURN and not is_busy and not game_over

func is_player_turn() -> bool:
	return current_phase == Phase.PLAYER_TURN

func is_enemy_turn() -> bool:
	return current_phase == Phase.ENEMY_TURN

func is_deploy() -> bool:
	return current_phase == Phase.DEPLOY

func get_phase_name() -> String:
	match current_phase:
		Phase.DEPLOY: return "DEPLOY"
		Phase.PLAYER_TURN: return "PLAYER_TURN"
		Phase.ENEMY_TURN: return "ENEMY_TURN"
		Phase.RESOLVE_STATUS: return "RESOLVE_STATUS"
		Phase.GAME_OVER: return "GAME_OVER"
	return "UNKNOWN"
