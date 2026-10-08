extends AudioStreamPlayer

func lancer_des() -> void:
	stop()
	$Des.play()
	await $Des.finished
	if not $Combat.playing:
		$Combat.play()

func retour_menu() -> void:
	$Combat.stop()
	$Des.stop()
	if not playing:
		play()
