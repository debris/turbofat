tool
extends Node
## Autotiles a tilemap for indoor floors.
##
## The carpet tiling logic renders floors with deliberate imperfections.

## autotile coordinates for a carpet cell without imperfections
const CARPET_FLAWLESS_CELL := Vector2(0, 0)

## autotile coordinates for carpet cells with imperfections
const CARPET_FLAWED_CELLS := [
	Vector2(1, 0), Vector2(2, 0),
	Vector2(0, 1), Vector2(1, 1), Vector2(2, 1),
	Vector2(0, 2), Vector2(1, 2), Vector2(2, 2),
	Vector2(0, 3), Vector2(1, 3), Vector2(2, 3),
]

## percent of carpet cells without imperfections, in the range [0.0, 1.0]
const CARPET_QUALITY := 0.76

## The parent tilemap's tile ID for carpet tiles
export (int) var carpet_tile_index: int = -1

## An editor toggle which manually applies autotiling.
##
## Godot has no way of automatically reacting to GridMap/TileMap changes. See Godot #11855
## https://github.com/godotengine/godot/issues/11855
export (bool) var _autotile: bool setget autotile

## tilemap containing floors
onready var _tile_map: TileMap = get_parent()

## Preemptively initializes onready variables to avoid null references.
func _enter_tree() -> void:
	_initialize_onready_variables()


## Autotiles floors, applying imperfections.
##
## The floor autotiling logic applies probabilities and cannot be handled by Godot's built-in autotiling.
func autotile(_value: bool) -> void:
	for cell in _tile_map.get_used_cells_by_id(carpet_tile_index):
		_autotile_carpet(cell)


## Preemptively initializes onready variables to avoid null references.
func _initialize_onready_variables() -> void:
	_tile_map = get_parent()


## Autotiles a tile containing a carpet.
##
## Parameters:
## 	'cell': The TileMap coordinates of the cell to be autotiled.
func _autotile_carpet(cell: Vector2) -> void:
	if randf() < CARPET_QUALITY:
		# replace the cell with a perfect carpet tile
		_set_cell_autotile_coord(cell, CARPET_FLAWLESS_CELL)
	else:
		# replace the cell with a fuzzy carpet tile
		_set_cell_autotile_coord(cell, Utils.rand_value(CARPET_FLAWED_CELLS))


## Updates the autotile coordinate for a TileMap cell.
##
## Parameters:
## 	'cell': The TileMap coordinates of the cell to be updated.
##
## 	'autotile_coord': The autotile coordinates to assign.
func _set_cell_autotile_coord(cell: Vector2, autotile_coord: Vector2) -> void:
	var tile: int = _tile_map.get_cellv(cell)
	var flip_x: bool = _tile_map.is_cell_x_flipped(cell.x, cell.y)
	var flip_y: bool = _tile_map.is_cell_y_flipped(cell.x, cell.y)
	var transpose: bool = _tile_map.is_cell_transposed(cell.x, cell.y)
	_tile_map.set_cellv(cell, tile, flip_x, flip_y, transpose, autotile_coord)