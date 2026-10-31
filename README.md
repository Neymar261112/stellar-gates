# Arches & Astrions – prototype Godot

Deux cartes de test en 3D, Élyra et Varda, reliées par une Arche. Le Solaris court, dash, vole (8 s avant surchauffe), tombe dans les gouffres, et la pause tactique fixe une destination. Trois balises par carte.

## Ouvrir le projet
1. Installer **Godot 4.3** (version standard, pas .NET) : https://godotengine.org/download
2. Ouvrir Godot → **Importer** → choisir le fichier `project.godot` de ce dossier.
3. Appuyer sur **F5** (ou le bouton Play en haut à droite). Le premier lancement importe le modèle et les textures, ça prend quelques secondes.

## Commandes
| Action | Manette (Xbox) | Clavier / souris |
|---|---|---|
| Se déplacer | stick gauche | ZQSD ou flèches |
| Caméra (et direction du vol) | stick droit | souris (premier clic pour la capturer, Échap pour la libérer) |
| Sauter, puis **double saut = décollage** | A | Espace |
| En vol : A = vol stationnaire / reprendre le vol | A | Espace |
| En vol : couper les propulseurs (atterrir) | Y | Ctrl |
| Au sol : **changer d'arme** (fusil d'assaut ↔ Twin Vipers, l'autre est dans le dos) | Y | T ou molette |
| **Esquive** au sol : bond propulsé dans la direction du stick (en arrière sans direction), intouchable pendant la poussée | B (appui court) | Maj |
| **Se cacher** derrière un obstacle (B **maintenu** près d'un mur, d'un rocher, d'un muret) ; B à nouveau pour sortir | B maintenu | C |
| À couvert : glisser le long de l'obstacle / sortir pour tirer / sauter par-dessus un muret | stick gauche / LT ou RT / A | ZQSD / clic droit ou gauche / Espace |
| **Courir** (bascule, s'arrête quand on lâche le stick ou qu'on vise) | clic stick gauche | Q (A sur AZERTY) |
| En vol : **vrille** à gauche / à droite | B + stick à gauche / à droite | Maj + Q / D |
| En vol : boost | B (stick au centre) ou clic stick gauche | Maj |
| Tirer : **au sol, en saut ou en vol stationnaire seulement**, jamais en plein vol | RT | clic gauche |
| Viser à l'épaule (aide à la visée) ; **en plein vol, viser = passer en vol stationnaire** | LT | clic droit |
| Mêlée (ruée électrique) | clic stick droit | V ou clic molette |
| Recharger | X | X |
| **Grenade** (fragmentation au départ) | LB | E |
| **Lanceur d'assaut** (missile au poignet au départ) | RB | R |
| Ultime : **batterie de missiles** (jauge pleine, noyau d'origine), puis RT pour chaque salve | LB + RB ensemble, ou croix haut | F |
| Pause tactique : arsenal et destination | Start | Tab |
| En pause : parcourir l'arsenal | croix gauche / droite | flèches gauche / droite |
| En pause : consulter le kit (on change de capacité à la Forge, pas en mission) | croix gauche / droite | flèches |
| Emotes du preset (au sol) | croix gauche / bas / droite | 1 / 2 / 3 |
| **Menu du jeu** (équipement, inventaire, pilote, défis, carte, options ; « Quitter le jeu » dans Options) | Vue (Back) | Échap |

**Le Solaris de récup et ses composants (étapes 5 et 6)** : le jeu commence avec une **épave** côté gameplay : **pas de vol** (le double saut ne donne qu'un petit bond propulsé), pas de dash, marche lourde, bouclier de 25, une grenade seulement (LB) et pas d'ultime. Dix **caisses** sont posées sur Élyra : les grises « Horizon » près du départ (vol court de 5 s, dash, bouclier de 60, grenade et lanceur), les dorées « d'origine » loin ou cachées (vol 14 s, dash enchaîné et mêlée ×1,5, bouclier 110 et vie 130, batterie de missiles et recharges −25 %). Depuis l'étape 6, **une caisse ne change plus la forme du Solaris** : elle monte le composant de gameplay et **débloque** la pièce d'apparence du même ensemble, à choisir ensuite à l'Atelier (propulseurs → torse, blindage → bras, servomoteurs → jambes, noyau → casque ; les deux finitions débloquent un vinyle et deux matériaux). Le panneau « Composants » en haut à gauche suit la reconstruction.

## Le gameplay de l'exo (déplacements et poses)
- **Marche lourde** : à chaque pas la caméra encaisse un peu, le bassin s'enfonce ; il faut un instant pour lancer la masse de l'armure. Le stick à moitié = marche lente.
- **Course** (clic du stick gauche) : ×1,6, la caméra recule et s'ouvre, foulée longue, lignes de vent légères.
- **Saut et réceptions** : petite poussière au saut ; une chute de plus de quelques mètres finit en **réception de super-héros** (genou et poing au sol, onde de choc, cailloux, secousse, bref ralenti pour les grosses chutes).
- **Cachette** : B maintenu près d'un obstacle. Derrière un muret on s'accroupit, derrière un mur haut on reste debout. Les tirs qui viennent de l'autre côté sont arrêtés ; en sortant pour tirer (LT ou RT) on n'est plus protégé qu'à moitié. Six murets et murs sont posés dans le champ de tir d'Élyra.
- **Décollage** : flash, double onde, souffle au sol, la caméra recule pendant la poussée, pose bras tendus vers le bas.
- **Vol** : l'image s'ouvre avec la vitesse, lignes de vent, traînées blanches aux mains au-delà de 17 m/s, le Solaris s'incline dans les virages, la caméra vibre au boost.
- **Vrilles** : B + stick sur le côté, un tonneau complet en 0,5 s qui écarte de ~5 m et esquive tous les tirs (aussi en stationnaire).
- **Vol stationnaire** : face à la visée, posture de combat suspendue (une jambe repliée), souffle au sol quand on plane bas.
- **Poses de combat** : posture de tir jambes écartées en visant à l'arrêt, tir à la hanche fusil remonté, pas chassés en visant.
- **Squelette corrigé** (27 oct, soir) : le modèle Meshy est soudé entre les mains et les cuisses ; ces triangles faisaient des bandes étirées quand les bras bougeaient. `tools/reweight_aegis.py` refait les poids (bras séparés par la distance aux os) et coupe ces 119 triangles ; contrôle visuel : `tests/rig_pose_shots.tscn`. L'armure et la caméra sont interpolées entre deux pas de physique et l'animation tourne à chaque image : plus de saccades sur un écran 120/144 Hz.
- **Marche, trot et course en animations capturées** (27 oct, soir) : les clips idle / walk / run du robot « Xbot » des exemples three.js (rig Mixamo) sont transférés sur les 17 os du Solaris par `tools/bake_anim.gd` → `assets/anim/locomotion.json`. Buste et jambes reprennent les rotations du modèle source ; les bras (en T dans la source) sont alignés par direction. Le jeu mélange repos → marche → course selon la vitesse et cale la cadence sur la distance parcourue ; les poses de tir, de cachette et de vol se posent par-dessus. Au pas normal l'exo trottine à 72 % de la vitesse de ses servos, la course monte à 130 %. Contrôle : `tests/clip_shots.tscn`, vidéo `tests/showcase_walk.tscn`.
- Test automatique : `tests/movement_test.tscn` (course, cachette, tir bloqué, saut du muret, vrille, réception). Vidéo : `tests/showcase_exo.tscn`.

## Les attaques du Ranger (passe 2, 27 oct, nuit)
Le kit est repris du Ranger d'Anthem ; **l'Éveil est abandonné**.
- **Deux armes** : le fusil d'assaut Avant-garde (automatique, 30 coups) en main et le fusil de précision **Twin Vipers** (modèle Meshy de cyril, semi-automatique, 10 coups, 44 dégâts, deux traçantes, gros recul) accroché en diagonale dans le dos. Y au sol : la main droite va chercher l'arme par-dessus l'épaule (0,55 s), l'autre part dans le dos. Chaque arme garde ses munitions.
- **Tir** : au sol, en saut et en vol stationnaire seulement. En plein vol la gâchette ne fait rien (un message le rappelle) ; viser (LT) cale le Solaris en stationnaire. En stationnaire le recul repousse l'armure et fait balancer le buste et les jambes.
- **Recul et douilles** : la caméra et les bras remontent à chaque coup (plus fort aux Twin Vipers), une douille dorée part sur la droite de l'arme et rebondit au sol.
- **Esquive** : vrai bond propulsé (21 m/s qui retombe en 0,34 s, petit décollage, flammes, anneau de poussée), dans la direction du stick ou en arrière.
- **Grenades (LB)** lancées de la main gauche en cloche sur la cible visée : fragmentation (détonateur), givre (gèle 4 s, amorce), incendiaire (flaque de feu, amorce).
- **Lanceurs d'assaut (RB)** : missile au poignet à tête chercheuse (détonateur), rayon d'étincelles (perce, brûle : amorce), salve d'impulsion (boule rapide, détonateur). Amorce puis détonateur = **COMBO**.
- **Ultime, batterie de missiles** : deux lanceurs sortent des épaules, chaque cible dans le cône de visée (jusqu'à 8, à 85 m) reçoit un anneau de verrouillage, RT tire une salve (deux missiles par cible, ou six droit devant sans cible). Trois salves ou 12 s.
- Les **lance-roquettes Quadra Core et le canon Emberstorm** (Meshy) sont gardés pour le mode Colossus (ZIP dans le dossier du projet, pas encore importés).
- Tests : `tests/smoke.tscn` vérifie chaque pouvoir, les combos, le tir interdit en vol, le stationnaire, le changement d'arme, le semi-automatique, l'esquive et la salve. Captures : `tests/weapon_shots.tscn`. Vidéo : `tests/showcase_attaques.tscn`.

## La tenue des armes (28 oct)
- L'arme n'est plus collée à la main : elle est placée là où un soldat la tient (en travers du torse au repos, crosse à l'épaule en visée, devant la poitrine en tir à la hanche), et les deux bras vont la chercher par cinématique inverse : main droite sur la poignée, main gauche sous le canon (`_hold_weapon` dans `scripts/solaris_anim.gd`). Marche et course gardent l'arme à deux mains.
- Changement d'arme (0,9 s) : l'arme passe par-dessus l'épaule jusqu'à sa place dans le dos, la main attrape l'autre arme et la ramène devant. Chaque arme a sa place dans le dos (`holster_xf` dans `combat.gd`).
- Le point sous le canon où va la main gauche est réglé par arme (`fore` dans `WEAPONS`).
- Une main seulement en vol, en mêlée, au lancer de grenade et pendant les emotes.
- Vidéo de contrôle : `tests/showcase_armes.tscn` ; gros plans : `tests/hold_shots.tscn`.

## Nouvelles armes du butin (29 oct)
Sept fusils Meshy de cyril s'ajoutent à l'Avant-garde et aux Twin Vipers. Ils tombent comme butin (ennemis, caisses, fin de mission) et s'équipent à la Forge, onglet ARSENAL. **L'arme tenue en main et celle du dos sont celles de l'objet équipé**, avec leurs propres stats.

| Arme 1 (fusils d'assaut) | Style |
|---|---|
| **Tacticien** | polyvalent, un peu plus fort que l'Avant-garde (13 dégâts, 28 coups) |
| **Vigile** | léger et précis, 34 coups, porte plus loin (id `ivoire` gardé pour les sauvegardes) |
| **Minuit** | lourd : cadence lente, 19 dégâts, 40 coups, rechargement long |
| **Répétiteur** | très rapide, 7 dégâts, 45 coups |

| Arme 2 (fusils de précision) | Style |
|---|---|
| **Sentinelle arctique** | coup par coup, 58 dégâts, très longue portée (180 m) |
| **Silencieux** | semi-automatique rapide (30 dégâts, 14 coups), tir discret |
| **Titan** | très lent, 80 dégâts, 6 coups, gros recul |

- Chaque arme a un nom de chef-d'œuvre et de légendaire (ex. « Nuit de Khar », « Colère du Titan ») et une vignette 3D.
- Les noms et descriptions sont dans `data/loot/items.json` ; les stats et les points de tenue (`muzzle`, `fore`) dans `WEAPON_MODELS` de `scripts/combat.gd`.
- **Couleurs (29 oct, après-midi)** : toutes les armes, Avant-garde et Twin Vipers comprises, gardent leurs **textures Meshy d'origine** (couleur, métal, rugosité, relief) au lieu d'être repeintes par le preset (`shaders/weapon_meshy.gdshader`). Seules les lumières suivent la couleur **Énergie** (zone 6) : traçantes, flamme de bouche, et les détails lumineux peints dans la texture quand il y en a (les braises orange du Minuit, clé `lights`). Les pièces d'armure, elles, sont toujours repeintes.
- **Rareté sur l'arme** : liseré lumineux discret sur les bords (violet Épique, orange Chef-d'œuvre, or Légendaire, rien en dessous), sur l'arme tenue et dans le dos, et sur le modèle 3D qui tourne dans la fiche d'objet (Forge, menu).
- Le Tacticien et le Minuit sont réduits de 13 % (ils dépassaient trop devant le Solaris) ; l'ancien « Ivoire » s'appelle désormais **Vigile**.
- Fabrication : `tools/meshy_armes.py` (Blender : décimation ~25 000 triangles, textures 1024 px, origine à la poignée), puis `tools/weapon_res.tscn` (maillages `assets/weapons/<id>.res`) et `tools/weapon_icons.tscn` (vignettes). Les 17 ZIP Meshy du 29 oct sont rangés dans `meshy_armes_29oct/` (les canons et lanceurs non utilisés y attendent).
- Captures : `tests/armes_29oct_shots.tscn` (Solaris en visée avec chaque arme) et `tests/armes_29oct_forge.tscn` (Forge) → `videos/armes_29oct/` ; couleurs et liserés : `tests/couleurs_armes_shots.tscn` et `tests/couleurs_armes_forge.tscn` → `videos/armes_29oct/couleurs/` (les `*_avant_*` montrent l'ancienne taille du Tacticien et du Minuit).

## Les effets d'attaque (passe « effets », 28 oct)
- **Tirs** : la balle file réellement (courte traînée lumineuse à ~400 m/s) et l'impact apparaît à son arrivée. Éclair de bouche en étoile + flamme de côté + fumée, douilles qui tintent au sol.
- **Impacts selon la surface** : terre (poussière, mottes, trou), pierre (poussière grise, éclats, étincelles, trou), métal des cibles (gerbe d'étincelles, tintement, ricochets). Les trous et brûlures restent quelques secondes (70 au plus).
- **Explosions** : flash, boule de feu animée, onde de choc, gerbe, débris, poussière soufflée au sol, colonne de fumée noire qui monte, brûlure au sol.
- **Missiles** : flamme de tuyère qui vacille, traînée de fumée blanche qui reste dans l'air.
- **Givre** : brume glacée qui roule au sol, éclats de glace. **Brasier** : vraies flammes animées et fumée noire.
- **Sons** : fusil, Twin Vipers, explosions (grandes et petites), missiles, impacts, ricochets, douilles, rayon. Plusieurs variantes, hauteur au hasard.
- Tout est fabriqué par `tools/gen_fx.py` (textures `assets/fx/`, sons `assets/sfx/`) : aucun fichier extérieur. Pour retoucher un son ou une texture, modifier le script et le relancer (`python3 tools/gen_fx.py`).
- Banc d'essai des effets : `tests/fx_lab.tscn` (fond neutre) et `tests/fx_shots.tscn` (dans le champ de tir).

## L'Atelier et la Forge (étape 6)
Sur la carte de la **Terre**, marche dans l'anneau doré au pied de la rampe de l'Aster : on entre dans l'Atelier. On peut aussi ouvrir `scenes/atelier.tscn` et appuyer sur **F6** : tout y est débloqué pour tester, mais rien n'est sauvegardé. Règle de base : **l'apparence ne change jamais une stat**, les stats viennent uniquement de l'onglet Équipement (un test automatique le vérifie).

L'écran suit l'image de référence « FORGE RANGER » : 4 onglets en haut, une colonne à gauche, une à droite, le Solaris au centre sur son socle, la barre d'équipement (principale, secondaire, grenade, module, mêlée, ultime) et les statistiques (mobilité, protection, énergie, poids) en bas. Chaque ligne est une bande de vignettes rendues en 3D.

| Onglet (LB / RB) | Colonne gauche | Colonne droite |
|---|---|---|
| ÉQUIPEMENT | Composants (propulseurs, servomoteurs, blindage, noyau) | Grenade (LB) et lanceur d'assaut (RB), 6 loadouts |
| APPARENCE | Pièces : casque, torse, bras, jambes (avec compteurs), ensembles | Zone, couleurs, matériaux (sphères), **curseur d'usure** et type d'usure, marquages et emplacement, préréglages |
| MODES | Ranger (actif), Colossus, Storm, Interceptor (verrouillés). On ne change de mode qu'ici. | Animations : arrivée, victoire, 3 emotes |
| PRÉRÉGLAGES | 10 presets d'apparence | 6 loadouts d'équipement |

**Décor de la Forge (29 oct)** : l'intérieur de la Forge d'après la maquette v2 (`maquette_forge/maquette_forge_v2_2.png`) remplace l'ancien hangar (cylindres bruns, caisses bleues). Halle en pierre calcaire et charpente en fer, verrière par où entrent des rais de soleil doré dans l'air poussiéreux, rosace, grande porte ouverte sur le jour. Le Solaris reste à sa place, sur un socle rond à gradins cerclé d'anneaux bleus, sous le grand anneau de maintenance (carters arrondis, bandes émettrices bleues, rayon de lumière douce). Deux bras robots en acier gris aux capots orange, postes de travail aux écrans holographiques, râteliers, caisses, câbles pendants, suspensions chaudes et appliques, bannières rouge et blanc / bleu marine à l'emblème ailé, lierre, et un second berceau en partie visible sur le côté. Le flou de profondeur et le cadrage / la rotation / le zoom de la caméra n'ont pas changé.
- Construit dans Godot (pas d'export de la maquette Blender) : `scenes/forge/forge_decor.tscn` (`scripts/forge/forge_decor.gd`, avec l'éclairage et l'environnement). Chaque accessoire est une scène à part, facile à remplacer par un modèle Meshy : `robot_arm`, `cradle_ring`, `workstation`, `tool_rack`, `crates`, `lantern` dans `scenes/forge/` (garder le nœud `Tourelle/Pointe` du bras soudeur pour les étincelles). Matériaux partagés : `scripts/forge/forge_kit.gd`, textures Poly Haven (CC0) en 1024 px dans `assets/forge/tex/`.
- Captures et images par seconde : `tests/forge_decor_shots.tscn` → `videos/forge_decor/`. Sauvegarde de l'ancien décor : `sauvegardes_forge_decor/`.

Commandes : **LB / RB** onglets, **LT / RT** colonne gauche / droite, haut / bas (stick gauche ou croix) changer de ligne, **gauche / droite essayer en direct**, **A** valider, **X** action de la ligne (enregistrer un preset ou un loadout, jouer une animation), **Start** sauvegarder le preset porté, **Vue** copier puis coller une couleur, **B** quitter, stick droit tourner et zoomer, clic du stick droit remettre de face. Clavier : flèches, Entrée, Échap, Page préc. / Page suiv. (onglets), Tab (colonne), X, S, C / V. Souris : clic sur une vignette ou sur le curseur, glisser pour tourner, molette pour zoomer.

### Le Solaris : corps Aegis et pièces Meshy

Le Solaris est refait à partir du modèle Meshy **Aegis Sentinel** de cyril (`assets/solaris/aegis_rig.glb`, ~54 000 sommets). Il est rigué avec les mêmes 17 os que l'ancien Solaris (`tools/rig_aegis.py`), donc toutes les animations marchent pareil. Les formes simples que j'avais ajoutées (ailes, plaques, boîtes) sont retirées. Le corps se repeint selon le preset : les parties orange prennent la couleur Principale, les blanches la Secondaire, les noires la Structure et les lumières l'Énergie.

Pièces portables par-dessus (Forge > Apparence) :
- **Exo Ranger** : les bras gauche et droit Meshy (`assets/pieces/exo/`), un modèle par côté, coupés en 3 (bras, avant-bras, main) pour plier au coude et au poignet. Preset « Aegis bras Exo ».
- **Mech orange** : casque, torse, bras et jambes Meshy (`assets/pieces/mech/`). Preset « Mech orange ».
- Récup, Horizon et Originel attendent leurs pièces Meshy.
- **Pièces du 29 oct (soir)** : 7 torses (Sentinelle de braise, Sentinelle de braise II, Avant-garde de braise, Sentinelle orange, Titan orange, Avant-garde Titan, Plastron Titan) et 2 bras (Gantelet du Tigre, Griffe de braise). Débloqués d'office (`Appearance.TEST_PIECES`). Captures : `videos/nouvelles_pieces/` (`tests/nouvelles_pieces_shots.tscn`). ZIP d'origine : `meshy_pieces_29oct/` (torses) et `meshy_armes_29oct/` (bras).
- **Plus de « pantin désarticulé »** (29 oct) : chaque pièce Meshy est maintenant **habillée sur le squelette** comme le corps. `tools/skin_pieces.tscn` soude ses morceaux en un seul maillage et donne à chaque sommet les poids du corps Aegis juste en dessous (point le plus proche, limité aux os du membre) : l'armure plie au genou, au coude, à l'épaule comme le corps, sans trou entre les morceaux. Le corps n'est plus caché par des ellipsoïdes : il est masqué **sommet par sommet**, seulement là où l'armure est devant lui (ou juste dessous quand il dépasse), donc jamais de trou ailleurs. Avant/après : `videos/pieces_avant_apres/` (`tests/pieces_shots.tscn`). Le casque Mech est un peu agrandi, le pied Mech allongé pour couvrir le pied du corps.
- **Casque Sentinelle de braise** (31 oct) : 7e casque Meshy (`ranger.casque_braise`, fichiers `assets/pieces/casques/casque_ember*`), débloqué d'office. ZIP : `meshy_pieces_29oct/Meshy_AI_Ember_Sentinel_Helmet_20261029_texture_fbx.zip`. Gros plan : `videos/nouvelles_pieces/casque_braise_tete.png` (`CAS=casque_braise`). Sauvegarde : `sauvegardes_casque_ember/`.
- **Essai tourelle Hunyuan3D** (31 oct) : `scenes/essais/test_tourelle.tscn` (plateau tournant dans la Forge, touches 1-6 pour 6 jeux de couleurs, Espace / +/- pour la rotation). Modèle nettoyé : `assets/essais/tourelle_hunyuan/`. Captures : `videos/essai_tourelle/` (lancer avec `-- capture`).
- **Ajouter une pièce** : (1) Blender `tools/meshy_pieces.py` (décimation, textures 1024 px, `.glb` ; un bras plié est redressé et coupé en 3 avec les points épaule/coude/poignet/doigts de `BRAS`) ; (2) une entrée dans `Catalog.mesh_def` (`MESHY_29OCT` pour un torse, `_limb` pour un bras) et dans `Catalog.SKINNED` ; (3) Godot `tools/skin_pieces.tscn` (ou `PIECE=<id>` pour une seule). Sans fichier habillé, la pièce retombe sur l'ancien mode rigide.

**Armes Meshy** (`assets/weapons/`) : le fusil « Orange Vanguard » est tenu dans la main droite, bas au repos et épaulé en visée (les deux mains). Les Twin Vipers sont accrochées dans le dos. La grenade « Ember Core » sert pour les trois grenades et reprend les couleurs du preset ; les armes gardent leurs textures d'origine (voir « Nouvelles armes du butin »).

Les lumières de l'arme, les flammes, les traînées, les traçantes et les missiles reprennent les couleurs du preset (zone 6 = énergie). L'animation d'arrivée se joue en début de carte et en sortant de l'Atelier, la pose de victoire quand une borne est sécurisée. Les presets et les pièces débloquées sont sauvegardés dans `user://apparence.json` (dossier de données de Godot) ; les composants de gameplay repartent de l'épave à chaque partie sur Élyra.

**L'arsenal (étape 5)** : remplacé le 27 octobre par le kit du Ranger : trois grenades en LB, trois lanceurs d'assaut en RB, à changer dans la pause tactique ou à la Forge. En pause, les cartes montrent le rôle et le temps de recharge de chaque pouvoir.

**Les ennemis (étape 4)** : une borne rouge près du départ (Élyra et Varda) lance trois vagues quand on s'en approche. Trois types : le **soldat** (tire en rafales de trois, garde ses distances, se décale), le **drone** (tourne autour en l'air, tire, et fonce sur toi toutes les 5 s), la **brute** (320 de vie, charge après une préparation rouge, frappe au corps à corps). Ils te repèrent à vue et te perdent après quelques secondes hors de vue. Points faibles : la tête du soldat, l'œil du drone, le noyau orange dans le dos de la brute (dégâts ×2, « CRITIQUE »). La grenade de givre les gèle, les combos et la batterie de missiles marchent sur eux comme sur les cibles. Zone sécurisée après la 3e vague, puis les vagues reviennent 25 s plus tard.

**Les pouvoirs et combos (étape 3)** : remplacés par le kit du Ranger (voir « Les attaques du Ranger » plus haut). Le principe reste : une **amorce** marque la cible (brûlée, gelée), un **détonateur** la fait exploser (70 de dégâts, moitié pour les voisines) et le jeu affiche COMBO ; la mêlée détone aussi.

**Le combat (étape 2)** : fusil à impulsion (30 coups, rechargement 1,5 s, 11 de dégâts), visée à l'épaule qui rapproche la caméra et aide à viser la cible la plus proche du réticule (réticule rouge), mêlée en ruée (45 de dégâts), bouclier de 60 qui se régénère après 3,5 s sans dégâts, vie de 100. Un dash esquive les tirs. Des cibles d'entraînement attendent devant le départ d'Élyra et sur Varda : mannequins, drones en vol et une tourelle qui riposte. Elles réapparaissent quelques secondes après leur destruction. À 0 de vie, l'armure se coupe 3 s et se réactive au dernier sol sûr.

**Le vol, façon Anthem** : en vol on avance toujours ; la caméra donne la direction, stick droit vers le haut pour monter, vers le bas pour piquer. Monter chauffe vite, piquer refroidit, le vol stationnaire chauffe lentement. Traverser la cascade d'Élyra ou se poser dans l'eau refroidit d'un coup. À 100 % de chaleur, les propulseurs se coupent 3 s et on tombe. Un atterrissage à pleine vitesse finit en glissade.

En pause tactique, un clic sur le sol fixe une destination : le Solaris s'y rend seul à la reprise.

## Test de décor : la clairière de l'Arche (Élyra)
Scène à part, pour juger l'ambiance d'un vrai décor : `scenes/elyra_clairiere.tscn`. Dans Godot, double-cliquer sur ce fichier dans le panneau *Système de fichiers* puis appuyer sur **F6** (lancer la scène courante). Le Solaris y est complet (vol débloqué). Terrain sculpté, falaises, forêt géante bioluminescente, Arche, sanctuaire sous les racines, cascade et bassin, brume et lueurs. Sur le PC (rendu Forward+) s'ajoutent la brume volumétrique et l'occlusion ambiante, absentes de la vidéo rendue côté serveur.

## La carte de la Terre (vallée d'Horizon)
Scène `scenes/terre.tscn` (double-clic dans le panneau *Système de fichiers*, puis **F6**). La maison du jeu : la vallée minière sous la pluie, la base Horizon creusée dans le flanc est (hangar, modules, tour, portail de la galerie), l'Aster posé sur son aire, la mine à ciel ouvert et son chevalement, le lac au sud, la première Arche au fond de la vallée sous ses échafaudages, et l'équipage sur l'esplanade (Ilse Varga, Teo Marchetti, Nadia Okafor, Sann, l'escouade en Bastion et Zéphyr). Le Solaris y est complet pour explorer en vol. Les éléments sont des formes simples à remplacer par des modèles Meshy.

## Le Solaris riggé et animé
Le modèle `assets/solaris/solaris_rig.glb` porte un squelette de 17 os (hanches, colonne, buste, cou, tête, bras ×3, jambes ×3 de chaque côté) et des poids de peau calculés par le script `tools/rig_solaris.py` (pas d'outil externe, le découpage est fait par zones avec des fondus aux articulations). Les animations sont procédurales dans `scripts/solaris_anim.gd` : repos (respiration), marche et course (cycle calé sur la vitesse), dash, saut, chute, réception, vol, dash en vol, vol stationnaire, mêlée, visée et recul du tir, lancement de pouvoir, piqué météore, mort. Elles se déclenchent toutes seules selon l'état du joueur. Démo : `tests/showcase_rig.tscn`. Un vrai modèle riggé (Meshy) pourra remplacer ce squelette à condition de garder les mêmes noms d'os.

## Dossiers
- `scenes/main.tscn` : la scène unique (monde, joueur, HUD, pause).
- `scripts/maps.gd` : les cartes (grille de caractères, palette, ciel, Arche, balises). Pour ajouter un monde : une fonction de plus et une entrée dans `by_id`.
- `scripts/world.gd` : construit une carte (dalles, rampe, rochers, props, balises, Arche, cibles d'entraînement).
- `scripts/game.gd` : racine, change de carte quand on traverse l'Arche (fondu au noir).
- `scripts/player.gd` : déplacement, vol, chaleur, caméra.
- `scripts/solaris_anim.gd` : poses et cycles du squelette du Solaris. `tools/rig_solaris.py` : génère `solaris_rig.glb` depuis `solaris.glb`.
- `scripts/combat.gd` : arme, visée, mêlée, vie et bouclier (nœud créé sous le joueur).
- `scripts/target.gd`, `scripts/turret_shot.gd` : cibles d'entraînement et projectile (tourelle, soldats, drones).
- `scripts/enemy.gd`, `scripts/arena.gd` : les trois ennemis et les vagues lancées par la borne.
- `scripts/loadout.gd` : le gameplay (autoload « Loadout ») : 4 composants × 3 niveaux, pouvoirs équipés, 6 loadouts.
- `scripts/appearance.gd` : l'apparence (autoload « Appearance ») : look porté, 10 presets, pièces débloquées, sauvegarde. Aucune stat.
- `scripts/catalog.gd` : données de personnalisation (modes, ensembles, géométrie des 16 pièces, matériaux, usures, vinyles, animations, nuancier). `data/catalogue-armures.json` : les 77 ensembles du document de conception.
- `scripts/solaris_look.gd` : pose les pièces sur les os, peint les 6 zones, l'usure et le vinyle, repeint l'arme. `shaders/exosuit.gdshader` : le matériau commun (couleur, type, usure). `scripts/vinyl_art.gd` : les vinyles dessinés par code.
- `scripts/atelier.gd`, `scenes/atelier.tscn` : l'Atelier et la Forge. Tests : `tests/forge_test.tscn` (Forge), `tests/smoke.tscn` (jeu, dont la séparation apparence / gameplay), démo `tests/showcase_forge.tscn` (Forge et Solaris Aegis), captures `tests/mech_shots.tscn` (LOOK_PRESET=nom du preset), `tests/weapon_shots.tscn` (fusil et grenade), `tests/forge_ui_shots.tscn`, `tests/helmet_shots.tscn`. Vignettes : `scripts/forge_thumbs.gd`. Shaders : `shaders/exosuit.gdshader` (zones), `shaders/meshy_piece.gdshader` (pièces Meshy repeintes), `shaders/wear.gdshaderinc` (usure commune).
- `scripts/part_crate.gd`, `scripts/fire_zone.gd`, `scripts/missile.gd` : caisses de pièces, flaque de feu de la grenade incendiaire, missiles à tête chercheuse (poignet, impulsion, batterie).
- `scripts/fx.gd` : boîte à effets (particules, flashs, anneaux, secousses, ralenti), autoload « Fx ».
- `scripts/hud.gd`, `scripts/tactical_pause.gd` : interface.
- `scripts/decor_base.gd` : outils communs des décors construits par code (terrain par fonction de hauteur, matériaux, eau, Arche).
- `scripts/clairiere.gd`, `scenes/elyra_clairiere.tscn` : le test de décor (clairière de l'Arche). `scripts/terre.gd`, `scenes/terre.tscn` : la carte de la Terre. `scenes/player.tscn` : le Solaris seul, réutilisable dans d'autres scènes.
- `scripts/input_setup.gd` : touches et boutons de manette.
- `assets/solaris/` : modèle allégé (150 000 triangles) et textures.

## Ressenti façon Anthem (caméra, vitesse, enchaînements)
- Caméra à l'épaule : près du dos, le Solaris sur le tiers gauche ; en visée elle se colle à l'épaule droite (player.gd, `_camera_step`). Elle recule et se recentre seulement en vol.
- Flou de vitesse sur les bords (shaders/speed_blur.gdshader) en course, esquive, vrille, décollage et boost. En mode Compatibilité (OpenGL) il est coupé si le halo (glow) est actif, car l'image copiée y est vide ; sur PC (Forward+) les deux marchent ensemble.
- Vol rasant : près du sol ou de l'eau, l'exo glisse à ~2 m au lieu de se poser (gerbes d'eau), sauf piqué franc.
- Réception coupée dès qu'on vise, tire ou court : on enchaîne atterrissage et tir.
- Chaque balle : petit coup de zoom en plus du recul.
- Vidéo : tests/showcase_ressenti.tscn

## Butin, progression et stats d'équipement (étape 7, 28 oct)
- **En mission** (Élyra, lancé avec F5) : les ennemis et les caisses lâchent des **diamants** à la couleur de leur rareté (blanc Commun, vert Peu commun, bleu Rare, violet Épique, orange Chef-d'œuvre, or Légendaire), avec une colonne de lumière d'autant plus haute que l'objet est rare. On les ramasse en passant ; à droite de l'écran ne s'affiche que la rareté. En haut à droite : niveau pilote, barre d'XP (la partie dorée = XP gagnée pendant la mission) et nombre de butins dans le sac.
- **Fin de mission** (les 3 vagues du champ de tir terminées) : écran « Mission accomplie » avec l'XP (ennemis, caisses, mission), la barre de niveau et ce que chaque niveau débloque, puis les objets révélés un par un, du moins rare au plus rare (éclat doré pour le légendaire). **A** : passer / continuer ; **Y** (ou F) : aller directement à la Forge.
- **Butin corrigé** : chaque mission favorise un type d'objet (Élyra = armes, Varda = composants) et un **légendaire est garanti** après 8 missions d'affilée sans or (compteur affiché sur l'écran de fin).
- **Niveau pilote** (1 à 30) = grand tutoriel : niv. 2 propulseurs Horizon (le Solaris vole), niv. 3 esquive + lanceur d'assaut RB + 3e composant, niv. 4 blindage Horizon, niv. 5 Ailes solaires + 4e composant, niv. 6 difficulté Difficile, niv. 7 servos d'Originel + 5e composant, niv. 8 blindage ivoire, niv. 10 ultime + 6e composant, niv. 15 / 20 / 25 Grand Maître 1 / 2 / 3. Les caisses ne montent plus de composant : elles donnent du butin (et débloquent toujours la pièce d'apparence, récompense d'exploration).
- **Objets** : 6 raretés, puissance, 0 à 4 inscriptions (locales = l'objet seul, globales = tout l'exo), effet spécial pour chef-d'œuvre et légendaire (renforcé ×1,5). Deux exemplaires du même objet n'ont pas les mêmes inscriptions. Emplacements : Arme 1 (fusils d'assaut), Arme 2 (fusils de précision), grenade LB, lanceur RB, 6 composants. Mêlée et ultime restent fixes (pas de loot). Le soutien viendra plus tard.
- **Forge** : nouveaux onglets ARSENAL (armes et capacités), COMPOSANTS, RECYCLAGE et SYSTÈMES (les 4 systèmes du Solaris, la difficulté, les loadouts). Gauche / droite : parcourir (trié par puissance) ; à droite, la fiche de l'objet comparée à l'objet équipé (vert = mieux, rouge = moins bien, alerte si on perd une amorce ou un détonateur, puissance de l'exo avant → après). **A** équiper, **X** verrouiller. Recyclage : A deux fois sur un objet, ou en lot (« tous les Communs »). Matériaux : Alliage d'Arche, Cristal de porte, Fragments de Veilleur, Éclats de l'Architecte. Plans et fabrication : plus tard. Les loadouts retiennent aussi les objets équipés.
- **Difficulté** (onglet SYSTÈMES) : Facile, Normal, Difficile, Grand Maître 1-3 ; la vie des ennemis, l'XP et la rareté du butin montent avec.
- **L'apparence ne change jamais les stats** : seul `BuildStats` calcule les stats, à partir de l'équipement (test automatique).
- Sauvegarde : `user://progression.json` (niveau, XP, objets, matériaux, difficulté, loadouts). Forge lancée seule (F6) : arsenal de démonstration, rien n'est sauvegardé.
- Données à équilibrer sans toucher au code : `data/loot/items.json` (objets, raretés, noms), `data/loot/affixes.json` (inscriptions, effets), `data/loot/tables.json` (difficultés, missions, chances de drop, XP, recyclage, niveaux pilote).
- Code : `scripts/loot/` (autoloads Inventory, BuildStats, Progression, Expedition ; LootDB, LootRoll, LootDrop, LootUI, debrief.gd). Test : `tests/loot_test.tscn` (sans écran). Vidéo : `tests/showcase_loot.tscn`.

## Menu du jeu (28 oct)
- **Bouton Vue (les deux carrés) ou Échap**, partout où l'on pilote le Solaris (Terre, expéditions) : le jeu se fige et le menu s'ouvre, dans le style de la Forge. **B** ou Vue pour revenir au jeu. **LB / RB** (E / R) changent d'onglet.
- Comme dans Anthem, **on y consulte, on n'y équipe pas** : l'équipement se change à la Forge de l'Atelier (anneau doré au pied de l'Aster, ou Y depuis l'écran de fin de mission). Start reste la pause tactique, qui ne change plus les capacités non plus.
- **ÉQUIPEMENT** : les 10 emplacements (armes, capacités, composants, avec les emplacements encore verrouillés et leur niveau), la puissance de l'exo, tous les bonus globaux, les 4 systèmes du Solaris, la fiche de l'objet sous le curseur.
- **INVENTAIRE** : tout le butin trié par type et puissance, filtres TOUT / ARMES / CAPACITÉS / COMPOSANTS (gauche / droite), fiche comparée à l'objet équipé, matériaux, nombre d'objets par rareté. **X** verrouille, **Y** (C au clavier) **marque « à recycler »** ; à la Forge, RECYCLAGE > « Les marqués » recycle tout ce qui est marqué.
- **PILOTE** : niveau, XP, difficulté, garantie de légendaire, systèmes du Solaris, et la liste des déblocages par niveau (faits, prochain, à venir).
- **DÉFIS** : 9 défis avec barre de progression (expéditions, ennemis, caisses, recyclage, chefs-d'œuvre, légendaire, niveau pilote). Récompense actuelle : de l'XP pilote, versée une fois, avec un message en jeu. Les défis se règlent dans `data/loot/tables.json` (« challenges »).
- **CARTE** : le relevé de la planète (Élyra, Varda) avec le Solaris, les balises, l'Arche et le champ de tir. Sur Terre : pas encore de carte.
- **OPTIONS** : volume général, plein écran (gardés dans `user://options.json`), reprendre, quitter le jeu (A deux fois, la progression est sauvegardée).
- **Capacités en 3D** (modèles Meshy de cyril, 28 oct) : les 6 capacités (grenades fragmentation, givre, incendiaire ; missile au poignet, émetteur de rayon, canon à impulsion) ont leur vignette rendue en 3D dans la Forge, le menu et l'écran de fin, et leur modèle qui tourne sur la fiche de l'objet. La grenade équipée apparaît dans la main et en vol. Fichiers : `assets/loot/<id>.glb` et `assets/loot/icons/<id>.png`, produits par `tools/meshy_loot.py` (Blender : allègement à ~20 000 triangles, textures 1024 px). Une version travaillée `<id>_m` (chef-d'œuvre) ou `<id>_l` (légendaire) sera prise automatiquement quand elle existera.
- Code : `scripts/menu/game_menu.gd` (autoload GameMenu). Test : `tests/menu_test.tscn` (sans écran). Vidéo : `tests/showcase_menu.tscn`.

## Kit du Ranger lisible (amorces, combos) et effets Blender
- Amorces visibles sur les cibles (scripts/status_fx.gd) : carapace de glace + brume (gel), flammes + braises (feu), arcs électriques (choc), étiquette « AMORCÉ · GEL / FEU / CHOC ».
- Combo selon l'amorce (combat.gd, `_detonate`) : ÉCLAT DE GLACE (ralentit les voisins), EMBRASEMENT (les voisins prennent feu), FOUDROIEMENT. Le nom s'affiche au centre de l'écran.
- La grenade apparaît dans la main gauche et part au sommet du lancer (0,22 s) ; missile, rayon et impulsion partent bras tendu (0,12 s).
- Fumée et feu rendus en volumes 3D dans Blender : tools/blender_fx.py (bpy 5.2 en module Python, voir l'en-tête), remplace smoke_sheet.png et fire_sheet.png de gen_fx.py. Avant/après : effets-blender-avant-apres.png.
- Vidéo : tests/showcase_kit.tscn

## Cinématique « montagne » (Solaris dans la vallée)

Scène `scenes/cinematique_montagne.tscn` : double-cliquer dessus dans le panneau *Système de fichiers*, puis **F6**. 30 s : arrivée en vol, atterrissage près du lac, marche, regard vers les montagnes, tir final. **Espace** rejoue, **Échap** quitte. Le Solaris est celui du jeu (`aegis_rig.glb`, avec la peinture de l'Atelier) ; l'animation, la caméra et les accessoires viennent de la version Blender (`assets/cinematique/montagne.json`), les arbres et rochers sont posés en MultiMesh, la poussière d'atterrissage vient de `Fx`.
- Refaire l'export depuis Blender : `blender -b travail_claude/cinematique_montagne.blend -P tools/exporter_cinematique_montagne.py`.
- Vidéo : `godot --path . --write-movie out.avi --fixed-fps 24 res://scenes/cinematique_montagne.tscn` (la fenêtre Godot doit rester affichée pendant l'enregistrement).
- Version Blender rendue : `travail_claude/solaris_cinematique_montagne.mp4`.