class_name UniteVisuelle
extends Node2D
## L'affichage d'UN perso sur le plateau : image, ombre, barre de vie, animations.
## C'est le Plateau qui crée ces nœuds, tu n'as pas à en poser à la main.

const COULEUR_JOUEUR := Color("4a90e2")
const COULEUR_ENNEMI := Color("e2504a")
const LARGEUR_BARRE := 56.0
const HAUTEUR_BARRE := 7.0

## Couleurs des carrés de remplacement quand l'image d'un perso est introuvable.
const COULEURS_CLASSES := {
	PersoData.Classe.ASSASSIN: Color("3a3a44"),
	PersoData.Classe.MAGE: Color("7b3fa0"),
	PersoData.Classe.TANK: Color("9aa3ad"),
	PersoData.Classe.HEALER: Color("f2a6d0"),
	PersoData.Classe.DPS: Color("4f9a5b"),
}

var unite: Unite
var hauteur: float = 120.0

var _corps: Node2D
var _barre_vie: ColorRect
var _etiquette_stun: Label
var _couleur_equipe: Color
var _tween_deplacement: Tween
var _tween_coup: Tween


## texture peut être null : on affiche alors un rectangle de couleur à la place.
func initialiser(p_unite: Unite, texture: Texture2D, region: Rect2, echelle: float, p_hauteur: float) -> void:
	unite = p_unite
	hauteur = p_hauteur
	_couleur_equipe = COULEUR_JOUEUR if unite.equipe == Unite.Equipe.JOUEUR else COULEUR_ENNEMI

	_corps = Node2D.new()
	add_child(_corps)
	if texture != null:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.region_enabled = true
		sprite.region_rect = region
		sprite.scale = Vector2(echelle, echelle)
		# Les pieds du perso sont posés sur l'origine du nœud.
		sprite.position = Vector2(-region.size.x * echelle / 2.0, -region.size.y * echelle)
		_corps.add_child(sprite)
	else:
		var bloc := ColorRect.new()
		bloc.color = COULEURS_CLASSES[unite.data.classe]
		bloc.size = Vector2(48, hauteur * 0.75)
		bloc.position = Vector2(-24, -bloc.size.y)
		_corps.add_child(bloc)

	var haut := -hauteur - 6.0
	var fond := ColorRect.new()
	fond.color = Color(0, 0, 0, 0.75)
	fond.size = Vector2(LARGEUR_BARRE + 2, HAUTEUR_BARRE + 2)
	fond.position = Vector2(-LARGEUR_BARRE / 2.0 - 1, haut - 1)
	add_child(fond)
	_barre_vie = ColorRect.new()
	_barre_vie.color = _couleur_equipe
	_barre_vie.size = Vector2(LARGEUR_BARRE, HAUTEUR_BARRE)
	_barre_vie.position = Vector2(-LARGEUR_BARRE / 2.0, haut)
	add_child(_barre_vie)

	var nom := _creer_etiquette(unite.data.nom, 13, Color.WHITE)
	nom.position = Vector2(-60, haut - 22)
	add_child(nom)

	_etiquette_stun = _creer_etiquette("STUN", 13, Color("ffe14d"))
	_etiquette_stun.position = Vector2(-60, haut - 38)
	_etiquette_stun.visible = false
	add_child(_etiquette_stun)

	queue_redraw()


func _creer_etiquette(texte: String, taille: int, couleur: Color) -> Label:
	var label := Label.new()
	label.text = texte
	label.size = Vector2(120, 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", taille)
	label.add_theme_color_override("font_color", couleur)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	return label


## Ombre ovale sous les pieds, de la couleur de l'équipe.
func _draw() -> void:
	if unite == null:
		return
	draw_set_transform(Vector2(0, -3), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 32.0, Color(_couleur_equipe, 0.75))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func maj_vie() -> void:
	var ratio := clampf(float(unite.pv) / float(unite.pv_max), 0.0, 1.0)
	_barre_vie.size.x = LARGEUR_BARRE * ratio


func aller_a(destination: Vector2, teleportation: bool) -> void:
	if _tween_deplacement != null:
		_tween_deplacement.kill()
	if teleportation:
		position = destination
		modulate.a = 0.0
		_tween_deplacement = create_tween()
		_tween_deplacement.tween_property(self, "modulate:a", 1.0, 0.25)
	else:
		_tween_deplacement = create_tween()
		_tween_deplacement.tween_property(self, "position", destination, 0.3)


## Petit élan vers la cible puis retour.
func frapper_vers(point: Vector2) -> void:
	var direction := (point - position).normalized()
	if _tween_coup != null:
		_tween_coup.kill()
	_tween_coup = create_tween()
	_tween_coup.tween_property(_corps, "position", direction * 14.0, 0.07)
	_tween_coup.tween_property(_corps, "position", Vector2.ZERO, 0.13)


## Flash rouge quand le perso prend un coup.
func prendre_coup() -> void:
	_corps.modulate = Color(1.0, 0.45, 0.45)
	create_tween().tween_property(_corps, "modulate", Color.WHITE, 0.2)


func soigner() -> void:
	_corps.modulate = Color(0.6, 1.0, 0.6)
	create_tween().tween_property(_corps, "modulate", Color.WHITE, 0.3)


func etourdir(duree: float) -> void:
	_etiquette_stun.visible = true
	await get_tree().create_timer(duree).timeout
	_etiquette_stun.visible = false


func mourir() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)
