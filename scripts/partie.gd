class_name Partie
extends Node
## Gère une partie complète : les niveaux, les vies, et l'enchaînement des combats.
##
## Déroulement :
##   nouvelle_partie()  -> signal niveau_pret (tirage + dés faits, ennemis visibles)
##   le joueur place ses persos avec combat.placer(...)
##   lancer_combat()    -> le combat se joue
##   -> signal niveau_gagne / vie_perdue / partie_gagnee / partie_perdue
##   continuer()        -> prépare le niveau suivant (ou le même si on a perdu une vie)

signal niveau_pret(niveau: int, unites_joueur: Array[Unite])
signal niveau_gagne(niveau: int)
signal vie_perdue(vies_restantes: int)
signal partie_gagnee
signal partie_perdue

# --- ÉQUILIBRAGE de la partie
const VIES_DEPART := 3
const PERSOS_JOUEUR := 5

## Un élément par niveau. bonus = multiplicateur de Pv et de dégâts des ennemis.
const NIVEAUX := [
	{"ennemis": 3, "bonus": 1.0},
	{"ennemis": 4, "bonus": 1.15},
	{"ennemis": 5, "bonus": 0.9},
	{"ennemis": 5, "bonus": 1.0},
	{"ennemis": 5, "bonus": 1.1},
]

var combat: Combat
var niveau: int = 1  ## commence à 1
var vies: int = VIES_DEPART
var terminee: bool = false
var unites_joueur: Array[Unite] = []


func _init() -> void:
	combat = Combat.new()
	add_child(combat)
	combat.combat_termine.connect(_sur_combat_termine)


func nombre_niveaux() -> int:
	return NIVEAUX.size()


## Démarre (ou redémarre) une partie au niveau 1 avec toutes les vies.
func nouvelle_partie() -> void:
	niveau = 1
	vies = VIES_DEPART
	terminee = false
	_preparer_niveau()


## À appeler quand le joueur a fini de placer ses persos (ou que le timer est fini).
func lancer_combat() -> void:
	if terminee or combat.en_cours:
		return
	combat.demarrer()


## À appeler après un combat pour passer à la suite :
## niveau suivant si on a gagné, même niveau si on a perdu une vie.
func continuer() -> void:
	if terminee or combat.en_cours:
		return
	_preparer_niveau()


func _preparer_niveau() -> void:
	combat.vider()
	unites_joueur.clear()
	for data in PersoData.tirage(PERSOS_JOUEUR):
		unites_joueur.append(combat.creer_unite(data, Unite.Equipe.JOUEUR))
	combat.lancer_tous_les_des(Unite.Equipe.JOUEUR)

	var reglages: Dictionary = NIVEAUX[niveau - 1]
	combat.generer_ennemis(reglages["ennemis"], reglages["bonus"])
	niveau_pret.emit(niveau, unites_joueur)


func _sur_combat_termine(gagnant: int) -> void:
	if gagnant == Unite.Equipe.JOUEUR:
		if niveau >= NIVEAUX.size():
			terminee = true
			partie_gagnee.emit()
		else:
			niveau_gagne.emit(niveau)
			niveau += 1
	else:
		# Défaite ou égalité : on perd une vie et on refera le même niveau.
		vies -= 1
		vie_perdue.emit(vies)
		if vies <= 0:
			terminee = true
			partie_perdue.emit()
