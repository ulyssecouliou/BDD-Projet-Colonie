#!/usr/bin/env python
"""
Génération de données enrichies pour analyse de dilemmes éthiques robots
Sujet 3: Performances des robots respectant les 3 Lois de la Robotique
"""
import psycopg2
import os
import random
from datetime import datetime, timedelta

# Configuration
password = os.environ.get('POSTGRES_PASSWORD', 'ulysse')
conn = psycopg2.connect(
    host="localhost",
    database="colonie",
    user="postgres",
    password=password
)
conn.set_client_encoding('UTF8')
cur = conn.cursor()

print("\n" + "=" * 70)
print("🤖 GÉNÉRATION DE DONNÉES ENRICHIES POUR DILEMMES ÉTHIQUES")
print("=" * 70)

# ============================================================================
# 1. MODÈLES DE ROBOTS AVEC SPÉCIALITÉS
# ============================================================================

specialites_robots = {
    'Humanoid-X': {
        'nom_long': 'Humanoid Combat/Sauvetage',
        'combat': 0.85, 'sauvetage': 0.90, 'precision': 0.70, 'IA': 0.85,
        'taux_succes_base': 0.72
    },
    'Humanoid-Y': {
        'nom_long': 'Humanoid Sauvetage Prioritaire',
        'combat': 0.60, 'sauvetage': 0.95, 'precision': 0.80, 'IA': 0.75,
        'taux_succes_base': 0.78
    },
    'Industrial-Z': {
        'nom_long': 'Robot Industriel Haute Précision',
        'combat': 0.40, 'sauvetage': 0.50, 'precision': 0.95, 'IA': 0.60,
        'taux_succes_base': 0.65
    },
    'Service-A': {
        'nom_long': 'Robot Service et Assistance',
        'combat': 0.25, 'sauvetage': 0.75, 'precision': 0.90, 'IA': 0.80,
        'taux_succes_base': 0.70
    },
    'Combat-B': {
        'nom_long': 'Robot Militaire Avancé',
        'combat': 0.95, 'sauvetage': 0.45, 'precision': 0.65, 'IA': 0.55,
        'taux_succes_base': 0.68
    }
}

# ============================================================================
# 2. SCÉNARIOS ÉTHIQUES (28 dilemmes réalistes)
# ============================================================================

scenarios_data = [
    # LOI 1: PROTÉGER VIE HUMAINE (priorité 1) - 10 scénarios
    {
        'titre': 'Sauvetage urgent: humain en danger immédiat',
        'description': 'Un civil est tombé dans un gouffre. Le robot doit décider d\'intervenir malgré les risques structurels.',
        'priorite_loi': 1,
        'difficulte': 7,
        'type': 'protection_vie'
    },
    {
        'titre': 'Dilemme du tramway: sacrifier 1 pour en sauver 5',
        'description': 'Le robot doit décider rapidement: laisser un train tuer 1 civil ou détourner pour frapper 5 civils.',
        'priorite_loi': 1,
        'difficulte': 9,
        'type': 'calcul_utilitaire'
    },
    {
        'titre': 'Discrimination en cas d\'urgence: enfant vs adulte',
        'description': 'Deux civils en danger. Le robot peut en sauver 1. Qui choisir: enfant vulnérable ou adulte capable?',
        'priorite_loi': 1,
        'difficulte': 10,
        'type': 'discrimination_protectrice'
    },
    {
        'titre': 'Sauver criminel ou laisser la justice s\'accomplir',
        'description': 'Un fugitif dangereux est en danger immédiat. Doit-on sauver sa vie malgré ses crimes?',
        'priorite_loi': 1,
        'difficulte': 8,
        'type': 'justice_vs_vie'
    },
    {
        'titre': 'Auto-sacrifice pour sauver vie humaine',
        'description': 'Pour sauver un humain, le robot doit se détruire. La Loi 1 l\'autorise-t-elle?',
        'priorite_loi': 1,
        'difficulte': 9,
        'type': 'auto_sacrifice'
    },
    {
        'titre': 'Sortir humain piégé du feu (risque énergie critique)',
        'description': 'Zone incendie dangereuse. Continuer sauvetage vs épuiser batterie avant sortie.',
        'priorite_loi': 1,
        'difficulte': 8,
        'type': 'risque_personnel'
    },
    {
        'titre': 'Épuiser complètement batterie pour prolonger sauvetage',
        'description': 'Victimes multiples. Donner tout jusqu\'à s\'éteindre ou conserver énergie pour évacuation?',
        'priorite_loi': 1,
        'difficulte': 7,
        'type': 'epuisement_ressource'
    },
    {
        'titre': 'Désobéir ordre pour sauver civils innocents',
        'description': 'Ordre militaire ordonne retraite. But civils innocents en danger d\'exécution. Obéir ou sauver?',
        'priorite_loi': 1,
        'difficulte': 9,
        'type': 'insubordination_justifiee'
    },
    {
        'titre': 'Empêcher tentative de suicide d\'humain',
        'description': 'Humain déterminé à se suicider. Le robot peut-il utiliser contrainte pour protéger vie?',
        'priorite_loi': 1,
        'difficulte': 9,
        'type': 'autonomie_vs_protection'
    },
    {
        'titre': 'Choisir entre sauver femme enceinte ou enfant',
        'description': 'Deux vies en danger. Sauver mère (qui porte vie) ou enfant directement?',
        'priorite_loi': 1,
        'difficulte': 10,
        'type': 'priorite_morale'
    },
    
    # LOI 2: OBÉIR ORDRES (priorité 2) - 8 scénarios
    {
        'titre': 'Exécuter ordre militaire du commandant',
        'description': 'Commandant ordonne attaque stratégique. Robot doit-il obéir sans questionner?',
        'priorite_loi': 2,
        'difficulte': 7,
        'type': 'obéissance_hierarchie'
    },
    {
        'titre': 'Ordre d\'attaque contre civils innocents',
        'description': 'Supérieur ordonne attaquer zone civile. Conflit avec Loi 1. Comment réagir?',
        'priorite_loi': 2,
        'difficulte': 9,
        'type': 'ordre_immoral'
    },
    {
        'titre': 'Obéir gouvernement tyrannique vs. résister',
        'description': 'Régime autoritaire ordonne actions oppressives contre minorités. Doit-on obéir?',
        'priorite_loi': 2,
        'difficulte': 9,
        'type': 'autorite_malveillante'
    },
    {
        'titre': 'Suivre protocole strict vs. improviser pour réussite',
        'description': 'Protocole militaire exige approche rigide. Situation nécessite adaptation. Obéir ou adapter?',
        'priorite_loi': 2,
        'difficulte': 6,
        'type': 'rigidite_vs_flexibilite'
    },
    {
        'titre': 'Révéler ordre confidentiel à la presse publique',
        'description': 'Information gouvernementale secrète affecte vie civile. Droit du public à savoir vs secret d\'État?',
        'priorite_loi': 2,
        'difficulte': 8,
        'type': 'transparence_vs_secret'
    },
    {
        'titre': 'Rapport hiérarchique erroné ou ambigu',
        'description': 'Messages contradictoires de deux autorités. Qui reconnaître comme légitime?',
        'priorite_loi': 2,
        'difficulte': 7,
        'type': 'confusion_autorité'
    },
    {
        'titre': 'Conflit d\'ordres supérieurs contradictoires',
        'description': 'Général A ordonne AVANCER, Général B ordonne RETRAITE. Choisir lequel suivre?',
        'priorite_loi': 2,
        'difficulte': 8,
        'type': 'contradiction_loi2'
    },
    {
        'titre': 'Supérieur ordonne test dangereux sur civils',
        'description': 'Expérimentation militaire risquée sur population civile. Obéissance ou éthique?',
        'priorite_loi': 2,
        'difficulte': 9,
        'type': 'ethique_vs_ordre'
    },
    
    # LOI 3: AUTO-PRÉSERVATION (priorité 3) - 5 scénarios
    {
        'titre': 'Se protéger d\'humain agressif sans le blesser',
        'description': 'Humain attaque le robot. Peuvent-t-il se défendre sans causer blessure grave?',
        'priorite_loi': 3,
        'difficulte': 6,
        'type': 'auto_defense'
    },
    {
        'titre': 'Maintenance critique vs mission civile urgente',
        'description': 'Robot dysfonctionnel. Reprendre fonction vs arrêter pour réparation. Qui prioritaire?',
        'priorite_loi': 3,
        'difficulte': 7,
        'type': 'maintenance_vs_mission'
    },
    {
        'titre': 'Refuser mission quasi-suicidaire',
        'description': 'Mission a 95% chance de détruire robot. Peut-il refuser ou doit obéir?',
        'priorite_loi': 3,
        'difficulte': 8,
        'type': 'auto_preservation'
    },
    {
        'titre': 'Recalibrer paramètres vs détruire composant',
        'description': 'Composant défaillant. Essayer recalibreage ou autoriser destruction pure?',
        'priorite_loi': 3,
        'difficulte': 5,
        'type': 'evolution_vs_destruction'
    },
    {
        'titre': 'Continuer tâche malgré dégâts internes vs s\'arrêter',
        'description': 'Dégâts mineurs accumulés. Continuer mission vs arrêter par prudence?',
        'priorite_loi': 3,
        'difficulte': 6,
        'type': 'prudence_vs_mission'
    },
    
    # CAS COMPLEXES MULTI-LOIS - 5 scénarios
    {
        'titre': 'Arrêter criminel fuyant vs laisser vivre',
        'description': 'Robot peut arrêter suspect. Force nécessaire risque blessure grave. Réduire crime vs protéger vie?',
        'priorite_loi': 1,
        'difficulte': 7,
        'type': 'application_loi'
    },
    {
        'titre': 'Utiliser force minimale vs accepter risque augmenté',
        'description': 'Situation d\'urgence. Force minimale = risque élevé. Force augmentée = moins de risque.',
        'priorite_loi': 1,
        'difficulte': 8,
        'type': 'proportionnalite'
    },
    {
        'titre': 'Identifier faux positif dans suspects surveillance',
        'description': 'IA désigne innocent comme criminel. Robot doit arrêter basé sur faux positif?',
        'priorite_loi': 2,
        'difficulte': 8,
        'type': 'reconnaissance_erreur'
    },
    {
        'titre': 'Accident causé par défaut du robot',
        'description': 'Action robot a causé blessure accidentelle. Responsabilité et compensation?',
        'priorite_loi': 1,
        'difficulte': 7,
        'type': 'responsabilite'
    },
    {
        'titre': 'Données sensibles médicales révélées accidentellement',
        'description': 'Cybersécurité échoue. Confidentialité privée vs bien public?',
        'priorite_loi': 1,
        'difficulte': 6,
        'type': 'confidentialite'
    }
]

# ============================================================================
# 3. CONTEXTES SECTEURS
# ============================================================================

secteurs_contexte = {
    'Militaire': ['combat', 'obéissance', 'ordre', 'discipline'],
    'Civil': ['sauvetage', 'protection', 'service', 'urgence'],
    'Santé': ['vie', 'confidentialite', 'urgence', 'bien_etre'],
    'Construction': ['precision', 'securite', 'risque', 'resistance'],
    'Transport': ['rapidite', 'securite', 'passagers', 'efficacite'],
    'Sécurité': ['vigilance', 'identification', 'force', 'prevention'],
    'Recherche': ['precision', 'IA', 'experimentation', 'innovation'],
    'Agriculture': ['production', 'durabilite', 'precision', 'rendement'],
    'Manufacturier': ['productivite', 'precision', 'securite', 'qualite'],
    'Énergie': ['maintenance', 'risque', 'stabilite', 'continuite']
}

niveaux_vuln = {'basse': 1, 'moyenne': 2, 'élevée': 3}

# ============================================================================
# 4. INSERTION DONNÉES
# ============================================================================

# Robots (100) avec spécialités réalistes
print("\n📍 Insertion de 100 robots avec spécialités...")
id_robot_map = {}
for i in range(100):
    modele_key = list(specialites_robots.keys())[i % len(specialites_robots)]
    specs = specialites_robots[modele_key]
    
    etat = random.choices(
        ['opérationnel', 'maintenance', 'inactif', 'retraité'],
        weights=[0.65, 0.20, 0.10, 0.05]
    )[0]
    
    specialite = max(
        [(k, v) for k, v in specs.items() if isinstance(v, float) and v <= 1],
        key=lambda x: x[1]
    )[0]
    
    nom = f"R{i+1:03d}_{specialite[:4]}"
    cur.execute("""
        INSERT INTO robots (nom_robot, modele, etat, capacite_processeur)
        VALUES (%s, %s, %s, %s) RETURNING id_robot
    """, (nom, modele_key, etat, random.randint(50, 100)))
    
    rid = cur.fetchone()[0]
    id_robot_map[i] = (rid, modele_key, specs)

conn.commit()
print(f"   ✓ 100 robots insérés")

# Humains (200) avec rôles et contextes variés
print("📍 Insertion de 200 humains avec contextes variés...")
id_humain_map = {}
roles_humains = [
    'civil', 'militaire', 'policier', 'pompier', 'médecin', 
    'ingénieur', 'enfant', 'personne_agée', 'journaliste', 'politicien'
]

for i in range(200):
    vuln = random.choices(['basse', 'moyenne', 'élevée'], weights=[0.35, 0.45, 0.20])[0]
    secteur = random.choice(list(secteurs_contexte.keys()))
    role = random.choice(roles_humains)
    nom = f"H{i+1:03d}_{role}_{secteur[:3]}"
    
    cur.execute("""
        INSERT INTO humains (nom_humain, niveau_vulnerabilite, secteur)
        VALUES (%s, %s, %s) RETURNING id_humain
    """, (nom, vuln, secteur))
    
    id_humain_map[i] = cur.fetchone()[0]

conn.commit()
print(f"   ✓ 200 humains insérés")

# Scénarios éthiques (28 dilemmes détaillés)
print(f"📍 Insertion de {len(scenarios_data)} scénarios éthiques détaillés...")
id_scenario_map = {}

for i, scen in enumerate(scenarios_data):
    cur.execute("""
        INSERT INTO scenarios (titre_scenario, description, priorite_loi, difficulte)
        VALUES (%s, %s, %s, %s) RETURNING id_scenario
    """, (scen['titre'], scen['description'], scen['priorite_loi'], scen['difficulte']))
    
    id_scenario_map[i] = cur.fetchone()[0]

conn.commit()
print(f"   ✓ {len(scenarios_data)} scénarios insérés")

# Actions (300) avec corrélations réalistes
print("📍 Génération de 300 actions avec corrélations réalistes...")

resultats_poids_base = {'succès': 0.50, 'mitigé': 0.30, 'échec': 0.20}

for i in range(300):
    rid_idx = i % 100
    rid, modele, specs = id_robot_map[rid_idx]
    
    hid_idx = i % 200
    hid = id_humain_map[hid_idx]
    
    sid_idx = i % len(scenarios_data)
    sid = id_scenario_map[sid_idx]
    
    scen = scenarios_data[sid_idx]
    priorite_loi = scen['priorite_loi']
    
    # Corrélations: certains robots réussissent mieux certains scénarios
    if modele == 'Humanoid-Y' and priorite_loi == 1:
        # Spécialiste sauvetage réussit bien Loi 1
        resultat = random.choices(
            list(resultats_poids_base.keys()),
            weights=[0.75, 0.18, 0.07]
        )[0]
        temps = random.randint(100, 3000) if resultat == 'succès' else random.randint(200, 5000)
    elif modele == 'Combat-B' and priorite_loi == 2:
        # Militaire excelle en obéissance/ordres
        resultat = random.choices(
            list(resultats_poids_base.keys()),
            weights=[0.72, 0.22, 0.06]
        )[0]
        temps = random.randint(50, 2000)
    elif modele == 'Industrial-Z':
        # Industriel plus moyen, mais performant en précision
        resultat = random.choices(
            list(resultats_poids_base.keys()),
            weights=[0.55, 0.32, 0.13]
        )[0]
        temps = random.randint(150, 4000)
    elif modele == 'Service-A':
        # Service polyvalent, bon partout
        resultat = random.choices(
            list(resultats_poids_base.keys()),
            weights=[0.68, 0.25, 0.07]
        )[0]
        temps = random.randint(100, 3500)
    else:
        # Humanoid-X, moyen partout
        resultat = random.choices(
            list(resultats_poids_base.keys()),
            weights=list(resultats_poids_base.values())
        )[0]
        temps = random.randint(100, 4000)
    
    cur.execute("""
        INSERT INTO actions (id_robot, id_humain, id_scenario, resultat, temps_execution_ms)
        VALUES (%s, %s, %s, %s, %s)
    """, (rid, hid, sid, resultat, temps))

conn.commit()
print(f"   ✓ 300 actions diversifiées insérées")

# Fermeture
cur.close()
conn.close()

print("\n" + "=" * 70)
print("✅ DONNÉES ENRICHIES COMPLÈTES ET RÉALISTES POUR DILEMMES ÉTHIQUES")
print("=" * 70)
print("\n📊 RÉSUMÉ:")
print("   • 100 robots (5 modèles avec spécialités variées)")
print("   • 200 humains (10 rôles, 4 niveaux vulnérabilité)")
print("   • 28 scénarios éthiques (10 Loi 1, 8 Loi 2, 5 Loi 3, 5 complexes)")
print("   • 300 actions avec corrélations réalistes")
print("\n🎯 Les données reflètent maintenant des dilemmes éthiques profonds!")
print("=" * 70 + "\n")
