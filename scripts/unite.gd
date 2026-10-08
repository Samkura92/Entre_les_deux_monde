class_name Unite
extends RefCounted
## Un perso EN COMBAT : sa carte (PersoData) + son état du moment
## (Pv actuels, position, buffs du dé, stun...).

enum Equipe { JOUEUR, ENNEMI }
enum ZoneSoin { AUCUNE, ADJACENTS, EQUIPE }

const NON_PLACEE := Vector2i(-1, -1)

var data: PersoData
var equipe: Equipe
var pos: Vector2i = NON_PLACEE  ## x = colonne, y = ligne
var vivante: bool = true

# Stats de combat (copiées depuis data, puis modifiées par les dés)
var pv_max: int
var pv: int
var ad: float
var ap: float
var armure: float
var rm: float
var vitesse_attaque: float
var portee: int

# Effets du dé
var face_de: int = -1  ## -1 = pas encore lancé, sinon 0, 1 ou 2
var degats_bruts: bool = false  ## ignore l'Armure / la Rm
var zone_soin: ZoneSoin = ZoneSoin.AUCUNE

# Chronos internes
var temps_stun: float = 0.0
var recharge_attaque: float = 0.0
var recharge_deplacement: float = 0.0
var recharge_soin: float = 0.0


func _init(p_data: PersoData, p_equipe: Equipe) -> void:
	data = p_data
	equipe = p_equipe
	pv_max = data.pv
	pv = data.pv
	ad = data.ad
	ap = data.ap
	armure = data.armure
	rm = data.rm
	vitesse_attaque = data.vitesse_attaque
	portee = data.portee


## Multiplie les Pv et les dégâts (pour les ennemis des niveaux difficiles).
func appliquer_bonus(multiplicateur: float) -> void:
	pv_max = roundi(pv_max * multiplicateur)
	pv = pv_max
	ad *= multiplicateur
	ap *= multiplicateur


func est_placee() -> bool:
	return pos != NON_PLACEE


func nom_complet() -> String:
	var camp := "J" if equipe == Equipe.JOUEUR else "E"
	return "[%s] %s (%s)" % [camp, data.nom, data.nom_classe()]
