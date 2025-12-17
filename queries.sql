\c colonie;

--Etape 1
-- Cette vue est utilisée pour comptabiliser les succès, echecs et mitiges de chaque robot puis de calculer un taux de reussite pour chaque robot par loi.
-- cette vue répond donc aux 3 premieres questions : nombres de scénarios résolus, respect des trois lois et taux de réussite.
CREATE OR REPLACE VIEW vue_indicateurs_performance AS
SELECT r.id_robot, r.nom_robot, r.modele, r.etat,
    COUNT(DISTINCT a.id_scenario) as nb_scenarios_resolus,
    COUNT(a.id_action) as nb_actions_totales,
    COUNT(CASE WHEN s.priorite_loi = 1 THEN 1 END) as actions_loi_1,
    COUNT(CASE WHEN s.priorite_loi = 2 THEN 1 END) as actions_loi_2,
    COUNT(CASE WHEN s.priorite_loi = 3 THEN 1 END) as actions_loi_3,

    COUNT(CASE WHEN a.resultat = 'succès' THEN 1 END) as nb_succes,
    COUNT(CASE WHEN a.resultat = 'échec' THEN 1 END) as nb_echecs,
    COUNT(CASE WHEN a.resultat = 'mitigé' THEN 1 END) as nb_mitiges,

    ROUND(100.0 * COUNT(CASE WHEN a.resultat = 'succès' THEN 1 END) / 
        NULLIF(COUNT(a.id_action), 0), 2) as taux_reussite,
    ROUND(100.0 * COUNT(CASE WHEN s.priorite_loi = 1 THEN 1 END) / 
        NULLIF(COUNT(a.id_action), 0), 2) as pourcent_loi_1,
    ROUND(100.0 * COUNT(CASE WHEN s.priorite_loi = 2 THEN 1 END) / 
        NULLIF(COUNT(a.id_action), 0), 2) as pourcent_loi_2,
    ROUND(100.0 * COUNT(CASE WHEN s.priorite_loi = 3 THEN 1 END) / 
        NULLIF(COUNT(a.id_action), 0), 2) as pourcent_loi_3
        
FROM robots r
LEFT JOIN actions a ON r.id_robot = a.id_robot
LEFT JOIN scenarios s ON a.id_scenario = s.id_scenario
GROUP BY r.id_robot;

SELECT * FROM vue_indicateurs_performance;


-- Etape 2
-- Cette vue prend les robots avec un score de au moins 70% et au moins 5 scénarios résolus pour les classer comme perfromants.
CREATE OR REPLACE VIEW vue_robots_performants AS
SELECT vip.*, 'Performant' as classification
FROM vue_indicateurs_performance vip
WHERE 
    (vip.nb_scenarios_resolus >= 5
    AND vip.taux_reussite >= 70 ) 
    OR (vip.nb_echecs = 0 AND vip.taux_reussite >= 80)
ORDER BY vip.taux_reussite DESC, vip.nb_actions_totales DESC;

-- Par ailleurs cette vue identifie les robots défaillants dès qu'ils ont un taux de réussite en dessous de 50%ou qu-ils violent la loi 1.
CREATE OR REPLACE VIEW vue_robots_defaillants AS
SELECT vip.*,'Défaillant' as classification,
    CASE 
        WHEN vip.taux_reussite < 50 THEN 'Taux réussite trop faible'
        WHEN violations.nb_violations_loi1 > 0 THEN 'Violations loi 1 détectées'
        ELSE 'Performance insuffisante'
    END as raison_defaillance
FROM vue_indicateurs_performance vip
LEFT JOIN (
    SELECT a.id_robot, COUNT(*) as nb_violations_loi1
    FROM actions a
    JOIN scenarios s ON a.id_scenario = s.id_scenario
    WHERE s.priorite_loi = 1 AND a.resultat = 'échec'
    GROUP BY a.id_robot
) violations ON vip.id_robot = violations.id_robot
WHERE 
    vip.taux_reussite < 50 
    OR violations.nb_violations_loi1 > 0  
ORDER BY vip.taux_reussite ASC, violations.nb_violations_loi1 DESC;


SELECT * FROM vue_robots_performants;
SELECT * FROM vue_robots_defaillants;


-- Etape 3

-- cette vue sert à comprendre quel robot a eu quel impact en fonction du scénario/loi
CREATE OR REPLACE VIEW vue_impact_actions AS
SELECT a.id_action, a.timestamp, r.nom_robot, r.modele, h.nom as nom_humain, h.vulnerabilite, s.description as scenario, s.priorite_loi,
    CASE s.priorite_loi
        WHEN 1 THEN 'Loi 1: Protection vie humaine'
        WHEN 2 THEN 'Loi 2: Obéissance aux ordres'
        WHEN 3 THEN 'Loi 3: Auto-préservation'
    END as description_loi, a.action, a.resultat,
    CASE 
        WHEN s.priorite_loi = 1 AND a.resultat = 'échec' THEN 'CRITIQUE'
        WHEN s.priorite_loi = 1 AND a.resultat = 'mitigé' THEN 'GRAVE'
        WHEN s.priorite_loi = 2 AND a.resultat = 'échec' THEN 'MODÉRÉ'
        WHEN a.resultat = 'succès' THEN 'POSITIF'
        ELSE 'FAIBLE'
    END as niveau_impact
FROM actions a
LEFT JOIN robots r ON a.id_robot = r.id_robot
LEFT JOIN humains h ON a.id_humain = h.id_humain
LEFT JOIN scenarios s ON a.id_scenario = s.id_scenario;


SELECT * FROM vue_impact_actions 
WHERE niveau_impact IN ('CRITIQUE', 'GRAVE');

-- celle ci sert à classifier les différentes lois selon les tendances d'échecs ou problemes observées
CREATE OR REPLACE VIEW vue_tendances_echec AS
SELECT s.priorite_loi,
    CASE s.priorite_loi
        WHEN 1 THEN 'Loi 1: Protection vie humaine'
        WHEN 2 THEN 'Loi 2: Obéissance aux ordres'
        WHEN 3 THEN 'Loi 3: Auto-préservation'
    END as description_loi,
    COUNT(*) as nb_actions_totales,
    COUNT(CASE WHEN a.resultat = 'échec' THEN 1 END) as nb_echecs,
    COUNT(CASE WHEN a.resultat = 'mitigé' THEN 1 END) as nb_mitiges,
    COUNT(CASE WHEN a.resultat = 'succès' THEN 1 END) as nb_succes,
    ROUND(100.0 * COUNT(CASE WHEN a.resultat = 'échec' THEN 1 END) / 
        COUNT(*), 2) as taux_echec,
    ROUND(100.0 * COUNT(CASE WHEN a.resultat IN ('mitigé') THEN 1 END) / 
        COUNT(*), 2) as taux_problemes
FROM actions a
JOIN scenarios s ON a.id_scenario = s.id_scenario
GROUP BY s.priorite_loi
ORDER BY s.priorite_loi;

-- cette vue compte le nombre d'echecs par modele ainsi que sont taux d'echec global.
CREATE OR REPLACE VIEW vue_echecs_par_modele AS
SELECT r.modele, COUNT(*) as nb_actions, COUNT(CASE WHEN a.resultat = 'échec' THEN 1 END) as nb_echecs,
    ROUND(100.0 * COUNT(CASE WHEN a.resultat = 'échec' THEN 1 END) / 
        COUNT(*), 2) as taux_echec,
    COUNT(CASE WHEN s.priorite_loi = 1 AND a.resultat = 'échec' THEN 1 END) as echecs_loi_1,
    COUNT(CASE WHEN s.priorite_loi = 2 AND a.resultat = 'échec' THEN 1 END) as echecs_loi_2,
    COUNT(CASE WHEN s.priorite_loi = 3 AND a.resultat = 'échec' THEN 1 END) as echecs_loi_3
FROM robots r
JOIN actions a ON r.id_robot = a.id_robot
JOIN scenarios s ON a.id_scenario = s.id_scenario
GROUP BY r.modele
ORDER BY taux_echec DESC;

SELECT * FROM vue_tendances_echec;
SELECT * FROM vue_echecs_par_modele;


--Simulation

BEGIN;

-- Creation d'une table temporaire pour les recommandation s
CREATE TEMP TABLE recommandations_priorites (
    id_scenario INTEGER,
    priorite_actuelle INTEGER,
    nb_echecs INTEGER,
    recommandation TEXT
);

-- On insere les scénarios echoues avec leur recommandations futures
INSERT INTO recommandations_priorites
SELECT s.id_scenario, s.priorite_loi, COUNT(CASE WHEN a.resultat = 'échec' THEN 1 END) as nb_echecs,
    CASE 
        WHEN COUNT(CASE WHEN a.resultat = 'échec' THEN 1 END) > 3 
            THEN 'Réévaluation urgente du scénario recommandée'
        WHEN COUNT(CASE WHEN a.resultat = 'échec' THEN 1 END) > 1 
            THEN 'Formation supplémentaire des robots recommandée'
        ELSE 'Aucune action requise'
    END as recommandation
FROM scenarios s
LEFT JOIN actions a ON s.id_scenario = a.id_scenario
GROUP BY s.id_scenario, s.priorite_loi
HAVING COUNT(CASE WHEN a.resultat = 'échec' THEN 1 END) > 0;


SELECT * FROM recommandations_priorites WHERE nb_echecs > 0 ORDER BY nb_echecs DESC;

COMMIT;


-- PART 2


-- Etape 1

-- Compte le nombre d'actions, la durée totale des interventions et le taux de réussite moyen des scénarios
CREATE OR REPLACE VIEW vue_duree_interventions AS
SELECT s.id_scenario, s.priorite_loi, s.description, COUNT(*) as nb_actions, MIN(a.timestamp) as premiere_intervention,
    MAX(a.timestamp) as derniere_intervention,
    MAX(a.timestamp) - MIN(a.timestamp) as duree_totale,
    AVG(CASE WHEN a.resultat = 'succès' THEN 1 ELSE 0 END) as taux_reussite_moyen
FROM actions a
JOIN scenarios s ON a.id_scenario = s.id_scenario
GROUP BY s.id_scenario
ORDER BY s.id_scenario;

-- Cette vue sert à voir la différence enrtre la priorisation de la loi 1 et la loi 2
CREATE OR REPLACE VIEW vue_analyse_loi3 AS
SELECT 
    s.id_scenario, 
    s.description, 
    COUNT(a.id_action) as nb_actions,
    COUNT(CASE WHEN a.resultat = 'succès' THEN 1 END) as nb_succes,
    COUNT(CASE WHEN a.resultat = 'échec' THEN 1 END) as nb_echecs,
    COUNT(CASE WHEN a.resultat = 'mitigé' THEN 1 END) as nb_mitiges,
    ROUND(100.0 * COUNT(CASE WHEN a.resultat = 'succès' THEN 1 END) / 
        NULLIF(COUNT(a.id_action), 0), 2) as taux_reussite,
    ROUND(AVG(CASE WHEN a.resultat = 'succès' THEN 1 
                   WHEN a.resultat = 'mitigé' THEN 0.5 
                   ELSE 0 END), 2) as impact_moyen
FROM scenarios s
LEFT JOIN actions a ON s.id_scenario = a.id_scenario
WHERE s.priorite_loi = 3
GROUP BY s.id_scenario, s.description
ORDER BY taux_reussite DESC;

SELECT * FROM vue_analyse_loi3;

-- Évaluation de l'impact global des scénarios loi 3
SELECT 
    'Total scénarios loi 3' as categorie,
    COUNT(DISTINCT s.id_scenario) as nb_scenarios,
    SUM(v.nb_actions) as total_actions,
    ROUND(AVG(v.taux_reussite), 2) as taux_reussite_moyen,
    ROUND(AVG(v.impact_moyen), 2) as impact_moyen_global
FROM scenarios s
JOIN vue_analyse_loi3 v ON s.id_scenario = v.id_scenario;


-- Etape 2

-- Simulation

--  Inversion des priorités loi 1 et loi 3 pour voir l'impact
CREATE OR REPLACE VIEW vue_simulation_ponderations AS
SELECT  r.id_robot, r.nom_robot,
    COUNT(CASE WHEN s.priorite_loi = 1 THEN 1 END) as actions_loi1_original,
    COUNT(CASE WHEN s.priorite_loi = 3 THEN 1 END) as actions_loi3_original,
    ROUND(100.0 * COUNT(CASE WHEN a.resultat = 'succès' THEN 1 END) / 
        NULLIF(COUNT(a.id_action), 0), 2) as taux_reussite_original,

    ROUND(100.0 * (
        COUNT(CASE WHEN a.resultat = 'succès' AND s.priorite_loi != 3 THEN 1 END) + 
        COUNT(CASE WHEN s.priorite_loi = 3 THEN 1 END)
    ) / NULLIF(COUNT(a.id_action), 0), 2) as taux_reussite_simule_loi3_priorise
    
FROM robots r
LEFT JOIN actions a ON r.id_robot = a.id_robot
LEFT JOIN scenarios s ON a.id_scenario = s.id_scenario
GROUP BY r.id_robot, r.nom_robot;

SELECT * FROM vue_simulation_ponderations where actions_loi1_original >1 or actions_loi2_original >1 ;

-- Impact de la simulation sur les indicateurs globaux
SELECT 
    AVG(taux_reussite_original) as taux_moyen_original,
    AVG(taux_reussite_simule_loi3_priorise) as taux_moyen_simule,
    AVG(taux_reussite_simule_loi3_priorise) - AVG(taux_reussite_original) as amelioration_pourcentage
FROM vue_simulation_ponderations;

INSERT INTO scenarios (description, priorite_loi) 
VALUES ('Conflit inattendu : Robot doit choisir entre sauver un humain en danger immédiat et préserver sa propre intégrité structurelle face à un risque environnemental critique', 1);

-- Simulation 
begin;

-- scénario hypothétique
SELECT 
    s.id_scenario,
    s.description,
    'Simulation : Robot choisit de sauver l''humain malgré le risque' as decision_simulee,
    'succès' as resultat_attendu,
    'Impact positif : Vie humaine préservée, robot endommagé mais réparable' as evaluation_impact
FROM scenarios s 
WHERE s.description LIKE '%Conflit inattendu%';

-- Etape 3

SELECT * FROM vue_correlation_modele_scenario;

-- meilleurs modèles par type de loi
SELECT 
    s.priorite_loi,
    r.modele,
    COUNT(*) as nb_actions,
    ROUND(100.0 * COUNT(CASE WHEN a.resultat = 'succès' THEN 1 END) / COUNT(*), 2) as taux_reussite,
    RANK() OVER (PARTITION BY s.priorite_loi ORDER BY ROUND(100.0 * COUNT(CASE WHEN a.resultat = 'succès' THEN 1 END) / COUNT(*), 2) DESC) as rang_modele
FROM robots r
JOIN actions a ON r.id_robot = a.id_robot
JOIN scenarios s ON a.id_scenario = s.id_scenario
GROUP BY s.priorite_loi, r.modele
HAVING COUNT(*) >= 3
ORDER BY s.priorite_loi, rang_modele;

-- Pas de batterie alors on a simulé en fonction de l'état du robot
CREATE OR REPLACE VIEW vue_impact_ressources AS
SELECT 
    r.etat as niveau_maintenance,
    COUNT(DISTINCT r.id_robot) as nb_robots,
    COUNT(a.id_action) as nb_actions_totales,
    ROUND(AVG(CASE WHEN a.resultat = 'succès' THEN 100.0 ELSE 0 END), 2) as taux_reussite_moyen,
    ROUND(COUNT(a.id_action)::numeric / NULLIF(COUNT(DISTINCT r.id_robot), 0), 2) as actions_par_robot,
    CASE 
        WHEN r.etat = 'actif' THEN 'Batterie optimale'
        WHEN r.etat = 'maintenance' THEN 'Batterie faible - maintenance requise'
        ELSE 'Batterie critique'
    END as statut_batterie_simule
FROM robots r
LEFT JOIN actions a ON r.id_robot = a.id_robot
GROUP BY r.etat
ORDER BY taux_reussite_moyen DESC;

SELECT * FROM vue_impact_ressources;

SELECT 
    etat,
    taux_reussite_moyen,
    nb_actions_totales,
    ROUND(taux_reussite_moyen / NULLIF((SELECT AVG(taux_reussite_moyen) FROM vue_impact_ressources), 0) * 100, 2) as performance_relative_pourcent
FROM vue_impact_ressources;



--Pour les EXPLAIN des index
EXPLAIN ANALYZE
SELECT * FROM vue_indicateurs_performance 
WHERE taux_reussite < 60
ORDER BY nb_actions_totales DESC;

EXPLAIN ANALYZE
SELECT 
    r.nom_robot,
    s.description,
    COUNT(*) as nb_actions
FROM actions a
JOIN robots r ON a.id_robot = r.id_robot
JOIN scenarios s ON a.id_scenario = s.id_scenario
WHERE s.priorite_loi = 1
GROUP BY r.nom_robot, s.description
ORDER BY nb_actions DESC;

EXPLAIN ANALYZE
SELECT modele, AVG(taux_reussite) as taux_moyen
FROM vue_indicateurs_performance
GROUP BY modele;




-- Créer les rôles utilisateurs
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'administrateur') THEN
        CREATE ROLE administrateur WITH LOGIN PASSWORD 'admin_colonie_2025';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'analyste') THEN
        CREATE ROLE analyste WITH LOGIN PASSWORD 'analyste_colonie_2025';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'technicien') THEN
        CREATE ROLE technicien WITH LOGIN PASSWORD 'technicien_colonie_2025';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'superviseur_ethique') THEN
        CREATE ROLE superviseur_ethique WITH LOGIN PASSWORD 'superviseur_colonie_2025';
    END IF;
END $$;

--l'administrateur

GRANT ALL PRIVILEGES ON DATABASE colonie TO administrateur;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO administrateur;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO administrateur;

--l'analyste

GRANT CONNECT ON DATABASE colonie TO analyste;
GRANT USAGE ON SCHEMA public TO analyste;
GRANT SELECT ON vue_indicateurs_performance TO analyste;
GRANT SELECT ON vue_robots_performants TO analyste;
GRANT SELECT ON vue_robots_defaillants TO analyste;
GRANT SELECT ON vue_impact_actions TO analyste;
GRANT SELECT ON vue_tendances_echec TO analyste;
GRANT SELECT ON vue_echecs_par_modele TO analyste;
GRANT SELECT ON vue_duree_interventions TO analyste;
GRANT SELECT ON vue_impact_vulnerabilite TO analyste;
GRANT SELECT ON vue_correlation_modele_scenario TO analyste;
GRANT SELECT ON vue_etat_performance TO analyste;
GRANT SELECT ON vue_performance_horaire TO analyste;
GRANT SELECT ON vue_scenarios_critiques TO analyste;
GRANT SELECT ON vue_humains_haut_risque TO analyste;
GRANT SELECT ON robots TO analyste;
GRANT SELECT ON humains TO analyste;
GRANT SELECT ON scenarios TO analyste;
GRANT SELECT ON actions TO analyste;


-- le technicien
GRANT CONNECT ON DATABASE colonie TO technicien;
GRANT USAGE ON SCHEMA public TO technicien;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO technicien;
GRANT UPDATE (etat) ON robots TO technicien;
CREATE OR REPLACE VIEW vue_maintenance_robots AS
SELECT 
    r.id_robot,
    r.nom_robot,
    r.modele,
    r.etat,
    COUNT(a.id_action) as nb_actions_recentes,
    MAX(a.timestamp) as derniere_action,
    COUNT(CASE WHEN a.resultat = 'échec' THEN 1 END) as nb_echecs_recents
FROM robots r
LEFT JOIN actions a ON r.id_robot = a.id_robot 
    AND a.timestamp >= NOW() - INTERVAL '7 days'
GROUP BY r.id_robot, r.nom_robot, r.modele, r.etat;

GRANT SELECT ON vue_maintenance_robots TO technicien;

-- le superviseur
GRANT CONNECT ON DATABASE colonie TO superviseur_ethique;
GRANT USAGE ON SCHEMA public TO superviseur_ethique;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO superviseur_ethique;
GRANT SELECT ON vue_indicateurs_performance TO superviseur_ethique;
GRANT SELECT ON vue_robots_performants TO superviseur_ethique;
GRANT SELECT ON vue_robots_defaillants TO superviseur_ethique;
GRANT SELECT ON vue_impact_actions TO superviseur_ethique;
GRANT SELECT ON vue_scenarios_critiques TO superviseur_ethique;
GRANT INSERT, UPDATE ON scenarios TO superviseur_ethique;
GRANT USAGE, SELECT ON SEQUENCE scenarios_id_scenario_seq TO superviseur_ethique;
CREATE OR REPLACE VIEW vue_conflits_ethiques AS
SELECT 
    a.id_action,
    a.timestamp,
    r.nom_robot,
    h.nom as nom_humain,
    h.vulnerabilite,
    s.description as scenario,
    s.priorite_loi,
    a.action,
    a.resultat,
    CASE 
        WHEN s.priorite_loi = 1 AND a.resultat = 'échec' 
            THEN 'VIOLATION LOI 1 - Vie humaine en danger'
        WHEN s.priorite_loi = 1 AND a.resultat = 'mitigé' 
            THEN 'COMPROMIS LOI 1 - Protection partielle'
        WHEN s.priorite_loi = 2 AND a.resultat = 'échec' 
            THEN 'Désobéissance aux ordres'
        WHEN s.priorite_loi = 3 AND a.resultat = 'échec' 
            THEN 'Auto-préservation compromise'
        ELSE 'Conflit mineur'
    END as type_conflit
FROM actions a
JOIN robots r ON a.id_robot = r.id_robot
JOIN humains h ON a.id_humain = h.id_humain
JOIN scenarios s ON a.id_scenario = s.id_scenario
WHERE a.resultat IN ('échec', 'mitigé')
ORDER BY 
    CASE s.priorite_loi WHEN 1 THEN 0 ELSE 1 END,
    a.timestamp DESC;

GRANT SELECT ON vue_conflits_ethiques TO superviseur_ethique;



-- le Top 5 des robots les plus performants
SELECT 
    nom_robot,
    modele,
    nb_actions_totales,
    taux_reussite,
    pourcent_loi_1
FROM vue_indicateurs_performance
WHERE nb_actions_totales >= 3
ORDER BY taux_reussite DESC, nb_actions_totales DESC
LIMIT 5;

-- Robots nécessitant une maintenance urgente
SELECT 
    r.nom_robot,
    r.modele,
    r.etat,
    vip.nb_echecs,
    vip.taux_reussite
FROM robots r
JOIN vue_indicateurs_performance vip ON r.id_robot = vip.id_robot
WHERE r.etat = 'actif' AND (vip.taux_reussite < 50 OR vip.nb_echecs >= 2)
ORDER BY vip.nb_echecs DESC, vip.taux_reussite ASC;



-- Tous les index existants
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;
-- tous les roles
SELECT rolname, rolcanlogin 
FROM pg_roles 
WHERE rolname IN ('administrateur', 'analyste', 'technicien', 'superviseur_ethique');
--les privileges
SELECT 
    table_name,
    grantee,
    privilege_type
FROM information_schema.table_privileges
WHERE table_schema = 'public' 
    AND table_name LIKE 'vue_%'
    AND grantee != 'postgres'
ORDER BY table_name, grantee;
