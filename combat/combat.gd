class_name Combat
extends Node
## Toute la logique du combat : grille, dés, déplacements, attaques, fin.
## Aucun affichage ici : l'interface écoute les signaux ci-dessous.

signal de_lance(unite: Unite, face: int, description: String)
signal unite_deplacee(unite: Unite, ancienne_pos: Vector2i, nouvelle_pos: Vector2i, teleportation: bool)
signal attaque_effectuee(attaquant: Unite, cible: Unite, degats: int)
signal unite_soignee(soigneur: Unite, cible: Unite, montant: int)
signal unite_etourdie(unite: Unite, duree: float)
signal unite_morte(unite: Unite)
signal combat_termine(gagnant: int)  ## Unite.Equipe.JOUEUR, Unite.Equipe.ENNEMI ou EGALITE

const EGALITE := -1

# --- Grille : 6 x 6, lignes 0-2 = ennemis (en haut), lignes 3-5 = joueur (en bas)
const COLONNES := 6
const LIGNES := 6
const LIGNES_PAR_EQUIPE := 3

# --- ÉQUILIBRAGE du combat
const DUREE_MAX := 60.0  ## secondes, après ça = égalité
const DELAI_DEPLACEMENT := 0.4  ## secondes pour avancer d'une case

# --- ÉQUILIBRAGE des dés
const MULT_DEGATS_ASSASSIN := 1.5
const MULT_AP_MAGE := 1.5
const DUREE_STUN := 1.5
const BONUS_RESISTANCES_TANK := 30.0  ## ajouté à l'Armure ET à la Rm
const SOIN_HEALER := 60
const INTERVALLE_SOIN := 3.0  ## le Healer soigne toutes les X secondes
const MULT_DEGATS_EQUIPE_HEALER := 1.25
const BONUS_PORTEE_DPS := 2
const MULT_VITESSE_DPS := 1.5

const DESCRIPTIONS_DE := {
	PersoData.Classe.ASSASSIN: [
		"Augmente ses dégâts",
		"Se téléporte près d'un ennemi de la ligne arrière",
		"Se téléporte et augmente ses dégâts",
	],
	PersoData.Classe.MAGE: [
		"Augmente ses dégâts magiques",
		"Étourdit un ennemi de la ligne arrière",
		"Étourdit toute l'équipe ennemie",
	],
	PersoData.Classe.TANK: [
		"Augmente son Armure et sa Rm",
		"Augmente l'Armure et la Rm des alliés adjacents (et de lui-même)",
		"Augmente l'Armure et la Rm de toute son équipe",
	],
	PersoData.Classe.HEALER: [
		"Soigne régulièrement les alliés adjacents (et lui-même)",
		"Soigne régulièrement toute son équipe",
		"Augmente les dégâts de toute son équipe",
	],
	PersoData.Classe.DPS: [
		"Inflige des dégâts bruts (ignore l'Armure)",
		"Augmente sa portée",
		"Augmente sa vitesse d'attaque",
	],
}

var unites: Array[Unite] = []
var grille: Dictionary = {}  ## Vector2i -> Unite
var en_cours: bool = false
var temps: float = 0.0


# =====================================================================
#  PRÉPARATION (avant le combat)
# =====================================================================

## Crée une unité à partir d'une carte. Elle n'est pas encore sur la grille.
func creer_unite(data: PersoData, equipe: Unite.Equipe) -> Unite:
	var unite := Unite.new(data, equipe)
	unites.append(unite)
	return unite


## Lance le dé d'une unité. Renvoie la face (0, 1 ou 2).
## L'effet est seulement mémorisé : il s'applique au début du combat.
func lancer_de(unite: Unite) -> int:
	unite.face_de = randi_range(0, 2)
	de_lance.emit(unite, unite.face_de, description_de(unite))
	return unite.face_de


func lancer_tous_les_des(equipe: Unite.Equipe) -> void:
	for unite in unites:
		if unite.equipe == equipe:
			lancer_de(unite)


func description_de(unite: Unite) -> String:
	if unite.face_de < 0:
		return ""
	return DESCRIPTIONS_DE[unite.data.classe][unite.face_de]


## Vrai si la case est dans la moitié de terrain de cette équipe.
func dans_zone(pos: Vector2i, equipe: Unite.Equipe) -> bool:
	if pos.x < 0 or pos.x >= COLONNES:
		return false
	if equipe == Unite.Equipe.ENNEMI:
		return pos.y >= 0 and pos.y < LIGNES_PAR_EQUIPE
	return pos.y >= LIGNES - LIGNES_PAR_EQUIPE and pos.y < LIGNES


func dans_grille(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < COLONNES and pos.y >= 0 and pos.y < LIGNES


func case_libre(pos: Vector2i) -> bool:
	return dans_grille(pos) and not grille.has(pos)


## Pose (ou déplace) une unité sur une case de SA moitié de terrain.
## Renvoie false si c'est impossible (case occupée, hors zone, combat lancé).
func placer(unite: Unite, pos: Vector2i) -> bool:
	if en_cours or not dans_zone(pos, unite.equipe):
		return false
	if grille.has(pos) and grille[pos] != unite:
		return false
	if unite.est_placee():
		grille.erase(unite.pos)
	unite.pos = pos
	grille[pos] = unite
	return true


## Enlève une unité de la grille (elle retourne "dans la main").
func retirer(unite: Unite) -> void:
	if en_cours or not unite.est_placee():
		return
	grille.erase(unite.pos)
	unite.pos = Unite.NON_PLACEE


## Crée l'équipe ennemie : persos au hasard, dés lancés, placement au hasard.
## bonus = multiplicateur de Pv et de dégâts (1.2 = +20 %).
## Crée l'équipe ennemie : persos au hasard, dés lancés.
## Placement : corps à corps (portée 1) sur la ligne de devant, les autres tout au fond.
## bonus = multiplicateur de Pv et de dégâts (1.2 = +20 %).
func generer_ennemis(nombre: int = 5, bonus: float = 1.0) -> void:
	var colonnes_devant: Array = range(COLONNES)
	var colonnes_fond: Array = range(COLONNES)
	colonnes_devant.shuffle()
	colonnes_fond.shuffle()
	var ligne_devant := LIGNES_PAR_EQUIPE - 1  # la ligne ennemie la plus proche du joueur
	var ligne_fond := 0
	for data in PersoData.tirage(nombre):
		var unite := creer_unite(data, Unite.Equipe.ENNEMI)
		unite.appliquer_bonus(bonus)
		lancer_de(unite)
		if data.portee <= 1:
			placer(unite, Vector2i(colonnes_devant.pop_back(), ligne_devant))
		else:
			placer(unite, Vector2i(colonnes_fond.pop_back(), ligne_fond))


## Lance le combat. Les unités pas placées sont retirées du combat.
func demarrer() -> void:
	if en_cours:
		return
	var placees: Array[Unite] = []
	for unite in unites:
		if unite.est_placee():
			placees.append(unite)
	unites = placees
	temps = 0.0
	en_cours = true
	for unite in unites:
		_appliquer_de(unite)
	_verifier_fin()


## Remet tout à zéro pour le round suivant.
func vider() -> void:
	en_cours = false
	temps = 0.0
	unites.clear()
	grille.clear()


# =====================================================================
#  DÉROULEMENT DU COMBAT
# =====================================================================

func _process(delta: float) -> void:
	if en_cours:
		avancer(delta)


## Fait avancer le combat de `delta` secondes.
func avancer(delta: float) -> void:
	temps += delta
	var actives := vivantes()
	# Tout le monde joue, PUIS on retire les morts : deux persos peuvent
	# donc s'entretuer au même instant.
	for unite in actives:
		_jouer(unite, delta)
	for unite in actives:
		if unite.pv <= 0:
			unite.vivante = false
			grille.erase(unite.pos)
			unite_morte.emit(unite)
	_verifier_fin()


func _jouer(unite: Unite, delta: float) -> void:
	if unite.temps_stun > 0.0:
		unite.temps_stun -= delta
		return
	unite.recharge_attaque = maxf(0.0, unite.recharge_attaque - delta)
	unite.recharge_deplacement = maxf(0.0, unite.recharge_deplacement - delta)

	if unite.zone_soin != Unite.ZoneSoin.AUCUNE:
		unite.recharge_soin -= delta
		if unite.recharge_soin <= 0.0:
			_soigner(unite)
			unite.recharge_soin = INTERVALLE_SOIN

	var cible := _trouver_cible(unite)
	if cible == null:
		return
	if distance(unite.pos, cible.pos) <= unite.portee:
		if unite.recharge_attaque <= 0.0:
			_attaquer(unite, cible)
			unite.recharge_attaque = 1.0 / unite.vitesse_attaque
	elif unite.recharge_deplacement <= 0.0:
		_avancer_vers(unite, cible.pos)
		unite.recharge_deplacement = DELAI_DEPLACEMENT


## Cible = l'ennemi vivant le plus proche.
func _trouver_cible(unite: Unite) -> Unite:
	var meilleure: Unite = null
	var meilleur_score := INF
	for autre in unites:
		if autre.equipe == unite.equipe or not autre.vivante or autre.pv <= 0:
			continue
		var score := _score_distance(unite.pos, autre.pos)
		if score < meilleur_score:
			meilleur_score = score
			meilleure = autre
	return meilleure


func _attaquer(attaquant: Unite, cible: Unite) -> void:
	var degats := calculer_degats(attaquant, cible)
	cible.pv -= degats
	attaque_effectuee.emit(attaquant, cible, degats)


## Dégâts = Ad (ou Ap) réduits par l'Armure (ou la Rm) de la cible.
## Avec 100 d'armure on prend 2 fois moins de dégâts.
func calculer_degats(attaquant: Unite, cible: Unite) -> int:
	var puissance := attaquant.ap if attaquant.data.degats_magiques else attaquant.ad
	if attaquant.degats_bruts:
		return maxi(1, roundi(puissance))
	var resistance := cible.rm if attaquant.data.degats_magiques else cible.armure
	return maxi(1, roundi(puissance * 100.0 / (100.0 + resistance)))


## Avance d'une case (diagonales autorisées) vers la destination.
func _avancer_vers(unite: Unite, destination: Vector2i) -> void:
	var meilleure_case := unite.pos
	var meilleur_score := _score_distance(unite.pos, destination)
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var case := unite.pos + Vector2i(dx, dy)
			if not case_libre(case):
				continue
			var score := _score_distance(case, destination)
			if score < meilleur_score:
				meilleur_score = score
				meilleure_case = case
	if meilleure_case != unite.pos:
		_deplacer(unite, meilleure_case, false)


func _deplacer(unite: Unite, nouvelle_pos: Vector2i, teleportation: bool) -> void:
	var ancienne := unite.pos
	grille.erase(ancienne)
	unite.pos = nouvelle_pos
	grille[nouvelle_pos] = unite
	unite_deplacee.emit(unite, ancienne, nouvelle_pos, teleportation)


func _soigner(soigneur: Unite) -> void:
	var cibles: Array[Unite]
	if soigneur.zone_soin == Unite.ZoneSoin.EQUIPE:
		cibles = vivantes(soigneur.equipe)
	else:
		cibles = adjacents(soigneur)
	for cible in cibles:
		if cible.pv <= 0:
			continue
		var montant := mini(SOIN_HEALER, cible.pv_max - cible.pv)
		if montant > 0:
			cible.pv += montant
			unite_soignee.emit(soigneur, cible, montant)


func _etourdir(unite: Unite, duree: float) -> void:
	unite.temps_stun = maxf(unite.temps_stun, duree)
	unite_etourdie.emit(unite, duree)


func _verifier_fin() -> void:
	if not en_cours:
		return
	var joueur := vivantes(Unite.Equipe.JOUEUR).size()
	var ennemi := vivantes(Unite.Equipe.ENNEMI).size()
	if joueur > 0 and ennemi > 0 and temps < DUREE_MAX:
		return
	en_cours = false
	if joueur > 0 and ennemi == 0:
		combat_termine.emit(Unite.Equipe.JOUEUR)
	elif ennemi > 0 and joueur == 0:
		combat_termine.emit(Unite.Equipe.ENNEMI)
	else:
		combat_termine.emit(EGALITE)


# =====================================================================
#  EFFETS DES DÉS (appliqués au début du combat)
# =====================================================================

func _appliquer_de(unite: Unite) -> void:
	if unite.face_de < 0:
		return
	match unite.data.classe:
		PersoData.Classe.ASSASSIN:
			_de_assassin(unite)
		PersoData.Classe.MAGE:
			_de_mage(unite)
		PersoData.Classe.TANK:
			_de_tank(unite)
		PersoData.Classe.HEALER:
			_de_healer(unite)
		PersoData.Classe.DPS:
			_de_dps(unite)


func _de_assassin(unite: Unite) -> void:
	if unite.face_de == 0 or unite.face_de == 2:
		unite.ad *= MULT_DEGATS_ASSASSIN
	if unite.face_de == 1 or unite.face_de == 2:
		_teleporter_ligne_arriere(unite)


func _de_mage(unite: Unite) -> void:
	var adversaires := _equipe_adverse(unite.equipe)
	match unite.face_de:
		0:
			unite.ap *= MULT_AP_MAGE
		1:
			var arriere := ligne_arriere(adversaires)
			if not arriere.is_empty():
				_etourdir(arriere.pick_random(), DUREE_STUN)
		2:
			for cible in vivantes(adversaires):
				_etourdir(cible, DUREE_STUN)


func _de_tank(unite: Unite) -> void:
	var cibles: Array[Unite]
	match unite.face_de:
		0:
			cibles = [unite]
		1:
			cibles = adjacents(unite)
		2:
			cibles = vivantes(unite.equipe)
	for cible in cibles:
		cible.armure += BONUS_RESISTANCES_TANK
		cible.rm += BONUS_RESISTANCES_TANK


func _de_healer(unite: Unite) -> void:
	match unite.face_de:
		0:
			unite.zone_soin = Unite.ZoneSoin.ADJACENTS
			unite.recharge_soin = INTERVALLE_SOIN
		1:
			unite.zone_soin = Unite.ZoneSoin.EQUIPE
			unite.recharge_soin = INTERVALLE_SOIN
		2:
			for allie in vivantes(unite.equipe):
				allie.ad *= MULT_DEGATS_EQUIPE_HEALER
				allie.ap *= MULT_DEGATS_EQUIPE_HEALER


func _de_dps(unite: Unite) -> void:
	match unite.face_de:
		0:
			unite.degats_bruts = true
		1:
			unite.portee += BONUS_PORTEE_DPS
		2:
			unite.vitesse_attaque *= MULT_VITESSE_DPS


func _teleporter_ligne_arriere(unite: Unite) -> void:
	var arriere := ligne_arriere(_equipe_adverse(unite.equipe))
	if arriere.is_empty():
		return
	var cible: Unite = arriere.pick_random()
	var cases: Array[Vector2i] = []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var case := cible.pos + Vector2i(dx, dy)
			if case_libre(case):
				cases.append(case)
	if not cases.is_empty():
		_deplacer(unite, cases.pick_random(), true)


# =====================================================================
#  OUTILS
# =====================================================================

## Distance en cases (une diagonale compte pour 1).
func distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## Distance en cases + un petit départage pour préférer la ligne droite.
func _score_distance(a: Vector2i, b: Vector2i) -> float:
	return distance(a, b) + Vector2(a).distance_to(Vector2(b)) * 0.01


## Unités vivantes. Sans argument : les deux équipes.
func vivantes(equipe: int = -1) -> Array[Unite]:
	var resultat: Array[Unite] = []
	for unite in unites:
		if unite.vivante and (equipe == -1 or unite.equipe == equipe):
			resultat.append(unite)
	return resultat


## Alliés vivants à 1 case ou moins (l'unité elle-même comprise).
func adjacents(unite: Unite) -> Array[Unite]:
	var resultat: Array[Unite] = []
	for autre in vivantes(unite.equipe):
		if distance(unite.pos, autre.pos) <= 1:
			resultat.append(autre)
	return resultat


## Ligne arrière d'une équipe = ses unités sur la ligne la plus loin du milieu.
func ligne_arriere(equipe: Unite.Equipe) -> Array[Unite]:
	var membres := vivantes(equipe)
	var resultat: Array[Unite] = []
	if membres.is_empty():
		return resultat
	var ligne := membres[0].pos.y
	for unite in membres:
		if equipe == Unite.Equipe.JOUEUR:
			ligne = maxi(ligne, unite.pos.y)
		else:
			ligne = mini(ligne, unite.pos.y)
	for unite in membres:
		if unite.pos.y == ligne:
			resultat.append(unite)
	return resultat


func _equipe_adverse(equipe: Unite.Equipe) -> Unite.Equipe:
	if equipe == Unite.Equipe.JOUEUR:
		return Unite.Equipe.ENNEMI
	return Unite.Equipe.JOUEUR
