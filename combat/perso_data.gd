class_name PersoData
extends Resource
## Les stats d'un perso (la "carte"). Ne contient aucune logique de combat.

enum Classe { ASSASSIN, MAGE, TANK, HEALER, DPS }

const NOMS_CLASSES := {
	Classe.ASSASSIN: "Assassin",
	Classe.MAGE: "Mage",
	Classe.TANK: "Tank",
	Classe.HEALER: "Healer",
	Classe.DPS: "Dps",
}

## Les classes qui tapent avec l'Ap (réduit par la Rm de la cible).
## Les autres tapent avec l'Ad (réduit par l'Armure).
const CLASSES_MAGIQUES := [Classe.MAGE, Classe.HEALER]

## ÉQUILIBRAGE : les 10 persos du jeu, 2 par classe.
## vitesse = attaques par seconde, portee = nombre de cases (1 = corps à corps)
const PERSONNAGES := [
	# Assassins : Kayn fragile mais tape très fort / Sonia plus solide et rapide
	{"nom": "Kayn", "classe": Classe.ASSASSIN, "pv": 480, "ad": 85, "ap": 0, "armure": 20, "rm": 20, "vitesse": 1.0, "portee": 1},
	{"nom": "Sonia", "classe": Classe.ASSASSIN, "pv": 620, "ad": 55, "ap": 0, "armure": 30, "rm": 30, "vitesse": 1.4, "portee": 1},
	# Mages : Dalia gros dégâts lents / Blaise rapide à longue portée
	{"nom": "Dalia", "classe": Classe.MAGE, "pv": 480, "ad": 0, "ap": 100, "armure": 20, "rm": 30, "vitesse": 0.6, "portee": 3},
	{"nom": "Cassie", "classe": Classe.MAGE, "pv": 520, "ad": 0, "ap": 65, "armure": 20, "rm": 30, "vitesse": 0.9, "portee": 4},
	# Tanks : Franck sac à Pv / Rebecca beaucoup d'Armure et de Rm
	{"nom": "Franck", "classe": Classe.TANK, "pv": 1200, "ad": 40, "ap": 0, "armure": 45, "rm": 40, "vitesse": 0.6, "portee": 1},
	{"nom": "Rebecca", "classe": Classe.TANK, "pv": 850, "ad": 40, "ap": 0, "armure": 80, "rm": 70, "vitesse": 0.6, "portee": 1},
	# Healers : Sakura tape un peu / Yuna très résistante
	{"nom": "Samkura", "classe": Classe.HEALER, "pv": 520, "ad": 0, "ap": 55, "armure": 20, "rm": 30, "vitesse": 0.8, "portee": 3},
	{"nom": "Yuna", "classe": Classe.HEALER, "pv": 700, "ad": 0, "ap": 30, "armure": 35, "rm": 40, "vitesse": 0.7, "portee": 3},
	# Dps : Misa longue portée / Yoan courte portée mais tape plus fort
	{"nom": "Misa", "classe": Classe.DPS, "pv": 550, "ad": 55, "ap": 0, "armure": 25, "rm": 25, "vitesse": 0.9, "portee": 4},
	{"nom": "Yohan", "classe": Classe.DPS, "pv": 650, "ad": 75, "ap": 0, "armure": 25, "rm": 25, "vitesse": 0.9, "portee": 2},
]

@export var nom: String = ""
@export var classe: Classe = Classe.DPS
@export var pv: int = 100
@export var ad: int = 0
@export var ap: int = 0
@export var armure: int = 0
@export var rm: int = 0
@export var vitesse_attaque: float = 1.0  ## attaques par seconde
@export var portee: int = 1
@export var degats_magiques: bool = false


## Crée un perso à partir de son nom ("Kayn", "Yuna"...). Renvoie null si le nom n'existe pas.
static func creer(p_nom: String) -> PersoData:
	for fiche in PERSONNAGES:
		if fiche["nom"].to_lower() == p_nom.to_lower():
			return _depuis_fiche(fiche)
	push_error("Perso inconnu : " + p_nom)
	return null


## Les 10 persos du jeu.
static func tous() -> Array[PersoData]:
	var resultat: Array[PersoData] = []
	for fiche in PERSONNAGES:
		resultat.append(_depuis_fiche(fiche))
	return resultat


## Tire `nombre` persos au hasard, tous différents (les 5 persos du round).
static func tirage(nombre: int = 5) -> Array[PersoData]:
	var persos := tous()
	persos.shuffle()
	return persos.slice(0, nombre)


static func _depuis_fiche(fiche: Dictionary) -> PersoData:
	var p := PersoData.new()
	p.nom = fiche["nom"]
	p.classe = fiche["classe"]
	p.pv = fiche["pv"]
	p.ad = fiche["ad"]
	p.ap = fiche["ap"]
	p.armure = fiche["armure"]
	p.rm = fiche["rm"]
	p.vitesse_attaque = fiche["vitesse"]
	p.portee = fiche["portee"]
	p.degats_magiques = p.classe in CLASSES_MAGIQUES
	return p


func nom_classe() -> String:
	return NOMS_CLASSES[classe]
