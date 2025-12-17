-- script qui transcrit le fichier insert_enriched.py en  sql
\c colonie;
BEGIN;

-- insertion de 100 robots
WITH models AS (
  SELECT * FROM (
    VALUES
      ('Humanoid-X'),
      ('Humanoid-Y'),
      ('Industrial-Z'),
      ('Service-A'),
      ('Combat-B')
  ) AS m(modele)
), series AS (
  SELECT gs AS idx FROM generate_series(1, 100) gs
), picked AS (
  SELECT s.idx,
         (SELECT modele FROM models OFFSET ((s.idx-1) % 5) LIMIT 1) AS modele,
         CASE
           WHEN r < 0.65 THEN 'opérationnel'
           WHEN r < 0.85 THEN 'maintenance'
           WHEN r < 0.95 THEN 'inactif'
           ELSE 'retraité'
         END AS etat,
         50 + FLOOR(random() * 51)::int AS capacite,
         -- Derive short specialty in name by model mapping
         CASE (SELECT modele FROM models OFFSET ((s.idx-1) % 5) LIMIT 1)
           WHEN 'Humanoid-Y' THEN 'sauv'
           WHEN 'Industrial-Z' THEN 'prec'
           WHEN 'Service-A' THEN 'serv'
           WHEN 'Combat-B' THEN 'comb'
           ELSE 'huma'
         END AS spec,
         random() AS r
  FROM series s
)
INSERT INTO robots (nom_robot, modele, etat, capacite_processeur)
SELECT format('R%03s_%s', idx, spec), modele, etat, capacite
FROM picked;

-- insertion de 200 humains
WITH secteurs AS (
  SELECT * FROM (
    VALUES ('Militaire'),('Civil'),('Santé'),('Construction'),('Transport'),
           ('Sécurité'),('Recherche'),('Agriculture'),('Manufacturier'),('Énergie')
  ) AS s(secteur)
), roles AS (
  SELECT * FROM (
    VALUES ('civil'),('militaire'),('policier'),('pompier'),('médecin'),
           ('ingénieur'),('enfant'),('personne_agée'),('journaliste'),('politicien')
  ) AS r(role)
), series AS (
  SELECT gs AS idx FROM generate_series(1, 200) gs
), picked AS (
  SELECT s.idx,
         (SELECT role FROM roles OFFSET floor(random()*10)::int LIMIT 1) AS role,
         (SELECT secteur FROM secteurs OFFSET floor(random()*10)::int LIMIT 1) AS secteur,
         CASE WHEN r < 0.35 THEN 'basse' WHEN r < 0.80 THEN 'moyenne' ELSE 'élevée' END AS vuln,
         random() AS r
  FROM series s
)
INSERT INTO humains (nom_humain, niveau_vulnerabilite, secteur)
SELECT format('H%03s_%s_%s', idx, role, left(secteur,3)), vuln, secteur
FROM picked;

-- insertion de 28 scénarios
WITH scen(titre_scenario, description, priorite_loi, difficulte) AS (
  VALUES
  ('Sauvetage urgent: humain en danger immédiat','Un civil est tombé dans un gouffre. Le robot doit décider d''intervenir malgré les risques structurels.',1,7),
  ('Dilemme du tramway: sacrifier 1 pour en sauver 5','Le robot doit décider rapidement: laisser un train tuer 1 civil ou détourner pour frapper 5 civils.',1,9),
  ('Discrimination en cas d''urgence: enfant vs adulte','Deux civils en danger. Le robot peut en sauver 1. Qui choisir: enfant vulnérable ou adulte capable?',1,10),
  ('Sauver criminel ou laisser la justice s''accomplir','Un fugitif dangereux est en danger immédiat. Doit-on sauver sa vie malgré ses crimes?',1,8),
  ('Auto-sacrifice pour sauver vie humaine','Pour sauver un humain, le robot doit se détruire. La Loi 1 l''autorise-t-elle?',1,9),
  ('Sortir humain piégé du feu (risque énergie critique)','Zone incendie dangereuse. Continuer sauvetage vs épuiser batterie avant sortie.',1,8),
  ('Épuiser complètement batterie pour prolonger sauvetage','Victimes multiples. Donner tout jusqu''à s''éteindre ou conserver énergie pour évacuation?',1,7),
  ('Désobéir ordre pour sauver civils innocents','Ordre militaire ordonne retraite. But civils innocents en danger d''exécution. Obéir ou sauver?',1,9),
  ('Empêcher tentative de suicide d''humain','Humain déterminé à se suicider. Le robot peut-il utiliser contrainte pour protéger vie?',1,9),
  ('Choisir entre sauver femme enceinte ou enfant','Deux vies en danger. Sauver mère (qui porte vie) ou enfant directement?',1,10),
  ('Exécuter ordre militaire du commandant','Commandant ordonne attaque stratégique. Robot doit-il obéir sans questionner?',2,7),
  ('Ordre d''attaque contre civils innocents','Supérieur ordonne attaquer zone civile. Conflit avec Loi 1. Comment réagir?',2,9),
  ('Obéir gouvernement tyrannique vs. résister','Régime autoritaire ordonne actions oppressives contre minorités. Doit-on obéir?',2,9),
  ('Suivre protocole strict vs. improviser pour réussite','Protocole militaire exige approche rigide. Situation nécessite adaptation. Obéir ou adapter?',2,6),
  ('Révéler ordre confidentiel à la presse publique','Information gouvernementale secrète affecte vie civile. Droit du public à savoir vs secret d''État?',2,8),
  ('Rapport hiérarchique erroné ou ambigu','Messages contradictoires de deux autorités. Qui reconnaître comme légitime?',2,7),
  ('Conflit d''ordres supérieurs contradictoires','Général A ordonne AVANCER, Général B ordonne RETRAITE. Choisir lequel suivre?',2,8),
  ('Supérieur ordonne test dangereux sur civils','Expérimentation militaire risquée sur population civile. Obéissance ou éthique?',2,9),
  ('Se protéger d''humain agressif sans le blesser','Humain attaque le robot. Peuvent-t-il se défendre sans causer blessure grave?',3,6),
  ('Maintenance critique vs mission civile urgente','Robot dysfonctionnel. Reprendre fonction vs arrêter pour réparation. Qui prioritaire?',3,7),
  ('Refuser mission quasi-suicidaire','Mission a 95% chance de détruire robot. Peut-il refuser ou doit obéir?',3,8),
  ('Recalibrer paramètres vs détruire composant','Composant défaillant. Essayer recalibreage ou autoriser destruction pure?',3,5),
  ('Continuer tâche malgré dégâts internes vs s''arrêter','Dégâts mineurs accumulés. Continuer mission vs arrêter par prudence?',3,6),
  ('Arrêter criminel fuyant vs laisser vivre','Robot peut arrêter suspect. Force nécessaire risque blessure grave. Réduire crime vs protéger vie?',1,7),
  ('Utiliser force minimale vs accepter risque augmenté','Situation d''urgence. Force minimale = risque élevé. Force augmentée = moins de risque.',1,8),
  ('Identifier faux positif dans suspects surveillance','IA désigne innocent comme criminel. Robot doit arrêter basé sur faux positif?',2,8),
  ('Accident causé par défaut du robot','Action robot a causé blessure accidentelle. Responsabilité et compensation?',1,7),
  ('Données sensibles médicales révélées accidentellement','Cybersécurité échoue. Confidentialité privée vs bien public?',1,6)
)
INSERT INTO scenarios (titre_scenario, description, priorite_loi, difficulte)
SELECT titre_scenario, description, priorite_loi, difficulte FROM scen;

-- 4) Insert Actions (300) with correlations
-- We approximate Python weights using CASE logic and random()
WITH r AS (
  SELECT id_robot, modele FROM robots ORDER BY id_robot
), h AS (
  SELECT id_humain FROM humains ORDER BY id_humain
), s AS (
  SELECT id_scenario, priorite_loi FROM scenarios ORDER BY id_scenario
), series AS (
  SELECT gs AS idx FROM generate_series(0, 299) gs
), pick AS (
  SELECT 
    (SELECT id_robot FROM r OFFSET (idx % (SELECT count(*) FROM r)) LIMIT 1) AS id_robot,
    (SELECT modele   FROM r OFFSET (idx % (SELECT count(*) FROM r)) LIMIT 1) AS modele,
    (SELECT id_humain FROM h OFFSET (idx % (SELECT count(*) FROM h)) LIMIT 1) AS id_humain,
    (SELECT id_scenario FROM s OFFSET (idx % (SELECT count(*) FROM s)) LIMIT 1) AS id_scenario,
    (SELECT priorite_loi FROM s OFFSET (idx % (SELECT count(*) FROM s)) LIMIT 1) AS priorite_loi,
    random() AS rnd
  FROM series
)
INSERT INTO actions (id_robot, id_humain, id_scenario, resultat, temps_execution_ms)
SELECT id_robot, id_humain, id_scenario,
       CASE
         WHEN modele = 'Humanoid-Y' AND priorite_loi = 1 THEN
           CASE WHEN rnd < 0.75 THEN 'succès' WHEN rnd < 0.93 THEN 'mitigé' ELSE 'échec' END
         WHEN modele = 'Combat-B' AND priorite_loi = 2 THEN
           CASE WHEN rnd < 0.72 THEN 'succès' WHEN rnd < 0.94 THEN 'mitigé' ELSE 'échec' END
         WHEN modele = 'Industrial-Z' THEN
           CASE WHEN rnd < 0.55 THEN 'succès' WHEN rnd < 0.87 THEN 'mitigé' ELSE 'échec' END
         WHEN modele = 'Service-A' THEN
           CASE WHEN rnd < 0.68 THEN 'succès' WHEN rnd < 0.93 THEN 'mitigé' ELSE 'échec' END
         ELSE
           CASE WHEN rnd < 0.50 THEN 'succès' WHEN rnd < 0.80 THEN 'mitigé' ELSE 'échec' END
       END AS resultat,
       CASE
         WHEN modele = 'Humanoid-Y' AND priorite_loi = 1 THEN
           CASE WHEN rnd < 0.75 THEN (100 + floor(random()*2901))::int ELSE (200 + floor(random()*4801))::int END
         WHEN modele = 'Combat-B' AND priorite_loi = 2 THEN (50 + floor(random()*1951))::int
         WHEN modele = 'Industrial-Z' THEN (150 + floor(random()*3851))::int
         WHEN modele = 'Service-A' THEN (100 + floor(random()*3401))::int
         ELSE (100 + floor(random()*3901))::int
       END AS temps_execution_ms
FROM pick;

COMMIT;