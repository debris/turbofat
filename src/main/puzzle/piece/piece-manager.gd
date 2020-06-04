class_name PieceManager
extends Control
"""
Contains logic for spawning new pieces, moving/rotating pieces, handling player input, and locking pieces into the
playfield.
"""

# emitted when the current piece can't be placed in the _playfield
signal topped_out
signal piece_spawned

# emitted when the player rotates a piece
signal initial_rotated_right
signal initial_rotated_left
signal initial_rotated_twice

# emitted when the player moves a piece
signal initial_das_moved_left
signal initial_das_moved_right
signal das_moved_left
signal das_moved_right
signal moved_left
signal moved_right
signal rotated_left
signal rotated_right
signal soft_dropped
signal hard_dropped
signal squish_moved

# emitted for piece locks
signal lock_cancelled
signal lock_started

var _target_piece_pos: Vector2
var _target_piece_orientation: int

var _gravity_delay_frames := 0

onready var _playfield: Playfield = $"../Playfield"
onready var _next_piece_displays: NextPieceDisplays = $"../NextPieceDisplays"

# settings and state for the currently active piece.
var piece := ActivePiece.new(PieceTypes.piece_null)

# 'true' if the tile map's contents needs to be updated based on the currently active piece
var tile_map_dirty := false

# how many times the piece has moved horizontally this frame
var _horizontal_movement_count := 0

func _ready() -> void:
	PuzzleScore.connect("game_prepared", self, "_on_PuzzleScore_game_prepared")
	PuzzleScore.connect("game_started", self, "_on_PuzzleScore_game_started")
	PuzzleScore.connect("game_ended", self, "_on_PuzzleScore_game_ended")
	
	PieceSpeeds.current_speed = PieceSpeeds.speed("0")
	$States.set_state($States/None)
	_clear_piece()


func _process(_delta: float) -> void:
	if $StretchMap._stretch_seconds_remaining > 0:
		$StretchMap.show()
		$TileMap.hide()
		
		# if the player continues to move the piece, we keep stretching to its new location
		$StretchMap.stretch_to(piece.type.pos_arr[piece.orientation], piece.pos)
	else:
		$StretchMap.hide()
		$TileMap.show()


func _physics_process(_delta: float) -> void:
	_horizontal_movement_count = 0
	
	$States.update()
	
	if tile_map_dirty:
		_update_tile_map()
		tile_map_dirty = false


func get_state() -> State:
	return $States.get_state()


func playfield_ready_for_new_piece() -> bool:
	return _playfield.ready_for_new_piece()


"""
Writes the current piece to the playfield, checking whether it makes any boxes or clears any lines.

Returns true if the newly written piece results in a line clear.
"""
func write_piece_to_playfield() -> void:
	_playfield.write_piece(piece.pos, piece.orientation, piece.type)
	_clear_piece()


"""
Called when the player tops out, but doesn't lose.

Enters a state which waits for the _playfield to make room for the current piece.
"""
func enter_top_out_state(top_out_frames: int) -> void:
	$States.set_state($States/TopOut)
	piece.spawn_delay = top_out_frames


"""
Spawns a new piece at the top of the _playfield.

Returns 'true' if the piece was spawned successfully, or 'false' if the player topped out.
"""
func spawn_piece() -> bool:
	var piece_type := _next_piece_displays.pop_next_piece()
	piece = ActivePiece.new(piece_type)
	tile_map_dirty = true
	
	# apply initial orientation if rotate buttons are pressed
	if $InputCw.is_pressed() or $InputCcw.is_pressed():
		if $InputCw.is_pressed() and $InputCcw.is_pressed():
			piece.orientation = piece.get_flip_orientation(piece.orientation)
			$InputCw.set_input_as_handled()
			$InputCcw.set_input_as_handled()
			emit_signal("initial_rotated_twice")
		elif $InputCw.is_pressed():
			piece.orientation = piece.get_cw_orientation(piece.orientation)
			$InputCw.set_input_as_handled()
			emit_signal("initial_rotated_right")
		elif $InputCcw.is_pressed():
			piece.orientation = piece.get_ccw_orientation(piece.orientation)
			$InputCcw.set_input_as_handled()
			emit_signal("initial_rotated_left")
		
		# relocate rotated piece to the top of the _playfield
		var pos_arr: Array = piece.type.pos_arr[piece.orientation]
		var highest_pos := 3
		for pos in pos_arr:
			if pos.y < highest_pos:
				highest_pos = pos.y
		piece.pos.y -= highest_pos
	
	# apply initial infinite DAS
	var initial_das_dir := 0
	if $InputLeft.is_das_active():
		$InputLeft.set_input_as_handled()
		initial_das_dir -= 1
	if $InputRight.is_das_active():
		$InputRight.set_input_as_handled()
		initial_das_dir += 1
	
	if initial_das_dir == -1:
		# player is holding left; start piece on the left side
		var old_pos := piece.pos
		_reset_piece_target()
		_kick_piece([Vector2(-4, 0), Vector2(-4, -1), Vector2(-3, 0), Vector2(-3, -1),
				Vector2(-2, 0), Vector2(-2, -1), Vector2(-1, 0), Vector2(-1, -1),
				Vector2(0, 0), Vector2(0, -1), Vector2(1, 0), Vector2(1, -1),
			])
		_move_piece_to_target()
		if old_pos != piece.pos:
			emit_signal("initial_das_moved_left")
	elif initial_das_dir == 0:
		_reset_piece_target()
		_kick_piece([Vector2(0, 0), Vector2(0, -1), Vector2(-1, 0),
				Vector2(-1, -1), Vector2(1, 0), Vector2(1, -1),
			])
		_move_piece_to_target()
	elif initial_das_dir == 1:
		# player is holding right; start piece on the right side
		var old_pos := piece.pos
		_reset_piece_target()
		_kick_piece([Vector2(4, 0), Vector2(4, -1), Vector2(3, 0), Vector2(3, -1),
				Vector2(2, 0), Vector2(2, -1), Vector2(1, 0), Vector2(1, -1),
				Vector2(0, 0), Vector2(0, -1), Vector2(-1, 0), Vector2(-1, -1),
			])
		_move_piece_to_target()
		if old_pos != piece.pos:
			emit_signal("initial_das_moved_right")
	
	# lose?
	var topped_out: bool = false
	if not _can_move_piece_to(piece.pos, piece.orientation):
		emit_signal("topped_out")
		topped_out = true
	
	emit_signal("piece_spawned")
	return not topped_out


"""
Records any inputs to a buffer to be replayed later.
"""
func buffer_inputs() -> void:
	$InputLeft.buffer = true
	$InputRight.buffer = true
	$InputCw.buffer = true
	$InputCcw.buffer = true
	$InputSoftDrop.buffer = true
	$InputHardDrop.buffer = true


"""
Replays any inputs which were pressed while buffering.
"""
func pop_buffered_inputs() -> void:
	$InputLeft.pop_buffered_input()
	$InputRight.pop_buffered_input()
	$InputCw.pop_buffered_input()
	$InputCcw.pop_buffered_input()
	$InputSoftDrop.pop_buffered_input()
	$InputHardDrop.pop_buffered_input()


"""
If any move/rotate keys were pressed, this method will move the block accordingly.

Returns 'true' if the piece was interacted with successfully resulting in a movement change, orientation change, or
	lock reset
"""
func apply_player_input() -> bool:
	if not $InputHardDrop.is_pressed() \
			and not $InputSoftDrop.is_pressed() \
			and not $InputLeft.is_pressed() \
			and not $InputRight.is_pressed() \
			and not $InputCw.is_pressed() \
			and not $InputCcw.is_pressed():
		return false
	
	var did_hard_drop := false
	var old_piece_pos := piece.pos
	var old_piece_orientation := piece.orientation
	var applied_player_input := false

	if $States.get_state() == $States/MovePiece:
		_reset_piece_target()
		_calc_target_orientation()
		if _target_piece_orientation != piece.orientation \
				and not _can_move_piece_to(_target_piece_pos, _target_piece_orientation):
			_kick_piece()
		_move_piece_to_target(true)
		
		_attempt_horizontal_movement()
		
		# automatically trigger DAS if you're pushing a piece towards an obstruction. otherwise, pieces might slip
		# past a nook if you're holding a direction before DAS triggers
		if $InputLeft.is_pressed() \
				and not _can_move_piece_to(Vector2(piece.pos.x - 1, piece.pos.y), piece.orientation):
			$InputLeft.frames = 3600
		if $InputRight.is_pressed() \
				and not _can_move_piece_to(Vector2(piece.pos.x + 1, piece.pos.y), piece.orientation):
			$InputRight.frames = 3600
		
		if $InputHardDrop.is_just_pressed() or $InputHardDrop.is_das_active():
			_reset_piece_target()
			while _move_piece_to_target():
				_target_piece_pos.y += 1
			# lock piece
			piece.lock = PieceSpeeds.current_speed.lock_delay
			emit_signal("hard_dropped")
			did_hard_drop = true

	if $InputSoftDrop.is_just_pressed():
		if not _can_move_piece_to(Vector2(piece.pos.x, piece.pos.y + 1), piece.orientation):
			_reset_piece_target()
			_calc_squish_target()
			if _target_piece_pos != piece.pos:
				_squish_to_target()
			else:
				# Player can tap soft drop to lock cancel, if their timing is good. This lets them hard-drop into a
				# horizontal move or squish move to play faster
				_perform_lock_reset()
				applied_player_input = true
				emit_signal("lock_cancelled")
	elif $InputSoftDrop.is_pressed() and piece.lock >= PieceSpeeds.current_speed.lock_delay:
		if not _can_move_piece_to(Vector2(piece.pos.x, piece.pos.y + 1), piece.orientation):
			_reset_piece_target()
			_calc_squish_target()
			if _target_piece_pos != piece.pos:
				_squish_to_target()
	
	if old_piece_pos != piece.pos or old_piece_orientation != piece.orientation:
		if piece.lock > 0 and not did_hard_drop:
			_perform_lock_reset()
			applied_player_input = true
	return applied_player_input


func _clear_piece() -> void:
	piece = ActivePiece.new(PieceTypes.piece_null)
	tile_map_dirty = true


"""
Returns 'true' if the specified position and location is unobstructed, and the active piece could fit there. Returns
'false' if parts of this piece would be out of the _playfield or obstructed by blocks.
"""
func _can_move_piece_to(pos: Vector2, orientation: int) -> bool:
	return piece.can_move_piece_to(funcref(self, "_is_cell_blocked"), pos, orientation)


"""
Squishes a piece through other blocks towards the target.
"""
func _squish_to_target() -> void:
	# initialize the stretch animation for long stretches
	if _target_piece_pos.y - piece.pos.y >= 3:
		var unblocked_blocks: Array = piece.type.pos_arr[_target_piece_orientation].duplicate()
		$StretchMap.start_stretch(PieceSpeeds.SQUISH_FRAMES, piece.type.color_arr[piece.orientation][0].y)
		for dy in range(_target_piece_pos.y - piece.pos.y):
			var i := 0
			while i < unblocked_blocks.size():
				var target_block_pos: Vector2 = unblocked_blocks[i] + piece.pos + Vector2(0, dy)
				var valid_block_pos := true
				if target_block_pos.x < 0 or target_block_pos.x >= Playfield.COL_COUNT:
					valid_block_pos = false
				elif target_block_pos.y < 0 or target_block_pos.y >= Playfield.ROW_COUNT:
					valid_block_pos = false
				elif not _playfield.is_cell_empty(target_block_pos.x, target_block_pos.y):
					valid_block_pos = false
				if not valid_block_pos:
					unblocked_blocks.remove(i)
				else:
					i += 1
			$StretchMap.stretch_to(unblocked_blocks, piece.pos + Vector2(0, dy))
	
	_move_piece_to_target()
	emit_signal("squish_moved")
	piece.gravity = 0
	_gravity_delay_frames = PieceSpeeds.SQUISH_FRAMES


"""
Resets the piece's 'lock' value, preventing it from locking for a moment.
"""
func _perform_lock_reset() -> void:
	if piece.lock_resets >= PieceSpeeds.MAX_LOCK_RESETS or piece.lock == 0:
		return
	piece.lock = 0
	piece.lock_resets += 1


"""
Tries to 'squish' a piece past the _playfield blocks. This squish will be successful if there's a location below the
piece's current location where the piece can fit, and if at least one of the piece's blocks remains unobstructed
along its path to the target location.

If the 'squish' is successful, the '_target_piece_pos' field will be updated accordingly. If it is unsuccessful, the
'_target_piece_pos' field will retain its original value.
"""
func _calc_squish_target() -> void:
	var unblocked_blocks := []
	for _i in range(piece.type.pos_arr[_target_piece_orientation].size()):
		unblocked_blocks.append(true)
	
	var valid_target_pos := false
	while not valid_target_pos and _target_piece_pos.y < Playfield.ROW_COUNT:
		_target_piece_pos.y += 1
		valid_target_pos = true
		for i in range(piece.type.pos_arr[_target_piece_orientation].size()):
			var target_block_pos := piece.type.get_cell_position(_target_piece_orientation, i) \
					+ _target_piece_pos
			var valid_block_pos := true
			valid_block_pos = valid_block_pos and target_block_pos.x >= 0 and target_block_pos.x < Playfield.COL_COUNT
			valid_block_pos = valid_block_pos and target_block_pos.y >= 0 and target_block_pos.y < Playfield.ROW_COUNT
			if _playfield:
				valid_block_pos = valid_block_pos and _playfield.is_cell_empty(target_block_pos.x, target_block_pos.y)
			valid_target_pos = valid_target_pos and valid_block_pos
			unblocked_blocks[i] = unblocked_blocks[i] and valid_block_pos
			
	# for the slide to succeed, at least one block needs to have been unblocked the entire way down, and the
	# target needs to be valid
	var any_unblocked_blocks := false
	for unblocked_block in unblocked_blocks:
		if unblocked_block:
			any_unblocked_blocks = true
	if not valid_target_pos or not any_unblocked_blocks:
		_reset_piece_target()


"""
Kicks a rotated piece into a nearby empty space.

This does not attempt to preserve the original position/orientation unless explicitly given a kick of (0, 0).
"""
func _kick_piece(kicks: Array = []) -> void:
	var successful_kick := piece.kick_piece(funcref(self, "_is_cell_blocked"), _target_piece_pos,
			_target_piece_orientation, kicks)
	
	if successful_kick:
		_target_piece_pos += successful_kick
		if successful_kick.y < 0:
			piece.floor_kicks += 1


"""
Increments the piece's 'gravity'. A piece will fall once its accumulated 'gravity' exceeds a certain threshold.
"""
func apply_gravity() -> void:
	if _gravity_delay_frames > 0:
		_gravity_delay_frames -= 1
	else:
		if $InputSoftDrop.is_pressed():
			# soft drop
			piece.gravity += int(max(PieceSpeeds.DROP_G, PieceSpeeds.current_speed.gravity))
			emit_signal("soft_dropped")
		else:
			piece.gravity += PieceSpeeds.current_speed.gravity
		
		while piece.gravity >= PieceSpeeds.G:
			piece.gravity -= PieceSpeeds.G
			_reset_piece_target()
			_target_piece_pos.y = piece.pos.y + 1
			if not _move_piece_to_target():
				break
			
			if _horizontal_movement_count == 0:
				# move piece once per frame to allow pieces to slide into nooks during 20G
				_attempt_horizontal_movement()


"""
Increments the piece's 'lock'. A piece will become locked once its accumulated 'lock' exceeds a certain threshold,
usually about half a second.
"""
func apply_lock() -> void:
	if not _can_move_piece_to(Vector2(piece.pos.x, piece.pos.y + 1), piece.orientation):
		piece.lock += 1
		piece.gravity = 0
	else:
		piece.lock = 0


func is_playfield_clearing_lines() -> bool:
	return _playfield.remaining_line_clear_frames > 0


func _is_cell_blocked(pos: Vector2) -> bool:
	var blocked := false
	if pos.x < 0 or pos.x >= Playfield.COL_COUNT: blocked = true
	if pos.y < 0 or pos.y >= Playfield.ROW_COUNT: blocked = true
	if not _playfield.is_cell_empty(pos.x, pos.y): blocked = true
	return blocked


func _move_piece_to_target(play_sfx := false) -> bool:
	var valid_target_pos := _can_move_piece_to(_target_piece_pos, _target_piece_orientation)
	
	if valid_target_pos:
		if play_sfx:
			if piece.orientation != _target_piece_orientation:
				if _target_piece_orientation == piece.get_cw_orientation():
					emit_signal("rotated_right")
				elif _target_piece_orientation == piece.get_ccw_orientation():
					emit_signal("rotated_left")
				elif _target_piece_orientation == piece.get_flip_orientation():
					emit_signal("rotated_twice")
			elif piece.pos != _target_piece_pos:
				if _target_piece_pos.x > piece.pos.x:
					if $InputRight.is_das_active():
						emit_signal("das_moved_right")
					else:
						emit_signal("moved_right")
				elif _target_piece_pos.x < piece.pos.x:
					if $InputLeft.is_das_active():
						emit_signal("das_moved_left")
					else:
						emit_signal("moved_left")
		piece.pos = _target_piece_pos
		piece.orientation = _target_piece_orientation
		tile_map_dirty = true
	
	_reset_piece_target()
	return valid_target_pos

func _reset_piece_target() -> void:
	_target_piece_pos = piece.pos
	_target_piece_orientation = piece.orientation


func _attempt_horizontal_movement() -> void:
	if $InputLeft.is_just_pressed() or $InputLeft.is_das_active():
		_target_piece_pos.x -= 1
	
	if $InputRight.is_just_pressed() or $InputRight.is_das_active():
		_target_piece_pos.x += 1
	
	if _target_piece_pos.x != piece.pos.x and _move_piece_to_target(true):
		_horizontal_movement_count += 1


"""
Calculates the orientation the player is trying to rotate the piece to.
"""
func _calc_target_orientation() -> void:
	if $InputCw.is_just_pressed():
		_target_piece_orientation = piece.get_cw_orientation(_target_piece_orientation)
		
	if $InputCcw.is_just_pressed():
		_target_piece_orientation = piece.get_ccw_orientation(_target_piece_orientation)


"""
Refresh the tilemap which displays the piece, based on the current piece's position and orientation.
"""
func _update_tile_map() -> void:
	$TileMap.clear()
	for i in range(piece.type.pos_arr[piece.orientation].size()):
		var block_pos := piece.type.get_cell_position(piece.orientation, i)
		var block_color := piece.type.get_cell_color(piece.orientation, i)
		$TileMap.set_block(piece.pos + block_pos, 0, block_color)


func _on_States_entered_state(state: State) -> void:
	if state == $States/Prelock:
		emit_signal("lock_started")


func _on_PuzzleScore_game_prepared() -> void:
	_clear_piece()


func _on_PuzzleScore_game_started() -> void:
	$States.set_state($States/Prespawn)
	# Set the state frames so that the piece spawns immediately
	$States/Prespawn.frames = 3600
	tile_map_dirty = true


func _on_PuzzleScore_game_ended() -> void:
	$States.set_state($States/GameEnded)
