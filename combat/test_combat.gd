extends Node
## Scène de test : lance un combat complet et écrit tout dans la console.
## Attache ce script à un Node tout seul dans une scène, puis F6.

var combat: Combat


func _ready() -> void:
	combat = Combat.new()
	add_child(combat)

	combat.de_lance.connect(_sur_de_lance)
	combat.unite_deplacee.connect(_sur_deplacement)
	combat.attaque_effectuee.connect(_sur_attaque)
	combat.unite_soignee.connect(_sur_soin)
	combat.unite_etourdie.connect(_sur_stun)
	combat.unite_morte.connect(_sur_mort)
	combat.combat_termine.connect(_sur_fin)

	print("=== TIRAGE ET DÉS DU JOUEUR ===")
	var mes_unites: Array[Unite] = []
	for data in PersoData.tirage(5):
		mes_unites.append(combat.creer_unite(data, Unite.Equipe.JOUEUR))
	combat.lancer_tous_les_des(Unite.Equipe.JOUEUR)

	print("=== PLACEMENT ===")
	# Ici c'est la partie B qui appellera combat.placer() quand le joueur pose un perso.
	var cases := [Vector2i(1, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(2, 5), Vector2i(4, 5)]
	for i in mes_unites.size():
		combat.placer(mes_unites[i], cases[i])
		print("%s posé en %s" % [mes_unites[i].nom_complet(), cases[i]])

	print("=== ENNEMIS ===")
	combat.generer_ennemis(5)
	for unite in combat.vivantes(Unite.Equipe.ENNEMI):
		print("%s posé en %s" % [unite.nom_complet(), unite.pos])

	print("=== COMBAT ===")
	combat.demarrer()


func _chrono() -> String:
	return "%5.1fs" % combat.temps


func _sur_de_lance(unite: Unite, face: int, description: String) -> void:
	print("%s -> face %d : %s" % [unite.nom_complet(), face + 1, description])


func _sur_deplacement(unite: Unite, _ancienne: Vector2i, nouvelle: Vector2i, teleportation: bool) -> void:
	var verbe := "se téléporte" if teleportation else "avance"
	print("%s  %s %s en %s" % [_chrono(), unite.nom_complet(), verbe, nouvelle])


func _sur_attaque(attaquant: Unite, cible: Unite, degats: int) -> void:
	print("%s  %s tape %s : -%d (reste %d Pv)" % [_chrono(), attaquant.nom_complet(), cible.nom_complet(), degats, maxi(cible.pv, 0)])


func _sur_soin(soigneur: Unite, cible: Unite, montant: int) -> void:
	print("%s  %s soigne %s : +%d" % [_chrono(), soigneur.nom_complet(), cible.nom_complet(), montant])


func _sur_stun(unite: Unite, duree: float) -> void:
	print("%s  %s est étourdi %.1fs" % [_chrono(), unite.nom_complet(), duree])


func _sur_mort(unite: Unite) -> void:
	print("%s  %s est mort" % [_chrono(), unite.nom_complet()])


func _sur_fin(gagnant: int) -> void:
	match gagnant:
		Unite.Equipe.JOUEUR:
			print("=== VICTOIRE DU JOUEUR ===")
		Unite.Equipe.ENNEMI:
			print("=== VICTOIRE DES ENNEMIS ===")
		_:
			print("=== ÉGALITÉ ===")
