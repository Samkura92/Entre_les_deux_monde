extends Node2D
## Scène de test VISUELLE : un combat complet sur le plateau, avec tes dessins.
## Ouvre test_combat_visuel.tscn puis F6. Espace ou Entrée = nouveau combat.

const FOND := Color("23252f")
const DELAI_AVANT_COMBAT := 1.5  ## secondes pour regarder le placement avant que ça tape

var combat: Combat
var plateau: Plateau
var texte_resultat: Label
var _numero_combat: int = 0


func _ready() -> void:
	RenderingServer.set_default_clear_color(FOND)

	combat = Combat.new()
	add_child(combat)
	combat.de_lance.connect(_sur_de_lance)
	combat.combat_termine.connect(_sur_fin)

	plateau = Plateau.new()
	add_child(plateau)
	plateau.brancher(combat)
	# Plateau centré en largeur, collé en bas pour laisser de la place aux têtes de la ligne du haut
	var fenetre := get_viewport_rect().size
	var taille := plateau.taille()
	plateau.position = Vector2((fenetre.x - taille.x) / 2.0, fenetre.y - taille.y - 20.0).round()

	var aide := _creer_texte("Espace : nouveau combat", 16)
	aide.position = Vector2(16, 12)
	add_child(aide)

	texte_resultat = _creer_texte("", 44)
	texte_resultat.size = Vector2(fenetre.x, 60)
	texte_resultat.position = Vector2(0, fenetre.y / 2.0 - 30)
	texte_resultat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(texte_resultat)

	nouveau_combat()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		nouveau_combat()


func nouveau_combat() -> void:
	_numero_combat += 1
	var numero := _numero_combat
	texte_resultat.text = ""
	combat.vider()
	plateau.vider()

	print("")
	print("=== NOUVEAU COMBAT ===")
	# Les 5 persos du joueur, dés lancés, posés au hasard dans la moitié du bas.
	var cases: Array[Vector2i] = []
	for y in range(Combat.LIGNES - Combat.LIGNES_PAR_EQUIPE, Combat.LIGNES):
		for x in Combat.COLONNES:
			cases.append(Vector2i(x, y))
	cases.shuffle()
	for data in PersoData.tirage(5):
		var unite := combat.creer_unite(data, Unite.Equipe.JOUEUR)
		combat.lancer_de(unite)
		combat.placer(unite, cases.pop_back())

	combat.generer_ennemis(5)
	plateau.afficher_unites()

	await get_tree().create_timer(DELAI_AVANT_COMBAT).timeout
	if numero == _numero_combat:  # on n'a pas relancé entre-temps
		combat.demarrer()


func _sur_de_lance(unite: Unite, face: int, description: String) -> void:
	print("%s -> face %d : %s" % [unite.nom_complet(), face + 1, description])


func _sur_fin(gagnant: int) -> void:
	match gagnant:
		Unite.Equipe.JOUEUR:
			texte_resultat.text = "Victoire !"
		Unite.Equipe.ENNEMI:
			texte_resultat.text = "Défaite..."
		_:
			texte_resultat.text = "Égalité"


func _creer_texte(texte: String, taille: int) -> Label:
	var label := Label.new()
	label.text = texte
	label.add_theme_font_size_override("font_size", taille)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	return label
