extends Control
var weapon := -1
var spread := -1.0
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;size=Vector2(96,96)
func configure(index: int, error: float) -> void:
	var quantized=snappedf(error,.05)
	if index==weapon and quantized==spread: return
	weapon=index;spread=quantized;queue_redraw()
func _draw() -> void:
	var centre=size*.5;var radius=(17.0 if weapon>=2 else 10.0)+maxf(0,spread)*5
	for width in [4.0,2.0]:
		var color=Color(0,0,0,.7) if width==4 else Color.WHITE
		if weapon>=2:
			for i in 4:
				var angle=i*PI*.5
				draw_arc(centre,radius,angle+.18,angle+PI*.5-.18,12,color,width,true)
		else:
			for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
				draw_line(centre+direction*(radius*.55),centre+direction*radius,color,width,true)
			if weapon==1: draw_arc(centre,radius+5,0,TAU,32,color,width,true)
	draw_circle(centre,1.2,Color.WHITE)
