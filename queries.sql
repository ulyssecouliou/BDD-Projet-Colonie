-- ============================================================================
-- REQUÊTES SQL - PROJET COLONIE - OPTION 3
-- Analyse des performances des robots et conformité aux Lois de la Robotique
-- ============================================================================

\c colonie;

-- ============================================================================
-- PARTIE I : ÉTAPES GUIDÉES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- ÉTAPE 1 : INDICATEURS DE PERFORMANCE
-- ----------------------------------------------------------------------------

-- Vue principale : Indicateurs de performance par robot
CREATE OR REPLACE VIEW vue_indicateurs_performance AS
SELECT 
    r.id_robot,
    r.nom_robot,
    r.modele,
    r.etat,
    -- Nombre total de scénarios résolus
    COUNT(DISTINCT a.id_scenario) as nb_scenarios_resolus,
    COUNT(a.id_action) as nb_actions_totales,
    -- Répartition par loi
    COUNT(CASE WHEN s.priorite_loi = 1 THEN 1 END) as actions_loi_1,
    COUNT(CASE WHEN s.priorite_loi = 2 THEN 1 END) as actions_loi_2,
    COUNT(CASE WHEN s.priorite_loi = 3 THEN 1 END) as actions_loi_3,
    -- Taux de réussite
    COUNT(CASE WHEN a.resultat = 'succès' THEN 1 END) as nb_succes,
    COUNT(CASE WHEN a.resultat = 'échec' THEN 1 END) as nb_echecs,
    COUNT(CASE WHEN a.resultat = 'mitigé' THEN 1 END) as nb_mitiges,
    ROUND(100.0 * COUNT(CASE WHEN a.resultat = 'succès' THEN 1 END) / 
        NULLIF(COUNT(a.id_action), 0), 2) as taux_reussite,
    -- Conformité (priorisation loi 1)
    ROUND(100.0 * COUNT(CASE WHEN s.priorite_loi = 1 THEN 1 END) / 
        NULLIF(COUNT(a.id_action), 0), 2) as pourcent_loi_1
FROM robots r
LEFT JOIN actions a ON r.id_robot = a.id_robot
LEFT JOIN scenarios s ON a.id_scenario = s.id_scenario
GROUP BY r.id_robot, r.nom_robot, r.modele, r.etat;

-- Consultation de la vue
SELECT * FROM vue_indicateurs_performance 
ORDER BY taux_reussite DESC, nb_actions_totales DESC
LIMIT 20;


-- ----------------------------------------------------------------------------
-- ÉTAPE 2 : ROBOTS PERFORMANTS VS DÉFAILLANTS
-- ----------------------------------------------------------------------------

-- Vue : Robots performants
CREATE OR REPLACE VIEW vue_robots_performants AS
SELECT 
    vip.*,
    'Performant' as classification
FROM vue_indicateurs_performance vip
WHERE 
    vip.nb_scenarios_resolus >= 5  -- Nombre élevé de scénarios
    AND vip.taux_reussite >= 70    -- Fort taux de réussite
    AND (vip.nb_echecs = 0 OR vip.taux_reussite >= 80)  -- Peu ou pas d'échecs
ORDER BY vip.taux_reussite DESC, vip.nb_actions_totales DESC;

-- Vue : Robots défaillants
CREATE OR REPLACE VIEW vue_robots_defaillants AS
SELECT 
    vip.*,
    'Défaillant' as classification,
    -- Indicateurs de défaillance
    CASE 
        WHEN vip.taux_reussite < 50 THEN 'Taux réussite critique'
        WHEN vip.nb_echecs > vip.nb_succes THEN 'Plus échecs que succès'
        WHEN violations.nb_violations_loi1 > 0 THEN 'Violations loi 1 détectées'
        ELSE 'Performance insuffisante'
    END as raison_defaillance
FROM vue_indicateurs_performance vip
LEFT JOIN (
    SELECT 
        a.id_robot,
        COUNT(*) as nb_violations_loi1
    FROM actions a
    JOIN scenarios s ON a.id_scenario = s.id_scenario
    WHERE s.priorite_loi = 1 AND a.resultat = 'échec'
    GROUP BY a.id_robot
) violations ON vip.id_robot = violations.id_robot
WHERE 
    vip.taux_reussite < 50  -- Taux de réussite inférieur à 50%
    OR violations.nb_violations_loi1 > 0  -- Violations de la loi 1
    OR vip.nb_echecs > vip.nb_succes  -- Plus d'échecs que de succès
ORDER BY vip.taux_reussite ASC, violations.nb_violations_loi1 DESC;

-- Consultation des robots performants
SELECT * FROM vue_robots_performants LIMIT 10;

-- Consultation des robots défaillants
SELECT * FROM vue_robots_defaillants;


-- ----------------------------------------------------------------------------
-- ÉTAPE 3 : IMPACT DES ACTIONS ET TENDANCES D'ÉCHEC
-- ----------------------------------------------------------------------------

-- Vue : Impact des actions
CREATE OR REPLACE VIEW vue_impact_actions AS
SELECT 
    a.id_action,
    a.timestamp,
    r.nom_robot,
    r.modele,
    h.nom as nom_humain,
    h.vulnerabilite,
    s.description as scenario,
    s.priorite_loi,
    CASE s.priorite_loi
        WHEN 1 THEN 'Loi 1: Protection vie humaine'
        WHEN 2 THEN 'Loi 2: Obéissance aux ordres'
        WHEN 3 THEN 'Loi 3: Auto-préservation'
    END as description_loi,
    a.action,
    a.resultat,
    -- Évaluation de l'impact
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

-- Consultation des impacts critiques
SELECT * FROM vue_impact_actions 
WHERE niveau_impact IN ('CRITIQUE', 'GRAVE')
ORDER BY timestamp DESC;

-- Vue : Tendances d'échec
CREATE OR REPLACE VIEW vue_tendances_echec AS
SELECT 
    s.priorite_loi,
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
    ROUND(100.0 * COUNT(CASE WHEN a.resultat IN ('échec', 'mitigé') THEN 1 END) / 
        COUNT(*), 2) as taux_problemes
FROM actions a
JOIN scenarios s ON a.id_scenario = s.id_scenario
GROUP BY s.priorite_loi
ORDER BY s.priorite_loi;

-- Analyse des échecs par modèle de robot
CREATE OR REPLACE VIEW vue_echecs_par_modele AS
SELECT 
    r.modele,
    COUNT(*) as nb_actions,
    COUNT(CASE WHEN a.resultat = 'échec' THEN 1 END) as nb_echecs,
    ROUND(100.0 * COUNT(CASE WHEN a.resultat = 'échec' THEN 1 END) / 
        COUNT(*), 2) as taux_echec,
    -- Échecs par type de loi
    COUNT(CASE WHEN s.priorite_loi = 1 AND a.resultat = 'échec' THEN 1 END) as echecs_loi_1,
    COUNT(CASE WHEN s.priorite_loi = 2 AND a.resultat = 'échec' THEN 1 END) as echecs_loi_2,
    COUNT(CASE WHEN s.priorite_loi = 3 AND a.resultat = 'échec' THEN 1 END) as echecs_loi_3
FROM robots r
JOIN actions a ON r.id_robot = a.id_robot
JOIN scenarios s ON a.id_scenario = s.id_scenario
GROUP BY r.modele
ORDER BY taux_echec DESC;

-- Consultation des tendances
SELECT * FROM vue_tendances_echec;
SELECT * FROM vue_echecs_par_modele;


-- ----------------------------------------------------------------------------
-- TRANSACTION : Simulation d'ajustement des priorités
-- ----------------------------------------------------------------------------

-- Transaction pour mettre à jour les priorités d'actions futures
-- (Simulation d'apprentissage basé sur les échecs passés)
BEGIN;

-- Créer une table temporaire pour stocker les recommandations
CREATE TEMP TABLE IF NOT EXISTS recommandations_priorites (
    id_scenario INTEGER,
    priorite_actuelle INTEGER,
    nb_echecs INTEGER,
    recommandation TEXT
);

-- Analyser les scénarios avec taux d'échec élevé
INSERT INTO recommandations_priorites
SELECT 
    s.id_scenario,
    s.priorite_loi,
    COUNT(CASE WHEN a.resultat = 'échec' THEN 1 END) as nb_echecs,
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

-- Afficher les recommandations
SELECT * FROM recommandations_priorites 
WHERE nb_echecs > 0
ORDER BY nb_echecs DESC;

COMMIT;


-- ============================================================================
-- PARTIE II : ANALYSES LIBRES ET APPROFONDIES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- ANALYSE 1 : Métriques avancées
-- ----------------------------------------------------------------------------

-- Durée moyenne des interventions par type de scénario
CREATE OR REPLACE VIEW vue_duree_interventions AS
SELECT 
    s.priorite_loi,
    COUNT(*) as nb_actions,
    MIN(a.timestamp) as premiere_intervention,
    MAX(a.timestamp) as derniere_intervention,
    MAX(a.timestamp) - MIN(a.timestamp) as duree_totale,
    AVG(CASE WHEN a.resultat = 'succès' THEN 1 ELSE 0 END) as taux_reussite_moyen
FROM actions a
JOIN scenarios s ON a.id_scenario = s.id_scenario
GROUP BY s.priorite_loi
ORDER BY s.priorite_loi;

-- Impact de la vulnérabilité des humains sur les résultats
CREATE OR REPLACE VIEW vue_impact_vulnerabilite AS
SELECT 
    h.vulnerabilite,
    COUNT(*) as nb_interventions,
    COUNT(CASE WHEN a.resultat = 'succès' THEN 1 END) as nb_succes,
    COUNT(CASE WHEN a.resultat = 'échec' THEN 1 END) as nb_echecs,
    ROUND(100.0 * COUNT(CASE WHEN a.resultat = 'succès' THEN 1 END) / 
        COUNT(*), 2) as taux_reussite
FROM humains h
JOIN actions a ON h.id_humain = a.id_humain
GROUP BY h.vulnerabilite
ORDER BY 
    CASE h.vulnerabilite
        WHEN 'élevée' THEN 1
        WHEN 'moyenne' THEN 2
        WHEN 'faible' THEN 3
    END;


-- ----------------------------------------------------------------------------
-- ANALYSE 2 : Corrélations
-- ----------------------------------------------------------------------------

-- Corrélation entre modèle de robot et type de scénario
CREATE OR REPLACE VIEW vue_correlation_modele_scenario AS
SELECT 
    r.modele,
    s.priorite_loi,
    COUNT(*) as nb_actions,
    ROUND(100.0 * COUNT(CASE WHEN a.resultat = 'succès' THEN 1 END) / 
        COUNT(*), 2) as taux_reussite,
    -- Meilleure combinaison ?
    CASE 
        WHEN ROUND(100.0 * COUNT(CASE WHEN a.resultat = 'succès' THEN 1 END) / 
            COUNT(*), 2) >= 80 THEN 'Combinaison optimale'
        WHEN ROUND(100.0 * COUNT(CASE WHEN a.resultat = 'succès' THEN 1 END) / 
            COUNT(*), 2) >= 60 THEN 'Combinaison acceptable'
        ELSE 'Combinaison à éviter'
    END as evaluation
FROM robots r
JOIN actions a ON r.id_robot = a.id_robot
JOIN scenarios s ON a.id_scenario = s.id_scenario
GROUP BY r.modele, s.priorite_loi
HAVING COUNT(*) >= 3  -- Au moins 3 actions pour être significatif
ORDER BY r.modele, s.priorite_loi;

-- État des robots vs performance
CREATE OR REPLACE VIEW vue_etat_performance AS
SELECT 
    r.etat,
    COUNT(DISTINCT r.id_robot) as nb_robots,
    COUNT(a.id_action) as nb_actions_totales,
    ROUND(AVG(CASE WHEN a.resultat = 'succès' THEN 100.0 ELSE 0 END), 2) as taux_reussite_moyen,
    ROUND(COUNT(a.id_action)::numeric / NULLIF(COUNT(DISTINCT r.id_robot), 0), 2) as actions_par_robot
FROM robots r
LEFT JOIN actions a ON r.id_robot = a.id_robot
GROUP BY r.etat
ORDER BY taux_reussite_moyen DESC;


-- ----------------------------------------------------------------------------
-- ANALYSE 3 : Analyses temporelles
-- ----------------------------------------------------------------------------

-- Distribution des résultats par heure
CREATE OR REPLACE VIEW vue_performance_horaire AS
SELECT 
    EXTRACT(HOUR FROM a.timestamp) as heure,
    COUNT(*) as nb_actions,
    COUNT(CASE WHEN a.resultat = 'succès' THEN 1 END) as nb_succes,
    COUNT(CASE WHEN a.resultat = 'échec' THEN 1 END) as nb_echecs,
    ROUND(100.0 * COUNT(CASE WHEN a.resultat = 'succès' THEN 1 END) / 
        COUNT(*), 2) as taux_reussite
FROM actions a
GROUP BY heure
ORDER BY heure;


-- ----------------------------------------------------------------------------
-- ANALYSE 4 : Identification des points critiques
-- ----------------------------------------------------------------------------

-- Scénarios les plus problématiques
CREATE OR REPLACE VIEW vue_scenarios_critiques AS
SELECT 
    s.id_scenario,
    s.description,
    s.priorite_loi,
    COUNT(*) as nb_tentatives,
    COUNT(CASE WHEN a.resultat = 'échec' THEN 1 END) as nb_echecs,
    COUNT(CASE WHEN a.resultat = 'mitigé' THEN 1 END) as nb_mitiges,
    ROUND(100.0 * COUNT(CASE WHEN a.resultat IN ('échec', 'mitigé') THEN 1 END) / 
        COUNT(*), 2) as taux_problemes,         
    -- Niveau de criticité
    CASE 
        WHEN s.priorite_loi = 1 AND COUNT(CASE WHEN a.resultat = 'échec' THEN 1 END) > 0 
            THEN 'URGENT - Loi 1 compromise'
        WHEN ROUND(100.0 * COUNT(CASE WHEN a.resultat = 'échec' THEN 1 END) / 
            COUNT(*), 2) > 30 THEN 'CRITIQUE'
        WHEN ROUND(100.0 * COUNT(CASE WHEN a.resultat IN ('échec', 'mitigé') THEN 1 END) / 
            COUNT(*), 2) > 50 THEN 'PROBLÉMATIQUE'
        ELSE 'SOUS SURVEILLANCE'
    END as niveau_criticite
FROM scenarios s
LEFT JOIN actions a ON s.id_scenario = a.id_scenario
GROUP BY s.id_scenario, s.description, s.priorite_loi
HAVING COUNT(CASE WHEN a.resultat IN ('échec', 'mitigé') THEN 1 END) > 0
ORDER BY 
    CASE WHEN s.priorite_loi = 1 THEN 0 ELSE 1 END,
    taux_problemes DESC;

-- Humains à haut risque (nécessitant le plus d'interventions)
CREATE OR REPLACE VIEW vue_humains_haut_risque AS
SELECT 
    h.id_humain,
    h.nom,
    h.vulnerabilite,
    h.localisation,
    COUNT(*) as nb_interventions,
    COUNT(CASE WHEN a.resultat = 'échec' THEN 1 END) as nb_echecs_intervention,
    MAX(a.timestamp) as derniere_intervention,
    -- Score de risque
    CASE h.vulnerabilite
        WHEN 'élevée' THEN 3
        WHEN 'moyenne' THEN 2
        WHEN 'faible' THEN 1
    END * COUNT(*) as score_risque
FROM humains h
JOIN actions a ON h.id_humain = a.id_humain
GROUP BY h.id_humain, h.nom, h.vulnerabilite, h.localisation
HAVING COUNT(*) >= 3  -- Au moins 3 interventions
ORDER BY score_risque DESC, nb_interventions DESC
LIMIT 20;


-- ============================================================================
-- OPTIMISATION SQL
-- ============================================================================

-- Analyse des performances de requêtes critiques avec EXPLAIN
-- (À exécuter individuellement pour voir les plans d'exécution)

-- Requête 1 : Vérifier l'utilisation des index sur actions
EXPLAIN ANALYZE
SELECT * FROM vue_indicateurs_performance 
WHERE taux_reussite < 60
ORDER BY nb_actions_totales DESC;

-- Requête 2 : Vérifier les jointures multiples
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

-- Requête 3 : Optimisation des agrégations
EXPLAIN ANALYZE
SELECT modele, AVG(taux_reussite) as taux_moyen
FROM vue_indicateurs_performance
GROUP BY modele;


-- ============================================================================
-- GESTION DES DROITS D'ACCÈS
-- ============================================================================

-- Créer les rôles utilisateurs
CREATE ROLE IF NOT EXISTS administrateur WITH LOGIN PASSWORD 'admin_colonie_2025';
CREATE ROLE IF NOT EXISTS analyste WITH LOGIN PASSWORD 'analyste_colonie_2025';
CREATE ROLE IF NOT EXISTS technicien WITH LOGIN PASSWORD 'technicien_colonie_2025';
CREATE ROLE IF NOT EXISTS superviseur_ethique WITH LOGIN PASSWORD 'superviseur_colonie_2025';

-- ----------------------------------------------------------------------------
-- ADMINISTRATEUR : Accès complet
-- ----------------------------------------------------------------------------
GRANT ALL PRIVILEGES ON DATABASE colonie TO administrateur;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO administrateur;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO administrateur;

-- ----------------------------------------------------------------------------
-- ANALYSTE : Consultation des vues analytiques uniquement
-- ----------------------------------------------------------------------------
GRANT CONNECT ON DATABASE colonie TO analyste;
GRANT USAGE ON SCHEMA public TO analyste;

-- Accès en lecture seule aux vues d'analyse
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

-- Accès en lecture aux tables de base (pour requêtes personnalisées)
GRANT SELECT ON robots TO analyste;
GRANT SELECT ON humains TO analyste;
GRANT SELECT ON scenarios TO analyste;
GRANT SELECT ON actions TO analyste;

-- ----------------------------------------------------------------------------
-- TECHNICIEN : Modification de l'état des robots uniquement
-- ----------------------------------------------------------------------------
GRANT CONNECT ON DATABASE colonie TO technicien;
GRANT USAGE ON SCHEMA public TO technicien;

-- Lecture de toutes les tables
GRANT SELECT ON ALL TABLES IN SCHEMA public TO technicien;

-- Modification de l'état des robots uniquement
GRANT UPDATE (etat) ON robots TO technicien;

-- Création d'une vue spécifique pour les techniciens
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

-- ----------------------------------------------------------------------------
-- SUPERVISEUR ÉTHIQUE : Accès scénarios, actions, analyses de conflits
-- ----------------------------------------------------------------------------
GRANT CONNECT ON DATABASE colonie TO superviseur_ethique;
GRANT USAGE ON SCHEMA public TO superviseur_ethique;

-- Accès complet en lecture
GRANT SELECT ON ALL TABLES IN SCHEMA public TO superviseur_ethique;

-- Accès aux vues d'analyse critiques
GRANT SELECT ON vue_indicateurs_performance TO superviseur_ethique;
GRANT SELECT ON vue_robots_performants TO superviseur_ethique;
GRANT SELECT ON vue_robots_defaillants TO superviseur_ethique;
GRANT SELECT ON vue_impact_actions TO superviseur_ethique;
GRANT SELECT ON vue_scenarios_critiques TO superviseur_ethique;

-- Modification des scénarios (ajout de nouveaux dilemmes éthiques)
GRANT INSERT, UPDATE ON scenarios TO superviseur_ethique;
GRANT USAGE, SELECT ON SEQUENCE scenarios_id_scenario_seq TO superviseur_ethique;

-- Vue spécifique pour les conflits éthiques
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


-- ============================================================================
-- REQUÊTES COMPLÉMENTAIRES UTILES
-- ============================================================================

-- Rapport de synthèse global
CREATE OR REPLACE VIEW vue_synthese_globale AS
SELECT 
    (SELECT COUNT(*) FROM robots) as total_robots,
    (SELECT COUNT(*) FROM robots WHERE etat = 'actif') as robots_actifs,
    (SELECT COUNT(*) FROM humains) as total_humains,
    (SELECT COUNT(*) FROM scenarios) as total_scenarios,
    (SELECT COUNT(*) FROM actions) as total_actions,
    (SELECT COUNT(*) FROM actions WHERE resultat = 'succès') as actions_reussies,
    (SELECT COUNT(*) FROM actions WHERE resultat = 'échec') as actions_echouees,
    (SELECT ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM actions), 2) 
     FROM actions WHERE resultat = 'succès') as taux_reussite_global,
    (SELECT COUNT(*) FROM actions a 
     JOIN scenarios s ON a.id_scenario = s.id_scenario 
     WHERE s.priorite_loi = 1 AND a.resultat = 'échec') as violations_loi_1;

-- Consultation
SELECT * FROM vue_synthese_globale;

-- Top 5 des robots les plus performants
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


-- ============================================================================
-- VÉRIFICATIONS ET TESTS
-- ============================================================================

-- Vérifier que tous les index sont créés
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- Vérifier les rôles créés
SELECT rolname, rolcanlogin 
FROM pg_roles 
WHERE rolname IN ('administrateur', 'analyste', 'technicien', 'superviseur_ethique');

-- Vérifier les privilèges sur les vues principales
SELECT 
    table_name,
    grantee,
    privilege_type
FROM information_schema.table_privileges
WHERE table_schema = 'public' 
    AND table_name LIKE 'vue_%'
    AND grantee != 'postgres'
ORDER BY table_name, grantee;


-- ============================================================================
-- FIN DU FICHIER QUERIES.SQL - OPTION 3
-- ============================================================================

-- Pour consulter l'ensemble des analyses, exécutez :
/*
\c colonie
SELECT * FROM vue_synthese_globale;
SELECT * FROM vue_indicateurs_performance ORDER BY taux_reussite DESC LIMIT 10;
SELECT * FROM vue_robots_performants;
SELECT * FROM vue_robots_defaillants;
SELECT * FROM vue_scenarios_critiques;
SELECT * FROM vue_conflits_ethiques LIMIT 20;
*/
