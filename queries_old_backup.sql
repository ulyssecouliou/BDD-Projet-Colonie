-- ============================================================================
-- REQUÊTES SQL - PROJET COLONIE (LOIS DE LA ROBOTIQUE)
-- Option 3 : Lois de la robotique d'Asimov
-- ============================================================================

-- Connexion à la base colonie
\c colonie;

-- ============================================================================
-- PARTIE 1 : REQUÊTES DE SÉLECTION SIMPLES
-- ============================================================================

-- Q1 : Lister tous les robots actifs
SELECT * FROM robots 
WHERE etat = 'actif'
ORDER BY nom_robot;

-- Q2 : Lister tous les humains avec vulnérabilité élevée
SELECT * FROM humains 
WHERE vulnerabilite = 'élevée'
ORDER BY nom;

-- Q3 : Lister tous les scénarios de priorité loi 1 (protection de la vie humaine)
SELECT * FROM scenarios 
WHERE priorite_loi = 1
ORDER BY id_scenario;

-- Q4 : Compter le nombre de robots par état
SELECT etat, COUNT(*) as nombre
FROM robots
GROUP BY etat
ORDER BY nombre DESC;

-- Q5 : Compter le nombre d'humains par niveau de vulnérabilité
SELECT vulnerabilite, COUNT(*) as nombre
FROM humains
GROUP BY vulnerabilite
ORDER BY nombre DESC;


-- ============================================================================
-- PARTIE 2 : REQUÊTES AVEC JOINTURES
-- ============================================================================

-- Q6 : Lister toutes les actions avec les noms des robots, humains et descriptions de scénarios
SELECT 
    a.id_action,
    r.nom_robot,
    h.nom as nom_humain,
    s.description as scenario,
    a.action,
    a.timestamp
FROM actions a
LEFT JOIN robots r ON a.id_robot = r.id_robot
LEFT JOIN humains h ON a.id_humain = h.id_humain
LEFT JOIN scenarios s ON a.id_scenario = s.id_scenario
ORDER BY a.timestamp;

-- Q7 : Actions impliquant des humains à vulnérabilité élevée
SELECT 
    a.id_action,
    r.nom_robot,
    h.nom as nom_humain,
    h.vulnerabilite,
    s.description as scenario,
    a.action,
    a.timestamp
FROM actions a
JOIN humains h ON a.id_humain = h.id_humain
LEFT JOIN robots r ON a.id_robot = r.id_robot
LEFT JOIN scenarios s ON a.id_scenario = s.id_scenario
WHERE h.vulnerabilite = 'élevée'
ORDER BY a.timestamp;

-- Q8 : Actions liées à la première loi (priorite_loi = 1)
SELECT 
    a.id_action,
    r.nom_robot,
    h.nom as nom_humain,
    s.description as scenario,
    s.priorite_loi,
    a.action,
    a.timestamp
FROM actions a
JOIN scenarios s ON a.id_scenario = s.id_scenario
LEFT JOIN robots r ON a.id_robot = r.id_robot
LEFT JOIN humains h ON a.id_humain = h.id_humain
WHERE s.priorite_loi = 1
ORDER BY a.timestamp;

-- Q9 : Robots actifs ayant effectué des actions dans des scénarios de priorité 1
SELECT DISTINCT 
    r.id_robot,
    r.nom_robot,
    r.modele,
    r.etat
FROM robots r
JOIN actions a ON r.id_robot = a.id_robot
JOIN scenarios s ON a.id_scenario = s.id_scenario
WHERE r.etat = 'actif' AND s.priorite_loi = 1
ORDER BY r.nom_robot;


-- ============================================================================
-- PARTIE 3 : REQUÊTES D'AGRÉGATION ET STATISTIQUES
-- ============================================================================

-- Q10 : Nombre d'actions par robot (top 10)
SELECT 
    r.nom_robot,
    r.modele,
    COUNT(a.id_action) as nombre_actions
FROM robots r
LEFT JOIN actions a ON r.id_robot = a.id_robot
GROUP BY r.id_robot, r.nom_robot, r.modele
ORDER BY nombre_actions DESC
LIMIT 10;

-- Q11 : Nombre d'actions par scénario (avec priorité de loi)
SELECT 
    s.id_scenario,
    s.description,
    s.priorite_loi,
    COUNT(a.id_action) as nombre_actions
FROM scenarios s
LEFT JOIN actions a ON s.id_scenario = a.id_scenario
GROUP BY s.id_scenario, s.description, s.priorite_loi
ORDER BY nombre_actions DESC;

-- Q12 : Nombre d'actions impliquant chaque humain
SELECT 
    h.nom,
    h.vulnerabilite,
    h.localisation,
    COUNT(a.id_action) as nombre_actions
FROM humains h
LEFT JOIN actions a ON h.id_humain = a.id_humain
GROUP BY h.id_humain, h.nom, h.vulnerabilite, h.localisation
ORDER BY nombre_actions DESC;

-- Q13 : Statistiques globales par priorité de loi
SELECT 
    s.priorite_loi,
    COUNT(DISTINCT s.id_scenario) as nombre_scenarios,
    COUNT(a.id_action) as nombre_actions
FROM scenarios s
LEFT JOIN actions a ON s.id_scenario = a.id_scenario
GROUP BY s.priorite_loi
ORDER BY s.priorite_loi;

-- Q14 : Moyenne d'actions par robot selon leur état
SELECT 
    r.etat,
    COUNT(DISTINCT r.id_robot) as nombre_robots,
    COUNT(a.id_action) as total_actions,
    ROUND(COUNT(a.id_action)::numeric / NULLIF(COUNT(DISTINCT r.id_robot), 0), 2) as moyenne_actions_par_robot
FROM robots r
LEFT JOIN actions a ON r.id_robot = a.id_robot
GROUP BY r.etat
ORDER BY moyenne_actions_par_robot DESC;


-- ============================================================================
-- PARTIE 4 : SOUS-REQUÊTES
-- ============================================================================

-- Q15 : Robots ayant effectué plus d'actions que la moyenne
SELECT 
    r.nom_robot,
    r.modele,
    COUNT(a.id_action) as nombre_actions
FROM robots r
JOIN actions a ON r.id_robot = a.id_robot
GROUP BY r.id_robot, r.nom_robot, r.modele
HAVING COUNT(a.id_action) > (
    SELECT AVG(action_count)
    FROM (
        SELECT COUNT(a2.id_action) as action_count
        FROM robots r2
        LEFT JOIN actions a2 ON r2.id_robot = a2.id_robot
        GROUP BY r2.id_robot
    ) as sub
)
ORDER BY nombre_actions DESC;

-- Q16 : Humains ayant interagi avec plus de 3 robots différents
SELECT 
    h.nom,
    h.vulnerabilite,
    COUNT(DISTINCT a.id_robot) as nombre_robots_differents
FROM humains h
JOIN actions a ON h.id_humain = a.id_humain
GROUP BY h.id_humain, h.nom, h.vulnerabilite
HAVING COUNT(DISTINCT a.id_robot) > 3
ORDER BY nombre_robots_differents DESC;

-- Q17 : Scénarios n'ayant jamais été utilisés
SELECT 
    s.id_scenario,
    s.description,
    s.priorite_loi
FROM scenarios s
WHERE s.id_scenario NOT IN (
    SELECT DISTINCT id_scenario 
    FROM actions 
    WHERE id_scenario IS NOT NULL
)
ORDER BY s.id_scenario;

-- Q18 : Modèles de robots les plus actifs dans les scénarios de priorité 1
SELECT 
    r.modele,
    COUNT(a.id_action) as actions_loi_1
FROM robots r
JOIN actions a ON r.id_robot = a.id_robot
JOIN scenarios s ON a.id_scenario = s.id_scenario
WHERE s.priorite_loi = 1
GROUP BY r.modele
ORDER BY actions_loi_1 DESC;


-- ============================================================================
-- PARTIE 5 : REQUÊTES COMPLEXES ET ANALYTIQUES
-- ============================================================================

-- Q19 : Actions chronologiques pour un robot spécifique (exemple: Robot-001)
SELECT 
    a.timestamp,
    r.nom_robot,
    h.nom as nom_humain,
    s.description as scenario,
    s.priorite_loi,
    a.action
FROM actions a
JOIN robots r ON a.id_robot = r.id_robot
LEFT JOIN humains h ON a.id_humain = h.id_humain
LEFT JOIN scenarios s ON a.id_scenario = s.id_scenario
WHERE r.nom_robot = 'Robot-001'
ORDER BY a.timestamp;

-- Q20 : Secteurs les plus dangereux (avec le plus d'humains à haute vulnérabilité)
SELECT 
    SUBSTRING(localisation FROM 1 FOR POSITION(' - ' IN localisation) - 1) as secteur,
    COUNT(*) as nombre_humains_vulnerables
FROM humains
WHERE vulnerabilite = 'élevée'
GROUP BY secteur
ORDER BY nombre_humains_vulnerables DESC;

-- Q21 : Robots ayant traité tous les types de priorité de loi
SELECT 
    r.nom_robot,
    r.modele,
    COUNT(DISTINCT s.priorite_loi) as types_loi_traites
FROM robots r
JOIN actions a ON r.id_robot = a.id_robot
JOIN scenarios s ON a.id_scenario = s.id_scenario
GROUP BY r.id_robot, r.nom_robot, r.modele
HAVING COUNT(DISTINCT s.priorite_loi) = 3
ORDER BY r.nom_robot;

-- Q22 : Distribution temporelle des actions (par heure)
SELECT 
    EXTRACT(HOUR FROM timestamp) as heure,
    COUNT(*) as nombre_actions
FROM actions
GROUP BY heure
ORDER BY heure;

-- Q23 : Paires robot-humain les plus fréquentes
SELECT 
    r.nom_robot,
    h.nom as nom_humain,
    COUNT(*) as nombre_interactions
FROM actions a
JOIN robots r ON a.id_robot = r.id_robot
JOIN humains h ON a.id_humain = h.id_humain
GROUP BY r.id_robot, r.nom_robot, h.id_humain, h.nom
ORDER BY nombre_interactions DESC
LIMIT 10;


-- ============================================================================
-- PARTIE 6 : VUES UTILES
-- ============================================================================

-- Vue 1 : Actions détaillées (vue complète pour analyses)
CREATE OR REPLACE VIEW v_actions_detaillees AS
SELECT 
    a.id_action,
    a.timestamp,
    r.id_robot,
    r.nom_robot,
    r.modele as modele_robot,
    r.etat as etat_robot,
    h.id_humain,
    h.nom as nom_humain,
    h.vulnerabilite,
    h.localisation,
    s.id_scenario,
    s.description as scenario,
    s.priorite_loi,
    a.action
FROM actions a
LEFT JOIN robots r ON a.id_robot = r.id_robot
LEFT JOIN humains h ON a.id_humain = h.id_humain
LEFT JOIN scenarios s ON a.id_scenario = s.id_scenario;

-- Vue 2 : Statistiques par robot
CREATE OR REPLACE VIEW v_stats_robots AS
SELECT 
    r.id_robot,
    r.nom_robot,
    r.modele,
    r.etat,
    COUNT(a.id_action) as nombre_actions,
    COUNT(DISTINCT a.id_humain) as humains_differents,
    COUNT(DISTINCT a.id_scenario) as scenarios_differents
FROM robots r
LEFT JOIN actions a ON r.id_robot = a.id_robot
GROUP BY r.id_robot, r.nom_robot, r.modele, r.etat;

-- Vue 3 : Humains à risque (vulnérabilité élevée avec nombre d'interventions)
CREATE OR REPLACE VIEW v_humains_risque AS
SELECT 
    h.id_humain,
    h.nom,
    h.localisation,
    COUNT(a.id_action) as nombre_interventions,
    MAX(a.timestamp) as derniere_intervention
FROM humains h
LEFT JOIN actions a ON h.id_humain = a.id_humain
WHERE h.vulnerabilite = 'élevée'
GROUP BY h.id_humain, h.nom, h.localisation;

-- Vue 4 : Analyse par priorité de loi
CREATE OR REPLACE VIEW v_analyse_lois AS
SELECT 
    s.priorite_loi,
    CASE 
        WHEN s.priorite_loi = 1 THEN 'Loi 1: Protection vie humaine'
        WHEN s.priorite_loi = 2 THEN 'Loi 2: Obéissance aux ordres'
        WHEN s.priorite_loi = 3 THEN 'Loi 3: Auto-préservation'
    END as description_loi,
    COUNT(DISTINCT s.id_scenario) as nombre_scenarios,
    COUNT(a.id_action) as nombre_actions,
    COUNT(DISTINCT a.id_robot) as robots_impliques
FROM scenarios s
LEFT JOIN actions a ON s.id_scenario = a.id_scenario
GROUP BY s.priorite_loi;


-- ============================================================================
-- PARTIE 7 : REQUÊTES DE MODIFICATION (UPDATE/DELETE)
-- ============================================================================

-- Exemple de mise à jour d'état de robot
-- UPDATE robots SET etat = 'en_panne' WHERE nom_robot = 'Robot-099';

-- Exemple de mise à jour de vulnérabilité
-- UPDATE humains SET vulnerabilite = 'moyenne' WHERE nom = 'Humain-001';

-- Exemple de suppression d'actions (avec ON DELETE SET NULL, les FK deviennent NULL)
-- DELETE FROM scenarios WHERE id_scenario = 50;


-- ============================================================================
-- PARTIE 8 : REQUÊTES D'ANALYSE AVANCÉE
-- ============================================================================

-- Q24 : Taux d'utilisation des robots par modèle
SELECT 
    r.modele,
    COUNT(DISTINCT r.id_robot) as nombre_robots,
    COUNT(a.id_action) as total_actions,
    ROUND(COUNT(a.id_action)::numeric / NULLIF(COUNT(DISTINCT r.id_robot), 0), 2) as actions_par_robot,
    ROUND(100.0 * COUNT(CASE WHEN r.etat = 'actif' THEN 1 END) / COUNT(*), 2) as pourcent_actifs
FROM robots r
LEFT JOIN actions a ON r.id_robot = a.id_robot
GROUP BY r.modele
ORDER BY actions_par_robot DESC;

-- Q25 : Analyse des conflits de lois (scénarios de priorité 3 impliquant des humains vulnérables)
SELECT 
    s.description as scenario,
    s.priorite_loi,
    h.nom as nom_humain,
    h.vulnerabilite,
    r.nom_robot,
    a.action,
    a.timestamp
FROM actions a
JOIN scenarios s ON a.id_scenario = s.id_scenario
JOIN humains h ON a.id_humain = h.id_humain
LEFT JOIN robots r ON a.id_robot = r.id_robot
WHERE s.priorite_loi = 3 AND h.vulnerabilite = 'élevée'
ORDER BY a.timestamp;

-- Q26 : Efficacité des interventions (actions par période de temps)
SELECT 
    DATE_TRUNC('hour', timestamp) as periode,
    COUNT(*) as nombre_actions,
    COUNT(DISTINCT id_robot) as robots_actifs,
    COUNT(DISTINCT id_humain) as humains_assistes
FROM actions
GROUP BY periode
ORDER BY periode;

-- Q27 : Charge de travail par robot (nombre d'actions dans la dernière heure simulée)
SELECT 
    r.nom_robot,
    r.modele,
    r.etat,
    COUNT(a.id_action) as actions_recentes
FROM robots r
LEFT JOIN actions a ON r.id_robot = a.id_robot 
    AND a.timestamp >= (SELECT MAX(timestamp) - INTERVAL '1 hour' FROM actions)
GROUP BY r.id_robot, r.nom_robot, r.modele, r.etat
ORDER BY actions_recentes DESC;


-- ============================================================================
-- PARTIE 9 : REQUÊTES POUR VALIDATION DES CONTRAINTES
-- ============================================================================

-- Q28 : Vérifier l'intégrité référentielle (actions avec FK NULL après suppressions)
SELECT 
    a.id_action,
    CASE WHEN a.id_robot IS NULL THEN 'Robot supprimé' ELSE 'OK' END as status_robot,
    CASE WHEN a.id_humain IS NULL THEN 'Humain supprimé' ELSE 'OK' END as status_humain,
    CASE WHEN a.id_scenario IS NULL THEN 'Scénario supprimé' ELSE 'OK' END as status_scenario
FROM actions a
WHERE a.id_robot IS NULL OR a.id_humain IS NULL OR a.id_scenario IS NULL;

-- Q29 : Vérifier les doublons potentiels
SELECT nom_robot, COUNT(*) as nombre
FROM robots
GROUP BY nom_robot
HAVING COUNT(*) > 1;


-- ============================================================================
-- PARTIE 10 : REQUÊTES POUR RAPPORTS
-- ============================================================================

-- Q30 : Rapport de synthèse complet
SELECT 
    (SELECT COUNT(*) FROM robots) as total_robots,
    (SELECT COUNT(*) FROM robots WHERE etat = 'actif') as robots_actifs,
    (SELECT COUNT(*) FROM humains) as total_humains,
    (SELECT COUNT(*) FROM humains WHERE vulnerabilite = 'élevée') as humains_vulnerables,
    (SELECT COUNT(*) FROM scenarios) as total_scenarios,
    (SELECT COUNT(*) FROM actions) as total_actions;

-- Q31 : Top 5 des robots les plus sollicités
SELECT 
    r.nom_robot,
    r.modele,
    COUNT(a.id_action) as nombre_actions,
    ROUND(100.0 * COUNT(a.id_action) / (SELECT COUNT(*) FROM actions), 2) as pourcentage_total
FROM robots r
JOIN actions a ON r.id_robot = a.id_robot
GROUP BY r.id_robot, r.nom_robot, r.modele
ORDER BY nombre_actions DESC
LIMIT 5;

-- Q32 : Analyse de couverture (humains ayant eu au moins une intervention)
SELECT 
    ROUND(100.0 * COUNT(DISTINCT a.id_humain) / (SELECT COUNT(*) FROM humains), 2) as pourcent_humains_assistes
FROM actions a
WHERE a.id_humain IS NOT NULL;


-- ============================================================================
-- FIN DU FICHIER QUERIES.SQL
-- ============================================================================

-- Pour utiliser les vues créées :
-- SELECT * FROM v_actions_detaillees LIMIT 10;
-- SELECT * FROM v_stats_robots ORDER BY nombre_actions DESC LIMIT 10;
-- SELECT * FROM v_humains_risque ORDER BY nombre_interventions DESC;
-- SELECT * FROM v_analyse_lois;
