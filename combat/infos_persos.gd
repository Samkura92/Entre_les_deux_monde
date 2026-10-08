class_name InfosPersos
## Les petites infos sur les persos, affichées dans le menu "Personnages".
## La clé est le nom du perso en minuscules (comme le nom de son image).
## Tu peux écrire ce que tu veux entre les guillemets.

const INFOS := {
	"kayn": "Travaille pour les deux mondes. Ne paie d'impôts dans aucun.",
	"sonia": "Change de camp plus souvent que de dagues.",
	"dalia": "Aime tellement le sucre que ses sorts sentent le caramel.",
	"cassie": "Lance ses sorts de très loin. Elle dit que c'est tactique, pas de la timidité.",
	"franck": "N'a jamais enlevé son armure. Personne ne sait pourquoi.",
	"rebecca": "A donné un prénom à son bouclier. Elle refuse de le dire.",
	"samkura": "Soigne tout le monde, sauf ceux qui lui piquent ses chocolats.",
	"yuna": "Soigne les blessures en un instant. Les rancunes, jamais.",
	"misa": "Son double maléfique lui a volé sa coiffure. C'est personnel.",
	"yohan": "Rate rarement sa cible. Rate toujours son réveil.", 
}


## Renvoie l'info d'un perso, ou un texte vide s'il n'est pas dans la liste.
static func pour(nom: String) -> String:
	return INFOS.get(nom.to_lower(), "")


## "1 case (corps à corps)" ou "3 cases (à distance)".
static func texte_portee(portee: int) -> String:
	if portee <= 1:
		return "1 case (corps à corps)"
	return "%d cases (à distance)" % portee
