extends Node
## Scène de test : joue une partie complète toute seule (placement au hasard)
## et écrit les grandes étapes dans la console.
## Attache ce script à un Node tout seul dans une scène, puis F6.

var partie: Partie


func _ready() -> void:
	Engine.time_scale = 8.0  # accélère le jeu pour le test, à enlever dans le vrai jeu

	partie = Partie.new()
	add_child(partie)

	partie.niveau_pret.connect(_sur_niveau_pret)
	partie.niveau_gagne.connect(_sur_niveau_gagne)
	partie.vie_perdue.connect(_sur_vie_perdue)
	partie.partie_gagnee.connect(_sur_partie_gagnee)
	partie.partie_perdue.connect(_sur_partie_perdue)
	partie.combat.unite_morte.connect(_sur_mort)

	partie.nouvelle_partie()


func _sur_niveau_pret(niveau: int, unites_joueur: Array[Unite]) -> void:
	print("")
	print("=== NIVEAU %d / %d  (vies : %d) ===" % [niveau, partie.nombre_niveaux(), partie.vies])
	for unite in partie.combat.vivantes(Unite.Equipe.ENNEMI):
		print("%s en %s : %s" % [unite.nom_complet(), unite.pos, partie.combat.description_de(unite)])

	# Ici, dans le vrai jeu, c'est le joueur qui place ses persos pendant le timer.
	var cases: Array[Vector2i] = []
	for y in range(3, 6):
		for x in Combat.COLONNES:
			cases.append(Vector2i(x, y))
	cases.shuffle()
	for unite in unites_joueur:
		partie.combat.placer(unite, cases.pop_back())
		print("%s en %s : %s" % [unite.nom_complet(), unite.pos, partie.combat.description_de(unite)])

	partie.lancer_combat()


func _sur_mort(unite: Unite) -> void:
	print("%5.1fs  %s est K.O." % [partie.combat.temps, unite.nom_complet()])


func _sur_niveau_gagne(niveau: int) -> void:
	print(">>> Niveau %d gagné !" % niveau)
	# Dans le vrai jeu : afficher un écran "Niveau gagné" avec un bouton qui appelle continuer().
	partie.continuer.call_deferred()


func _sur_vie_perdue(vies_restantes: int) -> void:
	print(">>> Combat perdu, il reste %d vie(s)" % vies_restantes)
	if vies_restantes > 0:
		partie.continuer.call_deferred()


func _sur_partie_gagnee() -> void:
	print("")
	print("######## PARTIE GAGNÉE ########")


func _sur_partie_perdue() -> void:
	print("")
	print("######## GAME OVER ########")
