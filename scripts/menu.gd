extends Control
## Le menu principal : Jouer, Personnages, Règles, Son.
## Définis menu.tscn comme scène principale (clic droit > Définir comme scène principale).
const IMAGE_FOND := "res://assets/images/fonds/menu.png"
const ASSOMBRIR_FOND := 0.35  ## 0 = image telle quelle, 1 = noir complet
const SCENE_JEU := "res://scenes/jeu.tscn"
## Le titre s'affiche en trois morceaux : texte, dé, texte -> "Entre les [dé à 2 points] mondes"
const TITRE_AVANT := "Entre les"
const TITRE_FACE_DE := 2  ## nombre de points sur le dé du titre
const TITRE_APRES := "mondes"
const TAILLE_TITRE := 64
## Le dessin du dé est le même que dans le jeu (la classe FaceDe de jeu.gd).
const FaceDe := preload("res://scripts/jeu.gd").FaceDe
const FOND := Color("23252f")
const LARGEUR_BOUTON := 300.0

const TEXTE_REGLES := """Un portail s'est ouvert sur un monde de chaos, peuplé de nos doubles maléfiques. Ils sont venus semer la zizanie. À toi de les renvoyer d'où ils viennent.

Ton but : repousser l'invasion en gagnant les 5 niveaux sans perdre tes 3 vies.

1. À chaque niveau, tu reçois 5 personnages tirés au hasard.

2. Lance les dés. Chaque personnage, allié comme ennemi, obtient un effet qui dépend de sa classe et de la face obtenue (1, 2 ou 3). Les effets sont affichés sur les côtés.

3. Place tes personnages sur ta moitié du plateau en les faisant glisser. Clique sur un personnage pour voir sa classe et sa portée d'attaque.

4. Lance le combat. Les personnages se battent tout seuls et attaquent l'ennemi le plus proche.

Si tu gagnes, tu passes au niveau suivant. Si tu perds, tu perds une vie et tu recommences le niveau avec un nouveau tirage."""

var page_accueil: Control
var page_persos: Control
var page_regles: Control
var bouton_son: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	RenderingServer.set_default_clear_color(FOND)
	Musique.retour_menu()
	
	var fond := ColorRect.new()
	fond.color = FOND
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)
	# Image de fond, si elle existe
	if ResourceLoader.exists(IMAGE_FOND):
		var image_fond := TextureRect.new()
		image_fond.texture = load(IMAGE_FOND)
		image_fond.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image_fond.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image_fond.set_anchors_preset(Control.PRESET_FULL_RECT)
		image_fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(image_fond)

		# Voile sombre par-dessus, pour que les textes restent lisibles
		var voile := ColorRect.new()
		voile.color = Color(0, 0, 0, ASSOMBRIR_FOND)
		voile.set_anchors_preset(Control.PRESET_FULL_RECT)
		voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(voile)
	page_accueil = _creer_page_accueil()
	page_persos = _creer_page_persos()
	page_regles = _creer_page_regles()
	_montrer(page_accueil)


func _montrer(page: Control) -> void:
	for p in [page_accueil, page_persos, page_regles]:
		p.visible = (p == page)


# =====================================================================
#  PAGE D'ACCUEIL
# =====================================================================

func _creer_page_accueil() -> Control:
	var page := CenterContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(page)

	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 14)
	page.add_child(colonne)

	colonne.add_child(_creer_titre())

	var espace := Control.new()
	espace.custom_minimum_size = Vector2(0, 26)
	colonne.add_child(espace)

	colonne.add_child(_creer_bouton("Jouer", _sur_jouer))
	colonne.add_child(_creer_bouton("Personnages", _montrer_persos))
	colonne.add_child(_creer_bouton("Règles", _montrer_regles))
	bouton_son = _creer_bouton("", _sur_son)
	colonne.add_child(bouton_son)
	_maj_bouton_son()
	var credits := _creer_texte("Un jeu de Samia, Dalia et Ismael\nPolice : Pirata One (Google Fonts)", 13)
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits.add_theme_color_override("font_color", Color("c3c7d6"))
	colonne.add_child(credits)
	return page


## Le titre du jeu, avec un dé à la place du mot "deux".
func _creer_titre() -> Control:
	var ligne := HBoxContainer.new()
	ligne.alignment = BoxContainer.ALIGNMENT_CENTER
	ligne.add_theme_constant_override("separation", 20)

	ligne.add_child(_creer_texte(TITRE_AVANT, TAILLE_TITRE))

	# Le dé est posé dans un "support" de la même taille : la ligne de texte range
	# le support, et le dé peut rester penché à l'intérieur.
	var de := FaceDe.new(TAILLE_TITRE * 1.05)
	de.valeur = TITRE_FACE_DE
	de.rotation = -0.12  # légèrement penché, comme un dé qu'on vient de lancer
	var support := Control.new()
	support.custom_minimum_size = de.size
	support.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	support.add_child(de)
	ligne.add_child(support)

	ligne.add_child(_creer_texte(TITRE_APRES, TAILLE_TITRE))
	return ligne


func _sur_jouer() -> void:
	get_tree().change_scene_to_file(SCENE_JEU)


func _montrer_persos() -> void:
	_montrer(page_persos)


func _montrer_regles() -> void:
	_montrer(page_regles)


## Coupe ou remet tout le son du jeu (le bus "Master").
func _sur_son() -> void:
	AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
	_maj_bouton_son()


func _maj_bouton_son() -> void:
	bouton_son.text = "Son : coupé" if AudioServer.is_bus_mute(0) else "Son : activé"


# =====================================================================
#  PAGE DES PERSONNAGES
# =====================================================================

func _creer_page_persos() -> Control:
	var page := _creer_page_avec_titre("Les personnages")
	var colonne: VBoxContainer = page.get_meta("colonne")

	var defilement := ScrollContainer.new()
	defilement.custom_minimum_size = Vector2(1090, 470)
	defilement.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Rectangle sombre semi-transparent derrière les personnages
	var cadre := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.65)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(16)
	cadre.add_theme_stylebox_override("panel", style)
	cadre.add_child(defilement)
	colonne.add_child(cadre)

	var grille := GridContainer.new()
	grille.columns = 5
	grille.add_theme_constant_override("h_separation", 14)
	grille.add_theme_constant_override("v_separation", 18)
	defilement.add_child(grille)

	for data in PersoData.tous():
		grille.add_child(_creer_carte(data))

	colonne.add_child(_creer_bouton("Retour", _retour))
	return page


## La carte d'un perso : image, nom, classe, portée, petite info.
func _creer_carte(data: PersoData) -> Control:
	var largeur := 204.0
	var carte := VBoxContainer.new()
	carte.custom_minimum_size = Vector2(largeur, 0)
	carte.add_theme_constant_override("separation", 2)

	var texture := _image_perso(data.nom)
	if texture != null:
		var image := TextureRect.new()
		image.texture = texture
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = Vector2(largeur, 100)
		carte.add_child(image)
	else:
		var centre := CenterContainer.new()
		centre.custom_minimum_size = Vector2(largeur, 100)
		var bloc := ColorRect.new()
		bloc.color = UniteVisuelle.COULEURS_CLASSES[data.classe]
		bloc.custom_minimum_size = Vector2(54, 86)
		centre.add_child(bloc)
		carte.add_child(centre)

	var nom := _creer_texte(data.nom, 20)
	nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	carte.add_child(nom)

	var classe := _creer_texte("Classe : %s" % data.nom_classe(), 14)
	classe.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	classe.add_theme_color_override("font_color", Color("ffe9a8"))
	carte.add_child(classe)

	var portee := _creer_texte("Portée : %s" % InfosPersos.texte_portee(data.portee), 13)
	portee.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	carte.add_child(portee)

	var info := _creer_texte(InfosPersos.pour(data.nom), 13)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(largeur, 0)
	info.add_theme_color_override("font_color", Color("c3c7d6"))
	carte.add_child(info)
	return carte


## Charge l'image d'un perso (même dossier et mêmes noms que sur le plateau)
## et enlève les marges transparentes autour du dessin.
func _image_perso(nom: String) -> Texture2D:
	for base in [nom.to_lower(), nom]:
		for extension in Plateau.EXTENSIONS:
			var chemin: String = Plateau.DOSSIER_IMAGES + base + extension
			if not ResourceLoader.exists(chemin):
				continue
			var texture: Texture2D = load(chemin)
			var image := texture.get_image()
			if image == null or image.is_compressed():
				return texture
			var zone := image.get_used_rect()
			if zone.size.x <= 0 or zone.size.y <= 0:
				return texture
			var decoupe := AtlasTexture.new()
			decoupe.atlas = texture
			decoupe.region = Rect2(zone)
			return decoupe
	return null


# =====================================================================
#  PAGE DES RÈGLES
# =====================================================================

func _creer_page_regles() -> Control:
	var page := _creer_page_avec_titre("Règles")
	var colonne: VBoxContainer = page.get_meta("colonne")

	var texte := _creer_texte(TEXTE_REGLES, 17)
	texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texte.custom_minimum_size = Vector2(1000, 0)
	# Rectangle sombre semi-transparent derrière le texte
	var cadre := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.65)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(20)
	cadre.add_theme_stylebox_override("panel", style)
	cadre.add_child(texte)
	colonne.add_child(cadre)

	colonne.add_child(_creer_bouton("Que les dés te soient favorables!", _retour))
	return page


func _retour() -> void:
	_montrer(page_accueil)


# =====================================================================
#  OUTILS
# =====================================================================

## Une page plein écran avec un titre en haut. Le contenu s'ajoute dans sa "colonne".
func _creer_page_avec_titre(titre: String) -> Control:
	var page := CenterContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(page)

	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 16)
	page.add_child(colonne)
	page.set_meta("colonne", colonne)

	var label := _creer_texte(titre, 38)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(label)
	return page


func _creer_texte(texte: String, taille: int) -> Label:
	var label := Label.new()
	label.text = texte
	label.add_theme_font_size_override("font_size", roundi(taille * 1.2))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	return label


func _creer_bouton(texte: String, action: Callable) -> Button:
	var bouton := Button.new()
	bouton.text = texte
	bouton.add_theme_font_size_override("font_size", 22)
	bouton.custom_minimum_size = Vector2(LARGEUR_BOUTON, 56)
	bouton.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bouton.pressed.connect(action)
	return bouton
