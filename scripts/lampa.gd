extends OmniLight3D

var tik = 0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var energia = sin(tik)*1.1
	tik += 10*delta * 0.8
	if tik > 360:
		tik = 0
	light_energy = energia
	
