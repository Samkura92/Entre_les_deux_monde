extends Node2D
## Le jeu complet : niveaux, 3 vies, lancer de dés, placement à la souris, combat.
## Ouvre jeu.tscn puis F6.
##
## Déroulement d'un niveau :
##   1. les persos apparaissent, dés cachés ("?")      -> bouton "Lancer les dés"
##   2. les dés roulent, les effets s'affichent sur les côtés
##   3. le joueur fait glisser ses persos pour les placer -> bouton "Lancer le combat"
##   4. combat, puis panneau "Niveau suivant" / "Réessayer" / fin de partie
##
## Toute la logique (niveaux, vies, combat) est dans partie.gd et combat.gd.
## Ce script ne fait que l'affichage et les clics.

enum Phase { DES, ANIMATION_DES, PLACEMENT, COMBAT }


## Une face de dé dessinée avec des points (1, 2 ou 3). valeur 0 = "?" (pas encore lancé).
## Sert pour le gros dé du milieu et pour les petits dés à côté des persos.
class FaceDe extends Control:
	var valeur: int = 0:
		set(nouvelle):
			valeur = nouvelle
			queue_redraw()

	func _init(cote: float) -> void:
		size = Vector2(cote, cote)
		pivot_offset = size / 2.0  # pour tourner autour de son centre
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var cote := size.x
		var style := StyleBoxFlat.new()
		style.bg_color = Color.WHITE
		style.border_color = Color.BLACK
		style.set_border_width_all(maxi(2, roundi(cote * 0.045)))
		style.set_corner_radius_all(roundi(cote * 0.17))
		draw_style_box(style, Rect2(Vector2.ZERO, size))

		if valeur <= 0:
			var taille_police := roundi(cote * 0.62)
			draw_string(get_theme_default_font(), Vector2(0, cote * 0.5 + taille_police * 0.36), "?",
				HORIZONTAL_ALIGNMENT_CENTER, cote, taille_police, Color.BLACK)
			return

		# Positions des points, en proportion du côté (0 = bord gauche/haut, 1 = bord droit/bas)
		var points: Array[Vector2] = []
		match valeur:
			1:
				points = [Vector2(0.5, 0.5)]
			2:
				points = [Vector2(0.3, 0.3), Vector2(0.7, 0.7)]
			_:
				points = [Vector2(0.27, 0.27), Vector2(0.5, 0.5), Vector2(0.73, 0.73)]
		for point in points:
			draw_circle(point * cote, cote * 0.1, Color.BLACK)

const SCENE_MENU := "res://combat/menu.tscn"
const SCRIPT_MENU := "res://combat/menu.gd"  ## on y reprend le texte des règles
const FOND := Color("23252f")
const IMAGE_FOND := "res://assets/effets/menu.png"
const ASSOMBRIR_FOND := 0.5  ## 0 = image telle quelle, 1 = noir complet
const COULEUR_COEUR := Color("e2504a")
const COULEUR_COEUR_VIDE := Color("4a4d5c")
const DELAI_ECRAN := 0.9  ## secondes entre la fin du combat et l'apparition du panneau
const LARGEUR_LISTE := 262.0
const NOMBRE_DE_TIRAGES := 16  ## combien de fois les chiffres changent pendant le lancer
const DUREE_TIRAGE := 0.07  ## secondes entre deux changements
const TAILLE_GROS_DE := 110.0
const TAILLE_PETIT_DE := 26.0

var partie: Partie
var plateau: Plateau
var phase: Phase = Phase.DES

# Interface
var texte_niveau: Label
var texte_ennemis: Label
var texte_aide: Label
var bouton_des: Button
var bouton_combat: Button
var liste_joueur: VBoxContainer
var liste_ennemis: VBoxContainer
var fiche: PanelContainer  ## infos du perso sur lequel on a cliqué
var fiche_nom: Label
var fiche_classe: Label
var fiche_portee: Label
var ecran: Control  ## voile sombre + panneau central
var titre_panneau: Label
var texte_panneau: Label
var bouton_panneau: Button
var _action_panneau: Callable
var popup_regles: Control  ## fenêtre des règles, par-dessus le combat
var bouton_son: Button

# Dés affichés sur les persos
var _badges: Dictionary = {}  ## Unite -> FaceDe

# Glisser-déposer
var _unite_glissee: Unite = null
var _decalage_glisser: Vector2 = Vector2.ZERO
var _surbrillance: ColorRect


func _ready() -> void:
	RenderingServer.set_default_clear_color(FOND)
	var fenetre := get_viewport_rect().size
	# Image de fond (la même que celle du menu), affichée derrière tout le reste
	if ResourceLoader.exists(IMAGE_FOND):
		var calque_fond := CanvasLayer.new()
		calque_fond.layer = -1
		add_child(calque_fond)
		var image_fond := TextureRect.new()
		image_fond.texture = load(IMAGE_FOND)
		image_fond.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image_fond.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image_fond.set_anchors_preset(Control.PRESET_FULL_RECT)
		image_fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
		calque_fond.add_child(image_fond)
		var voile_fond := ColorRect.new()
		voile_fond.color = Color(0, 0, 0, ASSOMBRIR_FOND)
		voile_fond.set_anchors_preset(Control.PRESET_FULL_RECT)
		voile_fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
		calque_fond.add_child(voile_fond)
	partie = Partie.new()
	add_child(partie)
	partie.niveau_pret.connect(_sur_niveau_pret)
	partie.niveau_gagne.connect(_sur_niveau_gagne)
	partie.vie_perdue.connect(_sur_vie_perdue)
	partie.partie_gagnee.connect(_sur_partie_gagnee)
	partie.partie_perdue.connect(_sur_partie_perdue)

	plateau = Plateau.new()
	add_child(plateau)
	plateau.brancher(partie.combat)
	var taille := plateau.taille()
	plateau.position = Vector2((fenetre.x - taille.x) / 2.0, fenetre.y - taille.y - 20.0).round()

	# Case en surbrillance pendant qu'on déplace un perso (dessinée sous les persos)
	_surbrillance = ColorRect.new()
	_surbrillance.size = Vector2(Plateau.TAILLE_CASE, Plateau.TAILLE_CASE)
	_surbrillance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surbrillance.visible = false
	plateau.add_child(_surbrillance)
	plateau.move_child(_surbrillance, 0)

	_creer_interface(fenetre)
	partie.nouvelle_partie()


# =====================================================================
#  DÉROULEMENT D'UN NIVEAU
# =====================================================================

## Un niveau commence : les persos sont tirés, les ennemis sont placés.
func _sur_niveau_pret(_niveau: int, unites_joueur: Array[Unite]) -> void:
	ecran.visible = false
	fiche.visible = false
	_placer_au_depart(unites_joueur)
	plateau.vider()
	plateau.afficher_unites()
	# Les barres de vie ne doivent pas "avaler" les clics destinés aux persos
	for visuel in plateau.visuels.values():
		_laisser_passer_les_clics(visuel)

	_badges.clear()
	for unite in partie.combat.unites:
		_creer_badge(unite)
	_vider_liste(liste_joueur)
	_vider_liste(liste_ennemis)
	_maj_infos()

	phase = Phase.DES
	texte_aide.text = "Lance les dés pour découvrir les effets de ce round."
	bouton_combat.visible = false
	bouton_des.visible = true
	bouton_des.grab_focus()


## Clic sur "Lancer les dés" : les chiffres défilent puis s'arrêtent sur le résultat.
func _sur_bouton_des() -> void:
	Musique.lancer_des()
	if phase != Phase.DES:
		return
	phase = Phase.ANIMATION_DES
	bouton_des.visible = false

	# Le gros dé apparaît au milieu du plateau et tourne pendant que les chiffres défilent
	var de := _creer_gros_de()
	var tours := NOMBRE_DE_TIRAGES * DUREE_TIRAGE
	de.scale = Vector2.ZERO
	var animation := de.create_tween()
	animation.tween_property(de, "scale", Vector2.ONE, 0.15)
	animation.parallel().tween_property(de, "rotation", TAU * 2.0, tours)

	for i in NOMBRE_DE_TIRAGES:
		de.valeur = randi_range(1, 3)
		for unite in _badges:
			_badges[unite].valeur = randi_range(1, 3)
		await get_tree().create_timer(DUREE_TIRAGE).timeout
	for unite in _badges:
		_badges[unite].valeur = unite.face_de + 1

	# Le dé rétrécit et disparaît
	var sortie := de.create_tween()
	sortie.tween_property(de, "scale", Vector2.ZERO, 0.15)
	sortie.tween_callback(de.queue_free)

	for unite in partie.combat.unites:
		var liste := liste_joueur if unite.equipe == Unite.Equipe.JOUEUR else liste_ennemis
		_ajouter_a_la_liste(liste, unite)

	phase = Phase.PLACEMENT
	texte_aide.text = "Fais glisser tes persos pour les placer, puis lance le combat."
	bouton_combat.visible = true
	bouton_combat.grab_focus()


func _sur_bouton_combat() -> void:
	if phase != Phase.PLACEMENT:
		return
	_lacher()
	phase = Phase.COMBAT
	bouton_combat.visible = false
	texte_aide.text = ""
	partie.lancer_combat()


func _sur_niveau_gagne(niveau: int) -> void:
	_montrer_panneau(
		"Niveau %d réussi !" % niveau,
		"Prochain combat : niveau %d" % (niveau + 1),
		"Niveau suivant",
		partie.continuer)


func _sur_vie_perdue(vies_restantes: int) -> void:
	queue_redraw()  # met à jour les cœurs
	if vies_restantes <= 0:
		return  # c'est _sur_partie_perdue qui affiche le game over
	var vies := "1 vie" if vies_restantes == 1 else "%d vies" % vies_restantes
	_montrer_panneau(
		"Combat perdu",
		"Il te reste %s, et c'est ok!" % vies,
		"Réessayer",
		partie.continuer)


func _sur_partie_perdue() -> void:
	_montrer_panneau(
		"Game over",
		"Tu as atteint le niveau %d" % partie.niveau,
		"Rejouer",
		partie.nouvelle_partie)


func _sur_partie_gagnee() -> void:
	_montrer_panneau(
		"Victoire !",
		"Tu as terminé les %d niveaux" % partie.nombre_niveaux(),
		"Rejouer",
		partie.nouvelle_partie)


# =====================================================================
#  PLACEMENT À LA SOURIS
# =====================================================================

## Position de départ : au hasard dans la moitié du joueur. Il déplace ensuite ses persos.
func _placer_au_depart(unites: Array[Unite]) -> void:
	var cases: Array[Vector2i] = []
	for y in range(Combat.LIGNES - Combat.LIGNES_PAR_EQUIPE, Combat.LIGNES):
		for x in Combat.COLONNES:
			cases.append(Vector2i(x, y))
	cases.shuffle()
	for unite in unites:
		partie.combat.placer(unite, cases.pop_back())


## Clic sur le plateau : affiche la fiche du perso cliqué (allié ou ennemi),
## et pendant le placement, attrape le perso si c'est un des nôtres.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	# Position du clic dans le repère du plateau
	var point: Vector2 = plateau.make_input_local(event).position
	var unite := _unite_sous(point)
	_montrer_fiche(unite)
	if phase == Phase.PLACEMENT and unite != null and unite.equipe == Unite.Equipe.JOUEUR:
		_attraper(unite, point)


func _process(_delta: float) -> void:
	if _unite_glissee == null:
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_glisser(plateau.get_local_mouse_position())
	else:
		_lacher()


## Commence à déplacer ce perso. `point` = position de la souris sur le plateau.
func _attraper(unite: Unite, point: Vector2) -> void:
	_unite_glissee = unite
	var visuel: UniteVisuelle = plateau.visuels[unite]
	_decalage_glisser = visuel.position - point
	_surbrillance.visible = true
	_glisser(point)


func _glisser(point: Vector2) -> void:
	var visuel: UniteVisuelle = plateau.visuels[_unite_glissee]
	visuel.position = point + _decalage_glisser
	var case := plateau.case_sous(visuel.position)
	_surbrillance.position = plateau.coin_case(case)
	if partie.combat.dans_zone(case, Unite.Equipe.JOUEUR):
		_surbrillance.color = Color(1, 1, 1, 0.3)
	else:
		_surbrillance.color = Color(1, 0.2, 0.2, 0.3)


## Pose le perso sur la case visée. Si un allié y est déjà, ils échangent leurs places.
## Si la case n'est pas dans la moitié du joueur, le perso retourne d'où il vient.
func _lacher() -> void:
	if _unite_glissee == null:
		return
	var unite := _unite_glissee
	_unite_glissee = null
	_surbrillance.visible = false

	var combat := partie.combat
	var visuel: UniteVisuelle = plateau.visuels[unite]
	var case := plateau.case_sous(visuel.position)
	if combat.dans_zone(case, Unite.Equipe.JOUEUR) and case != unite.pos:
		var occupant: Unite = combat.grille.get(case)
		if occupant == null:
			combat.placer(unite, case)
		else:
			var ancienne := unite.pos
			combat.retirer(unite)
			combat.placer(occupant, ancienne)
			combat.placer(unite, case)
			var visuel_occupant: UniteVisuelle = plateau.visuels[occupant]
			visuel_occupant.aller_a(plateau.position_case(occupant.pos), false)
	visuel.aller_a(plateau.position_case(unite.pos), false)


## Rend tous les éléments d'interface d'un nœud (barres, textes) transparents aux clics.
func _laisser_passer_les_clics(noeud: Node) -> void:
	if noeud is Control:
		noeud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for enfant in noeud.get_children():
		_laisser_passer_les_clics(enfant)


## Le perso (allié ou ennemi) dont l'image contient ce point. Si plusieurs se
## chevauchent, on prend celui qui est devant (le plus bas à l'écran).
func _unite_sous(point: Vector2) -> Unite:
	var trouvee: Unite = null
	var plus_bas := -INF
	for unite in plateau.visuels:
		var visuel: UniteVisuelle = plateau.visuels[unite]
		if not is_instance_valid(visuel):
			continue
		var zone := Rect2(visuel.position + Vector2(-38, -visuel.hauteur), Vector2(76, visuel.hauteur + 10))
		if zone.has_point(point) and visuel.position.y > plus_bas:
			plus_bas = visuel.position.y
			trouvee = unite
	return trouvee


## Affiche la fiche d'un perso (nom, classe, portée). Avec null, la fiche se cache.
func _montrer_fiche(unite: Unite) -> void:
	if unite == null:
		fiche.visible = false
		return
	var camp := "allié" if unite.equipe == Unite.Equipe.JOUEUR else "ennemi"
	fiche_nom.text = "%s (%s)" % [unite.data.nom, camp]
	fiche_classe.text = "Classe : %s" % unite.data.nom_classe()
	fiche_portee.text = "Portée : %s" % InfosPersos.texte_portee(unite.portee)
	fiche.visible = true


# =====================================================================
#  DÉS : badge sur chaque perso + listes sur les côtés
# =====================================================================

## Le gros dé blanc qui tourne au milieu du plateau pendant le lancer.
func _creer_gros_de() -> FaceDe:
	var de := FaceDe.new(TAILLE_GROS_DE)
	de.position = plateau.position + plateau.taille() / 2.0 - de.size / 2.0
	add_child(de)
	return de


## Petit dé à côté de la barre de vie, qui affiche "?" puis la face obtenue.
func _creer_badge(unite: Unite) -> void:
	var visuel: UniteVisuelle = plateau.visuels.get(unite)
	if visuel == null:
		return
	var badge := FaceDe.new(TAILLE_PETIT_DE)
	badge.position = Vector2(UniteVisuelle.LARGEUR_BARRE / 2.0 + 5, -visuel.hauteur - 17)
	visuel.add_child(badge)
	_badges[unite] = badge


## Ajoute une ligne "Misa · dé 2" + la description de l'effet dans une liste.
func _ajouter_a_la_liste(liste: VBoxContainer, unite: Unite) -> void:
	var couleur := UniteVisuelle.COULEUR_JOUEUR if unite.equipe == Unite.Equipe.JOUEUR else UniteVisuelle.COULEUR_ENNEMI
	var bloc := VBoxContainer.new()
	bloc.add_theme_constant_override("separation", 0)
	liste.add_child(bloc)

	var titre := _creer_texte("%s · dé %d" % [unite.data.nom, unite.face_de + 1], 15)
	titre.add_theme_color_override("font_color", couleur.lightened(0.35))
	bloc.add_child(titre)

	var description := _creer_texte(partie.combat.description_de(unite), 13)
	description.add_theme_color_override("font_color", Color("d0d3e0"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(LARGEUR_LISTE, 0)
	bloc.add_child(description)


func _vider_liste(liste: VBoxContainer) -> void:
	for enfant in liste.get_children():
		enfant.queue_free()


# =====================================================================
#  INTERFACE
# =====================================================================

func _creer_interface(fenetre: Vector2) -> void:
	var calque := CanvasLayer.new()
	add_child(calque)

	# --- Colonne de gauche : niveau, vies, effets des dés du joueur
	texte_niveau = _creer_texte("", 26)
	texte_niveau.position = Vector2(24, 16)
	calque.add_child(texte_niveau)

	texte_ennemis = _creer_texte("", 15)
	texte_ennemis.position = Vector2(24, 100)
	calque.add_child(texte_ennemis)

	var titre_joueur := _creer_texte("Ton équipe", 18)
	titre_joueur.position = Vector2(24, 140)
	calque.add_child(titre_joueur)

	liste_joueur = VBoxContainer.new()
	liste_joueur.position = Vector2(24, 170)
	liste_joueur.add_theme_constant_override("separation", 8)
	calque.add_child(liste_joueur)

	texte_aide = _creer_texte("", 14)
	texte_aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texte_aide.size = Vector2(LARGEUR_LISTE, 44)
	texte_aide.position = Vector2(24, fenetre.y - 62)
	texte_aide.add_theme_color_override("font_color", Color("ffe9a8"))
	calque.add_child(texte_aide)

	# --- Colonne de droite : effets des dés des ennemis, boutons
	var x_droite := fenetre.x - LARGEUR_LISTE - 24
	var titre_ennemis := _creer_texte("Ennemis", 18)
	titre_ennemis.position = Vector2(x_droite, 16)
	calque.add_child(titre_ennemis)

	liste_ennemis = VBoxContainer.new()
	liste_ennemis.position = Vector2(x_droite, 130)  # sous les boutons Menu, Règles et Son
	liste_ennemis.add_theme_constant_override("separation", 8)
	calque.add_child(liste_ennemis)

	# Fiche du perso cliqué, juste au-dessus du gros bouton
	fiche = PanelContainer.new()
	var style_fiche := StyleBoxFlat.new()
	style_fiche.bg_color = Color("2f3242")
	style_fiche.border_color = Color("8a90a8")
	style_fiche.set_border_width_all(2)
	style_fiche.set_corner_radius_all(8)
	style_fiche.set_content_margin_all(10)
	fiche.add_theme_stylebox_override("panel", style_fiche)
	fiche.custom_minimum_size = Vector2(LARGEUR_LISTE, 0)
	fiche.position = Vector2(x_droite, fenetre.y - 56 - 24 - 12 - 96)
	fiche.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fiche.visible = false
	calque.add_child(fiche)
	var lignes_fiche := VBoxContainer.new()
	lignes_fiche.add_theme_constant_override("separation", 2)
	fiche.add_child(lignes_fiche)
	fiche_nom = _creer_texte("", 17)
	lignes_fiche.add_child(fiche_nom)
	fiche_classe = _creer_texte("", 14)
	fiche_classe.add_theme_color_override("font_color", Color("ffe9a8"))
	lignes_fiche.add_child(fiche_classe)
	fiche_portee = _creer_texte("", 14)
	lignes_fiche.add_child(fiche_portee)

	# Petit bouton pour revenir au menu, en haut à droite
	var bouton_menu := Button.new()
	bouton_menu.text = "Menu"
	bouton_menu.add_theme_font_size_override("font_size", 14)
	bouton_menu.size = Vector2(76, 30)
	bouton_menu.position = Vector2(fenetre.x - 76 - 24, 14)
	bouton_menu.pressed.connect(_sur_bouton_menu)
	calque.add_child(bouton_menu)

	# Bouton "Règles" juste en dessous du bouton Menu
	var bouton_regles := Button.new()
	bouton_regles.text = "Règles"
	bouton_regles.add_theme_font_size_override("font_size", 14)
	bouton_regles.size = Vector2(76, 30)
	bouton_regles.position = Vector2(fenetre.x - 76 - 24, 14 + 30 + 8)
	bouton_regles.pressed.connect(_sur_bouton_regles)
	calque.add_child(bouton_regles)

	# Bouton "Son" juste en dessous du bouton Règles (coupe / remet le son, comme dans le menu)
	bouton_son = Button.new()
	bouton_son.add_theme_font_size_override("font_size", 14)
	bouton_son.size = Vector2(76, 30)
	bouton_son.position = Vector2(fenetre.x - 76 - 24, 14 + (30 + 8) * 2)
	bouton_son.pressed.connect(_sur_bouton_son)
	calque.add_child(bouton_son)
	_maj_bouton_son()

	bouton_des = _creer_bouton("Lancer les dés", fenetre)
	bouton_des.pressed.connect(_sur_bouton_des)
	calque.add_child(bouton_des)

	bouton_combat = _creer_bouton("Lancer le combat", fenetre)
	bouton_combat.pressed.connect(_sur_bouton_combat)
	bouton_combat.visible = false
	calque.add_child(bouton_combat)

	# --- Écran par-dessus tout : voile sombre + panneau au centre
	ecran = Control.new()
	ecran.set_anchors_preset(Control.PRESET_FULL_RECT)
	ecran.visible = false
	calque.add_child(ecran)

	var voile := ColorRect.new()
	voile.color = Color(0, 0, 0, 0.6)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	ecran.add_child(voile)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	ecran.add_child(centre)

	var panneau := PanelContainer.new()
	panneau.custom_minimum_size = Vector2(440, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2f3242")
	style.border_color = Color("8a90a8")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	panneau.add_theme_stylebox_override("panel", style)
	centre.add_child(panneau)

	var marge := MarginContainer.new()
	for cote in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		marge.add_theme_constant_override(cote, 30)
	panneau.add_child(marge)

	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 16)
	marge.add_child(colonne)

	titre_panneau = _creer_texte("", 38)
	titre_panneau.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(titre_panneau)

	texte_panneau = _creer_texte("", 19)
	texte_panneau.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(texte_panneau)

	bouton_panneau = Button.new()
	bouton_panneau.add_theme_font_size_override("font_size", 20)
	bouton_panneau.custom_minimum_size = Vector2(220, 52)
	bouton_panneau.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bouton_panneau.pressed.connect(_sur_bouton_panneau)
	colonne.add_child(bouton_panneau)

	_creer_popup_regles(calque, fenetre)


## Fenêtre des règles : voile sombre (qui bloque les clics) + panneau avec une croix en haut à droite.
func _creer_popup_regles(calque: CanvasLayer, fenetre: Vector2) -> void:
	popup_regles = Control.new()
	popup_regles.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_regles.visible = false
	calque.add_child(popup_regles)

	var voile := ColorRect.new()
	voile.color = Color(0, 0, 0, 0.6)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_regles.add_child(voile)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_regles.add_child(centre)

	var panneau := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2f3242")
	style.border_color = Color("8a90a8")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(20)
	panneau.add_theme_stylebox_override("panel", style)
	centre.add_child(panneau)

	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 12)
	panneau.add_child(colonne)

	# Ligne du haut : titre à gauche, croix à droite
	var haut := HBoxContainer.new()
	colonne.add_child(haut)
	var titre := _creer_texte("Règles", 30)
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haut.add_child(titre)
	var croix := Button.new()
	croix.text = "X"
	croix.add_theme_font_size_override("font_size", 18)
	croix.custom_minimum_size = Vector2(36, 36)
	croix.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	croix.pressed.connect(_fermer_regles)
	haut.add_child(croix)

	# Le texte peut être plus haut que l'écran : on le met dans une zone qui défile
	var defilement := ScrollContainer.new()
	defilement.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defilement.custom_minimum_size = Vector2(minf(760, fenetre.x - 80), fenetre.y - 200)
	colonne.add_child(defilement)

	var texte := _creer_texte(load(SCRIPT_MENU).TEXTE_REGLES, 15)
	texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defilement.add_child(texte)


func _creer_texte(texte: String, taille: int) -> Label:
	var label := Label.new()
	label.text = texte
	label.add_theme_font_size_override("font_size", roundi(taille * 1.2))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	return label


## Les deux gros boutons (dés et combat) sont au même endroit, en bas à droite.
func _creer_bouton(texte: String, fenetre: Vector2) -> Button:
	var bouton := Button.new()
	bouton.text = texte
	bouton.add_theme_font_size_override("font_size", 20)
	bouton.size = Vector2(LARGEUR_LISTE, 56)
	bouton.position = Vector2(fenetre.x - LARGEUR_LISTE - 24, fenetre.y - 56 - 24)
	return bouton


## Affiche le panneau central avec un titre, un texte et un bouton.
## `action` est la fonction appelée quand on clique sur le bouton.
func _montrer_panneau(titre: String, texte: String, texte_bouton: String, action: Callable) -> void:
	# Petit délai pour laisser voir la fin du combat
	await get_tree().create_timer(DELAI_ECRAN).timeout
	titre_panneau.text = titre
	texte_panneau.text = texte
	bouton_panneau.text = texte_bouton
	_action_panneau = action
	ecran.visible = true
	bouton_panneau.grab_focus()


func _sur_bouton_menu() -> void:
	get_tree().change_scene_to_file(SCENE_MENU)


func _sur_bouton_regles() -> void:
	popup_regles.visible = true


func _sur_bouton_son() -> void:
	AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
	_maj_bouton_son()


func _maj_bouton_son() -> void:
	bouton_son.text = "Son : non" if AudioServer.is_bus_mute(0) else "Son : oui"


func _fermer_regles() -> void:
	popup_regles.visible = false


func _sur_bouton_panneau() -> void:
	ecran.visible = false
	_action_panneau.call()


func _maj_infos() -> void:
	texte_niveau.text = "Niveau %d / %d" % [partie.niveau, partie.nombre_niveaux()]
	var reglages: Dictionary = Partie.NIVEAUX[partie.niveau - 1]
	var info := "%d ennemis" % reglages["ennemis"]
	if reglages["bonus"] > 1.0:
		info += " renforcés (+%d %%)" % roundi((reglages["bonus"] - 1.0) * 100.0)
	texte_ennemis.text = info
	queue_redraw()


## Dessine les cœurs des vies en haut à gauche.
func _draw() -> void:
	if partie == null:
		return
	for i in Partie.VIES_DEPART:
		var couleur := COULEUR_COEUR if i < partie.vies else COULEUR_COEUR_VIDE
		_dessiner_coeur(Vector2(42 + i * 44, 76), 34.0, couleur)


func _dessiner_coeur(centre: Vector2, t: float, couleur: Color) -> void:
	draw_circle(centre + Vector2(-t * 0.25, -t * 0.15), t * 0.28, couleur)
	draw_circle(centre + Vector2(t * 0.25, -t * 0.15), t * 0.28, couleur)
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(-t * 0.51, -t * 0.03),
		centre + Vector2(t * 0.51, -t * 0.03),
		centre + Vector2(0, t * 0.55),
	]), couleur)
