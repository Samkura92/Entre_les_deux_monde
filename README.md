# Entre les ⚁ mondes

🇫🇷 [Français](#-français) · 🇬🇧 [English](#-english)

---

## 🇫🇷 Français

**Entre les deux mondes** est un auto-battler avec des dés, réalisé en 3 jours sur Godot pour la [SD Gamejam 2026](https://itch.io/jam/sd-2026) (Slice & Dice).

C'est notre toute première game jam, et toute l'équipe débutait sur un moteur de jeu.

🎮 **Jouer :** [samkura.itch.io/entre-les-deux-mondes](https://samkura.itch.io/entre-les-deux-mondes)

### L'histoire

Un monde parallèle s'est ouvert. De l'autre côté, on retrouve les mêmes personnages... mais en version maléfique. Seuls les assassins restent neutres : ils se battent dans les deux camps.

### Comment jouer

1. À chaque niveau, tu reçois **5 personnages aléatoires**.
2. Tu appuies sur **Lancer les dés** : chaque personnage lance son **dé spécial à 3 faces**, dont l'effet dépend de sa classe.
3. Tu places ensuite tes personnages sur ta moitié du plateau.
4. Quand tu es prêt, tu appuies sur **Lancer le combat** : les personnages se battent tout seuls et attaquent l'ennemi le plus proche.

Le plateau fait 6 x 6 cases, coupé en deux : 3 lignes pour toi, 3 lignes pour l'ennemi.

Tu affrontes l'ordinateur sur **5 niveaux** de plus en plus difficiles, avec des ennemis tirés au hasard. Tu as **3 vies** : si tu perds un combat, tu perds une vie et tu recommences le niveau avec un nouveau tirage.

### Les classes

| Classe | Portée | Personnages |
|---|---|---|
| **Assassin** | Corps à corps | Kayn, Sonia |
| **Mage** | Distance | Dalia, Cassie |
| **Tank** | Corps à corps | Franck, Rebecca |
| **Healer** | Distance | Samkura, Yuna |
| **Dps** | Distance | Misa, Yohan |

### Les dés

Chaque classe a son propre dé. Voici l'effet de chaque face :

| Classe | 🎲 1 | 🎲 2 | 🎲 3 |
|---|---|---|---|
| **Assassin** | Augmente ses dégâts (+50 %) | Se téléporte près d'un ennemi de la ligne arrière | Se téléporte **et** augmente ses dégâts |
| **Mage** | Augmente ses dégâts magiques (+50 %) | Étourdit un ennemi de la ligne arrière (1,5 s) | Étourdit toute l'équipe ennemie (1,5 s) |
| **Tank** | Augmente son armure et sa résistance magique (+30) | Pareil pour lui et ses alliés adjacents | Pareil pour toute son équipe |
| **Healer** | Soigne les alliés adjacents et lui-même (60 PV toutes les 3 s) | Soigne toute son équipe (60 PV toutes les 3 s) | Augmente les dégâts de toute son équipe (+25 %) |
| **Dps** | Inflige des dégâts bruts (ignore l'armure) | Augmente sa portée (+2 cases) | Augmente sa vitesse d'attaque (+50 %) |

Chaque personnage a ses propres statistiques : dégâts d'attaque (AD), puissance magique (AP), armure, résistance magique (RM), vitesse d'attaque et points de vie (PV).

### Réalisation

- **Moteur :** Godot
- **Dessins :** personnages et plateau dessinés à la main sur Clip Studio
- **Police :** Pirata One
- **Durée :** 3 jours

### Équipe

- **Samia :** logique de combat, dessins
- **Dalia :** histoire, son
- **Ismael :** idée du style de jeu, gameplay

### Résultat

Classé 25e sur 36 à la SD Gamejam 2026.

---

## 🇬🇧 English

**Entre les deux mondes** ("Between the Two Worlds") is a dice-based auto-battler made in 3 days with Godot for the [SD Gamejam 2026](https://itch.io/jam/sd-2026) (Slice & Dice).

This is our very first game jam, and the whole team was new to game engines.

🎮 **Play:** [samkura.itch.io/entre-les-deux-mondes](https://samkura.itch.io/entre-les-deux-mondes)

### Story

A parallel world has opened. On the other side are the very same characters... but as evil versions of themselves. Only the assassins stay neutral: they fight on both sides.

### How to play

1. Each level, you get **5 random characters**.
2. Press **Roll the dice**: each character rolls their **special 3-sided die**, whose effect depends on their class.
3. You then place your characters on your half of the board.
4. When you're ready, press **Start the fight**: the characters fight on their own and attack the nearest enemy.

The board is a 6 x 6 grid split in two: 3 rows for you, 3 rows for the enemy.

You play against the computer through **5 levels** of increasing difficulty, with randomly picked enemies. You have **3 lives**: if you lose a fight, you lose a life and replay the level with a new draw.

### Classes

| Class | Range | Characters |
|---|---|---|
| **Assassin** | Melee | Kayn, Sonia |
| **Mage** | Ranged | Dalia, Cassie |
| **Tank** | Melee | Franck, Rebecca |
| **Healer** | Ranged | Samkura, Yuna |
| **Dps** | Ranged | Misa, Yohan |

### Dice

Each class has its own die. Here is what each face does:

| Class | 🎲 1 | 🎲 2 | 🎲 3 |
|---|---|---|---|
| **Assassin** | Boosts own damage (+50%) | Teleports next to a back-line enemy | Teleports **and** boosts own damage |
| **Mage** | Boosts own magic damage (+50%) | Stuns one back-line enemy (1.5 s) | Stuns the whole enemy team (1.5 s) |
| **Tank** | Boosts own armor and magic resistance (+30) | Same for itself and adjacent allies | Same for the whole team |
| **Healer** | Heals adjacent allies and itself (60 HP every 3 s) | Heals the whole team (60 HP every 3 s) | Boosts the whole team's damage (+25%) |
| **Dps** | Deals true damage (ignores armor) | Increases own range (+2 tiles) | Increases own attack speed (+50%) |

Each character has their own stats: attack damage (AD), ability power (AP), armor, magic resistance (MR), attack speed and health (HP).

### Made with

- **Engine:** Godot
- **Art:** hand-drawn characters and board, made in Clip Studio
- **Font:** Pirata One
- **Time:** 3 days

### Team

- **Samia:** combat logic, art
- **Dalia:** story, sound
- **Ismael:** game style idea, gameplay

### Result

Ranked 25th out of 36 at the SD Gamejam 2026.
