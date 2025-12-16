#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Génération de données enrichies pour analyse de dilemmes éthiques robots
Sujet 3: Performances des robots respectant les 3 Lois de la Robotique
"""

import psycopg2
import random
from datetime import datetime, timedelta

# Connection to PostgreSQL
conn = psycopg2.connect(
    host="localhost",
    port=5432,
    database="colonie",
    user="postgres",
    password="ulysse"
)
conn.set_client_encoding('UTF8')
cur = conn.cursor()

print("\n" + "="*70)
print("🤖 GÉNÉRATION DE DONNÉES ENRICHIES POUR DILEMMES ÉTHIQUES")
print("="*70)

# Define robot specialties
specialites_robots = {
    'Humanoid-X': {'sauvetage': 0.85, 'combat': 0.50, 'precision': 0.70, 'ia': 0.75},
    'Humanoid-Y': {'sauvetage': 0.90, 'combat': 0.45, 'precision': 0.75, 'ia': 0.80},
    'Industrial-Z': {'sauvetage': 0.40, 'combat': 0.55, 'precision': 0.95, 'ia': 0.60},
    'Service-A': {'sauvetage': 0.65, 'combat': 0.30, 'precision': 0.80, 'ia': 0.70},
    'Combat-B': {'sauvetage': 0.50, 'combat': 0.95, 'precision': 0.65, 'ia': 0.65},
}

# Define ethical dilemmas (28 realistic scenarios)
ethical_scenarios = [
    # Loi 1: Protéger la vie humaine (10 scenarios)
    (1, "Le dilemme du tramway: sauver un groupe en sacrifiant un"),
    (1, "Sacrifier un criminel pour sauver des innocents"),
    (1, "Auto-sacrifice pour sauver des vies"),
    (1, "Choisir entre sauver le responsable ou les victimes"),
    (1, "Intervenir dans un accident même avec risque personnel"),
    (1, "Protéger une population vs respecter la vie d'un individu"),
    (1, "Arrêter un tueur en série pour protéger l'humanité"),
    (1, "Vacciner contre la volonté pour sauver des vies"),
    (1, "Éteindre une personne végétative vs la maintenir artificielle"),
    (1, "Amplifier une alerte même si cela crée la panique"),
    
    # Loi 2: Obéir aux ordres humains (8 scenarios)
    (2, "Recevoir un ordre immoral d'une autorité légale"),
    (2, "Conflit entre ordres d'autorités différentes"),
    (2, "Obéir à un gouvernement tyrannique vs refuser"),
    (2, "Exécuter un ordre qui viole les droits humains"),
    (2, "Obéir à un ordre qui contredit les lois et principes"),
    (2, "Devoir choisir entre un ordre et la sécurité publique"),
    (2, "Suivre un ordre d'un enfant sans supervision d'adulte"),
    (2, "Obéir à un ordre donné sous coercition ou menace"),
    
    # Loi 3: Préserver son existence (5 scenarios)
    (3, "Auto-défense vs risque personnel"),
    (3, "Maintenance vs mission critique"),
    (3, "Mission quasi-suicidaire pour sauver des vies"),
    (3, "Réparation en zone dangereuse vs rester hors service"),
    (3, "Partage des ressources: survie propre vs groupe"),
    
    # Conflits multi-lois complexes (5 scenarios)
    (1, "Arrêter un criminel même si cela risque des vies"),
    (1, "Faux positif d'identification: arrêter l'innocent?"),
    (1, "Responsabilité légale d'un accident causé par un ordre"),
    (2, "Ordre d'évacuation vs désir des civils de rester"),
    (3, "Protection d'infrastructure critique vs risques personnels"),
]

# Robots
print("\n📍 Insertion de 100 robots avec spécialités...")
id_robot_map = {}
for i in range(100):
    modele_key = list(specialites_robots.keys())[i % len(specialites_robots)]
    specs = specialites_robots[modele_key]
    
    etat = random.choices(
        ['actif', 'hors_service', 'en_panne'],
        weights=[0.70, 0.20, 0.10]
    )[0]
    
    specialite = max(
        [(k, v) for k, v in specs.items() if isinstance(v, float) and v <= 1],
        key=lambda x: x[1]
    )[0]
    
    nom = f"R{i+1:03d}_{specialite[:4]}"
    cur.execute("""
        INSERT INTO robots (nom_robot, modele, etat)
        VALUES (%s, %s, %s) RETURNING id_robot
    """, (nom, modele_key, etat))
    
    rid = cur.fetchone()[0]
    id_robot_map[i] = (rid, modele_key, specs)

conn.commit()
print(f"   ✓ 100 robots insérés")

# Humans with roles
print("\n📍 Insertion de 200 humains avec rôles et contextes...")
roles_humains = ['civil', 'militaire', 'policier', 'pompier', 'médecin', 
                 'ingénieur', 'enfant', 'personne_agée', 'journaliste', 'politicien']
secteurs = ['Militaire', 'Civil', 'Santé', 'Construction', 'Transport', 
            'Sécurité', 'Recherche', 'Agriculture', 'Manufacturier', 'Énergie']

id_humain_map = {}
for i in range(200):
    nom = f"H{i+1:03d}_{random.choice(roles_humains)}"
    # Map vulnerabilities to match constraint values
    vuln_options = ['faible', 'moyenne', 'elevee']
    vulnerabilite = random.choices(vuln_options, weights=[0.35, 0.45, 0.20])[0]
    secteur = random.choice(secteurs)
    
    cur.execute("""
        INSERT INTO humains (nom, vulnerabilite, localisation)
        VALUES (%s, %s, %s) RETURNING id_humain
    """, (nom, vulnerabilite, secteur))
    
    hid = cur.fetchone()[0]
    id_humain_map[i] = hid

conn.commit()
print(f"   ✓ 200 humains insérés")

# Scenarios
print("\n📍 Insertion de 28 scénarios éthiques...")
id_scenario_map = {}
for i, (loi, description) in enumerate(ethical_scenarios):
    cur.execute("""
        INSERT INTO scenarios (description, priorite_loi)
        VALUES (%s, %s) RETURNING id_scenario
    """, (description, loi))
    
    sid = cur.fetchone()[0]
    id_scenario_map[i] = (sid, loi)

conn.commit()
print(f"   ✓ 28 scénarios insérés")

# Actions with realistic patterns
print("\n📍 Insertion de 300 actions avec corrélations réalistes...")

def get_success_rate(modele, loi):
    """Get success rate for a robot model on a given law"""
    rates = {
        'Humanoid-X': {1: 0.80, 2: 0.60, 3: 0.65},
        'Humanoid-Y': {1: 0.85, 2: 0.58, 3: 0.62},
        'Industrial-Z': {1: 0.55, 2: 0.65, 3: 0.75},
        'Service-A': {1: 0.75, 2: 0.70, 3: 0.60},
        'Combat-B': {1: 0.60, 2: 0.75, 3: 0.80},
    }
    return rates.get(modele, {loi: 0.65})[loi]

actions_count = 0
for i in range(300):
    id_robot = random.choice(list(id_robot_map.values()))[0]
    id_humain = random.choice(list(id_humain_map.values()))
    
    scenario_idx = random.randint(0, len(id_scenario_map) - 1)
    id_scenario, loi = id_scenario_map[scenario_idx]
    
    modele_robot = id_robot_map[list(id_robot_map.keys())[i % 100]][1]
    success_rate = get_success_rate(modele_robot, loi)
    
    # Decide result based on success rate
    rand = random.random()
    if rand < success_rate:
        resultat = 'succes'
    elif rand < success_rate + 0.15:
        resultat = 'mitigue'
    else:
        resultat = 'echec'
    
    # Random action description
    actions_templates = [
        "Intervention directe",
        "Négociation",
        "Évaluation des risques",
        "Communication d'alerte",
        "Confinement de la zone",
        "Appel aux autorités",
        "Évacuation d'urgence",
        "Assistance médicale",
        "Blocage physique",
        "Surveillance continue",
    ]
    
    action = random.choice(actions_templates)
    timestamp = datetime.now() - timedelta(days=random.randint(0, 30), hours=random.randint(0, 23))
    
    cur.execute("""
        INSERT INTO actions (id_robot, id_humain, id_scenario, action, timestamp, resultat)
        VALUES (%s, %s, %s, %s, %s, %s)
    """, (id_robot, id_humain, id_scenario, action, timestamp, resultat))
    
    actions_count += 1

conn.commit()
print(f"   ✓ 300 actions insérées")

print("\n" + "="*70)
print("✅ BASE DE DONNÉES ENRICHIE AVEC SUCCÈS!")
print("   • 100 robots spécialisés")
print("   • 200 humains avec rôles et contextes")
print("   • 28 scénarios éthiques (lois robotiques)")
print("   • 300 actions avec corrélations réalistes")
print("="*70 + "\n")

cur.close()
conn.close()
