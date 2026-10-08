class_name Plateau
extends Node2D
## Affiche la grille 6x6 et les persos, et anime tout ce qui se passe dans le combat.
##
## Utilisation :
##   plateau.brancher(combat)      une seule fois
##   plateau.afficher_unites()     quand les persos sont placés, AVANT combat.demarrer()

const TAILLE_CASE := 90.0
const HAUTEUR_PERSO := 112.0  ## hauteur à l'écran du perso le plus grand, en pixels
const PROJECTILES := {
	PersoData.Classe.MAGE: preload("res://assets/effets/boule.png"),
	PersoData.Classe.DPS: preload("res://assets/effets/fleche.png"),
	PersoData.Classe.ASSASSIN: preload("res://assets/effets/assasin.png")
}
const IMAGE_BRISURE := preload("res://assets/effets/dalle.png")
const CASES_BRISEES := [
	Vector2i(1, 0), Vector2i(4, 1), Vector2i(2, 2),
	Vector2i(0, 3), Vector2i(3, 4), Vector2i(5, 5),
]
const TEINTE_ENNEMI := Color(1.0, 0.8, 0.8)
const TEINTE_JOUEUR := Color(0.8, 0.88, 1.0)
## Les images doivent s'appeler comme le perso, en minuscules : kayn.png, sonia.png...
const DOSSIER_IMAGES := "res://assets/persos/"
const EXTENSIONS := [".png", ".webp", ".jpg"]

const CASE_ENNEMI_A := Color("5a3d3d")
const CASE_ENNEMI_B := Color("503636")
const CASE_JOUEUR_A := Color("3d4a5e")
const CASE_JOUEUR_B := Color("364254")
const COULEUR_LIGNES := Color(0, 0, 0, 0.35)

var combat: Combat
var visuels: Dictionary = {}  ## Unite -> UniteVisuelle

var _calque_unites: Node2D
var _calque_effets: Node2D
var _images: Dictionary = {}  ## nom du perso -> {"texture": Texture2D, "region": Rect2}
var _echelle: float = 1.0
var _images_pretes: bool = false


func _init() -> void:
	_calque_unites = Node2D.new()
	_calque_unites.y_sort_enabled = true  # les persos du bas passent devant ceux du haut
	add_child(_calque_unites)
	_calque_effets = Node2D.new()
	add_child(_calque_effets)


func brancher(p_combat: Combat) -> void:
	combat = p_combat
	combat.unite_deplacee.connect(_sur_deplacement)
	combat.attaque_effectuee.connect(_sur_attaque)
	combat.unite_soignee.connect(_sur_soin)
	combat.unite_etourdie.connect(_sur_stun)
	combat.unite_morte.connect(_sur_mort)


## Taille totale du plateau en pixels.
func taille() -> Vector2:
	return Vector2(Combat.COLONNES, Combat.LIGNES) * TAILLE_CASE


## Point où poser les pieds d'un perso pour une case donnée.
## Point où poser les pieds d'un perso pour une case donnée.
func position_case(case: Vector2i) -> Vector2:
	var ecran := _case_ecran(case)
	return Vector2((ecran.x + 0.5) * TAILLE_CASE, (ecran.y + 1.0) * TAILLE_CASE - 12.0)


## Coin en haut à gauche d'une case, en pixels (pour la surbrillance).
func coin_case(case: Vector2i) -> Vector2:
	return Vector2(_case_ecran(case)) * TAILLE_CASE


## La case sous un point (en coordonnées du plateau).
func case_sous(point: Vector2) -> Vector2i:
	var ecran := Vector2i(floori(point.x / TAILLE_CASE), floori(point.y / TAILLE_CASE))
	return _case_du_combat(ecran)


## Le combat range les camps en lignes. À l'écran on tourne le plateau d'un quart
## de tour : joueur à gauche, ennemis à droite. Ces deux fonctions font la conversion.
func _case_ecran(case: Vector2i) -> Vector2i:
	return Vector2i(Combat.LIGNES - 1 - case.y, case.x)


func _case_du_combat(ecran: Vector2i) -> Vector2i:
	return Vector2i(ecran.y, Combat.LIGNES - 1 - ecran.x)

## Crée l'affichage de toutes les unités déjà placées sur la grille.
func afficher_unites() -> void:
	_preparer_images()
	for unite in combat.unites:
		if unite.est_placee() and not visuels.has(unite):
			_creer_visuel(unite)


## Enlève tous les persos de l'écran (entre deux combats).
func vider() -> void:
	for visuel in visuels.values():
		if is_instance_valid(visuel):
			visuel.queue_free()
	visuels.clear()
	for effet in _calque_effets.get_children():
		effet.queue_free()


func _draw() -> void:
	for y in Combat.LIGNES:
		for x in Combat.COLONNES:
			var clair := (x + y) % 2 == 0
			var couleur: Color
			if x >= Combat.LIGNES - Combat.LIGNES_PAR_EQUIPE:
				couleur = CASE_ENNEMI_A if clair else CASE_ENNEMI_B
			else:
				couleur = CASE_JOUEUR_A if clair else CASE_JOUEUR_B
			var rect := Rect2(Vector2(x, y) * TAILLE_CASE, Vector2(TAILLE_CASE, TAILLE_CASE))
			draw_rect(rect, couleur)
			if Vector2i(x, y) in CASES_BRISEES:
				draw_texture_rect(IMAGE_BRISURE, rect, false)
			draw_rect(rect, COULEUR_LIGNES, false, 1.0)
	# Ligne de séparation entre les deux camps
	var milieu := Combat.LIGNES_PAR_EQUIPE * TAILLE_CASE
	draw_line(Vector2(milieu, 0), Vector2(milieu, taille().y), Color(1, 1, 1, 0.5), 3.0)


# =====================================================================
#  IMAGES DES PERSOS
# =====================================================================

## Charge les images de tous les persos et calcule une échelle commune,
## pour que tout le monde garde les proportions du dessin d'origine.
func _preparer_images() -> void:
	if _images_pretes:
		return
	_images_pretes = true
	var hauteur_max := 0.0
	for data in PersoData.tous():
		var info := _charger_image(data.nom)
		if not info.is_empty():
			_images[data.nom] = info
			hauteur_max = maxf(hauteur_max, info["region"].size.y)
	if hauteur_max > 0.0:
		_echelle = HAUTEUR_PERSO / hauteur_max


func _charger_image(nom: String) -> Dictionary:
	for base in [nom.to_lower(), nom]:
		for extension in EXTENSIONS:
			var chemin: String = DOSSIER_IMAGES + base + extension
			if ResourceLoader.exists(chemin):
				var texture: Texture2D = load(chemin)
				return {"texture": texture, "region": _zone_dessinee(texture)}
	push_warning("Image introuvable pour %s (attendue : %s%s.png)" % [nom, DOSSIER_IMAGES, nom.to_lower()])
	return {}


## Le rectangle qui contient vraiment le dessin, sans les marges transparentes.
func _zone_dessinee(texture: Texture2D) -> Rect2:
	var entiere := Rect2(Vector2.ZERO, texture.get_size())
	var image := texture.get_image()
	if image == null or image.is_compressed():
		return entiere
	var zone := image.get_used_rect()
	if zone.size.x <= 0 or zone.size.y <= 0:
		return entiere
	return Rect2(zone)


func _creer_visuel(unite: Unite) -> void:
	var visuel := UniteVisuelle.new()
	var info: Dictionary = _images.get(unite.data.nom, {})
	if unite.equipe == Unite.Equipe.ENNEMI:
		var mechant := _image_mechant(unite.data.nom)
		if not mechant.is_empty():
			info = mechant
	if info.is_empty():
		visuel.initialiser(unite, null, Rect2(), 1.0, HAUTEUR_PERSO)
	else:
		var hauteur: float = info["region"].size.y * _echelle
		visuel.initialiser(unite, info["texture"], info["region"], _echelle, hauteur)
	visuel.position = position_case(unite.pos)
	_calque_unites.add_child(visuel)
	visuels[unite] = visuel


# =====================================================================
#  RÉACTIONS AUX ÉVÉNEMENTS DU COMBAT
# =====================================================================

func _visuel(unite: Unite) -> UniteVisuelle:
	var visuel: UniteVisuelle = visuels.get(unite)
	if visuel != null and is_instance_valid(visuel):
		return visuel
	return null


func _sur_deplacement(unite: Unite, _ancienne: Vector2i, nouvelle: Vector2i, teleportation: bool) -> void:
	var visuel := _visuel(unite)
	if visuel != null:
		visuel.aller_a(position_case(nouvelle), teleportation)


func _sur_attaque(attaquant: Unite, cible: Unite, degats: int) -> void:
	var v_attaquant := _visuel(attaquant)
	var v_cible := _visuel(cible)
	if v_attaquant != null and v_cible != null:
		v_attaquant.frapper_vers(v_cible.position)
		if combat.distance(attaquant.pos, cible.pos) > 1 or PROJECTILES.has(attaquant.data.classe):
			_lancer_projectile(v_attaquant, v_cible, attaquant.data.classe)
	if v_cible != null:
		v_cible.prendre_coup()
		v_cible.maj_vie()
		_afficher_nombre(v_cible, "-%d" % degats, Color("ffd9d9"))


func _sur_soin(_soigneur: Unite, cible: Unite, montant: int) -> void:
	var visuel := _visuel(cible)
	if visuel != null:
		visuel.soigner()
		visuel.maj_vie()
		_afficher_nombre(visuel, "+%d" % montant, Color("8dff8d"))


func _sur_stun(unite: Unite, duree: float) -> void:
	var visuel := _visuel(unite)
	if visuel != null:
		visuel.etourdir(duree)


func _sur_mort(unite: Unite) -> void:
	var visuel := _visuel(unite)
	if visuel != null:
		visuel.mourir()
	visuels.erase(unite)


## Chiffre qui monte et disparaît au-dessus d'un perso.
func _afficher_nombre(visuel: UniteVisuelle, texte: String, couleur: Color) -> void:
	var label := Label.new()
	label.text = texte
	label.size = Vector2(80, 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", couleur)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.position = visuel.position + Vector2(-40 + randf_range(-12, 12), -visuel.hauteur * 0.75)
	_calque_effets.add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 34.0, 0.6)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.25)
	tween.tween_callback(label.queue_free)


## Petit losange qui vole de l'attaquant à la cible (attaques à distance).
func _lancer_projectile(depart: UniteVisuelle, arrivee: UniteVisuelle, classe: PersoData.Classe) -> void:
	var debut := depart.position + Vector2(0, -depart.hauteur * 0.5)
	var fin := arrivee.position + Vector2(0, -arrivee.hauteur * 0.5)
	var projectile: Node2D
	if PROJECTILES.has(classe):
		var sprite := Sprite2D.new()
		sprite.texture = PROJECTILES[classe]
		sprite.rotation = (fin - debut).angle()
		sprite.scale = Vector2(0.03, 0.03)
		projectile = sprite
	else:
		var losange := Polygon2D.new()
		losange.polygon = PackedVector2Array([Vector2(0, -7), Vector2(7, 0), Vector2(0, 7), Vector2(-7, 0)])
		losange.color = Color("c77dff")
		projectile = losange
	projectile.position = debut
	_calque_effets.add_child(projectile)
	var tween := projectile.create_tween()
	tween.tween_property(projectile, "position", fin, 0.15)
	tween.tween_callback(projectile.queue_free)
const SUFFIXE_MECHANT := "_mechant"
var _images_mechants: Dictionary = {}


## L'image "version méchante" d'un perso : même nom de fichier + "_mechant".
## Renvoie un dictionnaire vide si elle n'existe pas : l'ennemi garde alors le dessin normal.
func _image_mechant(nom: String) -> Dictionary:
	if _images_mechants.has(nom):
		return _images_mechants[nom]
	var info := {}
	for extension in EXTENSIONS:
		var chemin: String = DOSSIER_IMAGES + nom.to_lower() + SUFFIXE_MECHANT + extension
		if ResourceLoader.exists(chemin):
			var texture: Texture2D = load(chemin)
			info = {"texture": texture, "region": _zone_dessinee(texture)}
			break
	_images_mechants[nom] = info
	return info
