# Crosshair.gd
extends Control

func _ready():
	# Set to center of screen
	position = Vector2.ZERO
	
	
func _draw():
	# Draw a simple dot
	draw_circle(Vector2.ZERO, 1, Color.GHOST_WHITE)
	
	# Or draw a traditional crosshair
	var length = 10
	var gap = 8
	var thickness = 1
	
	# Top line
	draw_line(Vector2(0, -gap), Vector2(0, -gap - length), Color.WHITE, thickness)
	# Bottom line
	draw_line(Vector2(0, gap), Vector2(0, gap + length), Color.WHITE, thickness)
	# Left line
	draw_line(Vector2(-gap, 0), Vector2(-gap - length, 0), Color.WHITE, thickness)
	# Right line
	draw_line(Vector2(gap, 0), Vector2(gap + length, 0), Color.WHITE, thickness)
