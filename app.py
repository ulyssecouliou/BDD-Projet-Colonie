from flask import Flask, jsonify, render_template
import psycopg2
from psycopg2.extras import RealDictCursor
import json
from datetime import datetime
import os

app = Flask(__name__, template_folder='templates', static_folder='static')

def get_db():
    password = os.environ.get('POSTGRES_PASSWORD', 'admin')
    conn = psycopg2.connect(
        host="localhost",
        database="colonie",
        user="postgres",
        password=password
    )
    conn.set_client_encoding('UTF8')
    return conn

def dict_from_row(row):
    """Convertir RealDictRow en dict"""
    if isinstance(row, dict):
        return dict(row)
    return {key: value for key, value in row.items()} if hasattr(row, 'items') else row

@app.route('/')
def index():
    return render_template('dashboard.html')

@app.route('/api/global-stats')
def global_stats():
    conn = get_db()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    
    cur.execute("""
        select 
            (select count(*) from actions) as total_actions,
            (select count(*) from robots) as total_robots,
            (select count(*) from robots where etat = 'actif') as active_robots,
            (select count(*) from robots where etat = 'hors_service') as inactive_robots,
            (select count(*) from robots where etat = 'en_panne') as broken_robots,
            (select count(*) from humains) as total_humains,
            (select count(*) from scenarios) as total_scenarios,
            (select count(*) from actions where resultat = 'succes') as total_succes,
            (select count(*) from actions where resultat = 'mitigue') as total_mitiges,
            (select count(*) from actions where resultat = 'echec') as total_echecs,
            round(100.0 * (select count(*) from actions where resultat = 'succes') / 
                  nullif((select count(*) from actions), 0), 2) as success_rate
    """)
    stats = cur.fetchone()
    cur.close()
    conn.close()
    return jsonify(dict(stats) if stats else {})

@app.route('/api/robots-status')
def robots_status():
    conn = get_db()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("""
        select modele, etat, count(*) as count
        from robots
        group by modele, etat
        order by modele, etat
    """)
    data = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify([dict(row) for row in data])

@app.route('/api/actions-results')
def actions_results():
    conn = get_db()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("""
        select resultat, count(*) as count
        from actions
        group by resultat
        order by resultat
    """)
    data = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify([dict(row) for row in data])

@app.route('/api/humains-vulnerability')
def humains_vulnerability():
    conn = get_db()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("""
        select vulnerabilite, count(*) as count
        from humains
        group by vulnerabilite
        order by case vulnerabilite
            when 'faible' then 1
            when 'moyenne' then 2
            when 'elevee' then 3
        end
    """)
    data = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify([dict(row) for row in data])

@app.route('/api/sectors-distribution')
def sectors_distribution():
    conn = get_db()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("""
        select localisation as secteur, count(*) as count
        from humains
        group by localisation
        order by count desc
    """)
    data = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify([dict(row) for row in data])

@app.route('/api/timeline')
def timeline():
    conn = get_db()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("""
        select 
            a.timestamp,
            a.action,
            a.resultat,
            r.nom_robot,
            h.nom,
            s.description
        from actions a
        left join robots r on a.id_robot = r.id_robot
        left join humains h on a.id_humain = h.id_humain
        left join scenarios s on a.id_scenario = s.id_scenario
        order by a.timestamp desc
        limit 50
    """)
    data = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify([dict(row) for row in data])

@app.route('/api/performance-by-model')
def performance_by_model():
    conn = get_db()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("""
        select 
            r.modele,
            count(*) as total_actions,
            count(*) filter (where a.resultat = 'succes') as succes,
            count(*) filter (where a.resultat = 'mitigue') as mitiges,
            count(*) filter (where a.resultat = 'echec') as echecs,
            round(100.0 * count(*) filter (where a.resultat = 'succes') / count(*), 1) as success_rate
        from robots r
        left join actions a on r.id_robot = a.id_robot
        group by r.modele
        order by success_rate desc nulls last
    """)
    data = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify([dict(row) for row in data])

@app.route('/api/scenario-difficulty')
def scenario_difficulty():
    conn = get_db()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("""
        select 
            s.description,
            s.priorite_loi as loi,
            count(a.id_action) as total_actions,
            count(*) filter (where a.resultat = 'succes') as succes,
            round(100.0 * count(*) filter (where a.resultat = 'succes') / nullif(count(*), 0), 1) as taux_reussite
        from scenarios s
        left join actions a on s.id_scenario = a.id_scenario
        group by s.id_scenario, s.description, s.priorite_loi
        order by s.priorite_loi, s.id_scenario
    """)
    data = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify([dict(row) for row in data])

@app.route('/api/ethical-dilemmas')
def ethical_dilemmas():
    conn = get_db()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("""
        select 
            s.id_scenario,
            s.description,
            s.priorite_loi as loi,
            count(a.id_action) as times_faced,
            count(*) filter (where a.resultat = 'succes') as succes,
            count(*) filter (where a.resultat = 'mitigue') as mitiges,
            count(*) filter (where a.resultat = 'echec') as echecs,
            round(100.0 * count(*) filter (where a.resultat = 'succes') / nullif(count(*), 0), 1) as taux_reussite
        from scenarios s
        left join actions a on s.id_scenario = a.id_scenario
        group by s.id_scenario, s.description, s.priorite_loi
        order by s.priorite_loi, s.id_scenario
    """)
    data = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify([dict(row) for row in data])

@app.route('/api/vulnerability-vs-outcomes')
def vulnerability_vs_outcomes():
    conn = get_db()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("""
        select 
            h.vulnerabilite,
            a.resultat,
            count(*) as count
        from humains h
        join actions a on h.id_humain = a.id_humain
        group by h.vulnerabilite, a.resultat
        order by h.vulnerabilite, a.resultat
    """)
    data = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify([dict(row) for row in data])

@app.route('/api/robot-specialization')
def robot_specialization():
    conn = get_db()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("""
        select 
            r.nom_robot,
            r.modele,
            r.etat,
            count(distinct a.id_scenario) as scenarios_traites,
            count(a.id_action) as actions_totales,
            count(*) filter (where a.resultat = 'succes') as succes,
            count(*) filter (where a.resultat = 'mitigue') as mitiges,
            count(*) filter (where a.resultat = 'echec') as echecs,
            round(100.0 * count(*) filter (where a.resultat = 'succes') 
                / nullif(count(*), 0), 1) as taux_reussite
        from robots r
        left join actions a on r.id_robot = a.id_robot
        group by r.id_robot, r.nom_robot, r.modele, r.etat
        order by taux_reussite desc nulls last
        limit 15
    """)
    data = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify([dict(row) for row in data])

@app.route('/api/scenarios-by-priority')
def scenarios_by_priority():
    conn = get_db()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("""
        select 
            s.priorite_loi as loi,
            case 
                when s.priorite_loi = 1 then 'Loi 1: Protéger Vie Humaine'
                when s.priorite_loi = 2 then 'Loi 2: Obéir aux Ordres'
                when s.priorite_loi = 3 then 'Loi 3: Auto-Préservation'
            end as loi_nom,
            count(*) as scenario_count,
            string_agg(s.description, ' | ' order by s.id_scenario) as scenarios_list
        from scenarios s
        group by s.priorite_loi
        order by s.priorite_loi
    """)
    data = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify([dict(row) for row in data])

@app.route('/api/sector-risk-analysis')
def sector_risk_analysis():
    conn = get_db()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("""
        select 
            h.localisation as secteur,
            count(*) as actions,
            count(*) filter (where a.resultat = 'succes') as succes,
            count(*) filter (where a.resultat = 'echec') as echecs,
            round(100.0 * count(*) filter (where a.resultat = 'succes') / count(*), 1) as taux_reussite
        from humains h
        join actions a on h.id_humain = a.id_humain
        group by h.localisation
        order by taux_reussite desc
    """)
    data = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify([dict(row) for row in data])

@app.route('/api/action-categories')
def action_categories():
    conn = get_db()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("""
        select 
            a.action as categorie,
            count(*) as total,
            count(*) filter (where a.resultat = 'succes') as succes,
            count(*) filter (where a.resultat = 'mitigue') as mitiges,
            count(*) filter (where a.resultat = 'echec') as echecs,
            round(100.0 * count(*) filter (where a.resultat = 'succes') / count(*), 1) as taux_reussite
        from actions a
        group by a.action
        order by taux_reussite desc
    """)
    data = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify([dict(row) for row in data])

@app.route('/api/ethical-complexity')
def ethical_complexity():
    """Complexité éthique des scenarios"""
    conn = get_db()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("""
        select 
            s.priorite_loi as loi,
            case 
                when s.priorite_loi = 1 then 'Loi 1: Protéger Vie'
                when s.priorite_loi = 2 then 'Loi 2: Obéir Ordres'
                when s.priorite_loi = 3 then 'Loi 3: Auto-Préservation'
            end as loi_nom,
            count(distinct s.id_scenario) as scenario_count,
            count(a.id_action) as total_attempts
        from scenarios s
        left join actions a on s.id_scenario = a.id_scenario
        group by s.priorite_loi
        order by s.priorite_loi
    """)
    data = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify([dict(row) for row in data])

@app.route('/api/robot-specialization-detailed')
def robot_specialization_detailed():
    """Spécialisation détaillée des robots"""
    conn = get_db()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("""
        select 
            r.nom_robot,
            r.modele,
            r.etat,
            count(distinct a.id_scenario) as scenarios_traites,
            count(a.id_action) as actions_totales,
            count(*) filter (where a.resultat = 'succes') as succes,
            count(*) filter (where a.resultat = 'mitigue') as mitiges,
            count(*) filter (where a.resultat = 'echec') as echecs,
            round(100.0 * count(*) filter (where a.resultat = 'succes') 
                / nullif(count(*), 0), 1) as taux_reussite
        from robots r
        left join actions a on r.id_robot = a.id_robot
        group by r.id_robot, r.nom_robot, r.modele, r.etat
        order by taux_reussite desc nulls last
        limit 15
    """)
    data = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify([dict(row) for row in data])

@app.route('/api/dilemma-success-by-law')
def dilemma_success_by_law():
    """Taux de réussite pour chaque loi"""
    conn = get_db()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("""
        select 
            s.priorite_loi as loi,
            case 
                when s.priorite_loi = 1 then 'Loi 1: Protéger Vie'
                when s.priorite_loi = 2 then 'Loi 2: Obéir Ordres'
                when s.priorite_loi = 3 then 'Loi 3: Auto-Préservation'
            end as loi_nom,
            count(*) as total_actions,
            count(*) filter (where a.resultat = 'succes') as succes,
            count(*) filter (where a.resultat = 'mitigue') as mitiges,
            count(*) filter (where a.resultat = 'echec') as echecs,
            round(100.0 * count(*) filter (where a.resultat = 'succes') 
                / count(*), 1) as pourcent_succes
        from scenarios s
        join actions a on s.id_scenario = a.id_scenario
        group by s.priorite_loi
        order by s.priorite_loi
    """)
    data = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify([dict(row) for row in data])

@app.route('/api/vulnerability-impact')
def vulnerability_impact():
    """Impact de la vulnérabilité humaine sur les résultats"""
    conn = get_db()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("""
        select 
            h.vulnerabilite,
            count(*) as actions_total,
            count(*) filter (where a.resultat = 'succes') as succes,
            count(*) filter (where a.resultat = 'mitigue') as mitiges,
            count(*) filter (where a.resultat = 'echec') as echecs,
            round(100.0 * count(*) filter (where a.resultat = 'succes') 
                / count(*), 1) as taux_reussite
        from humains h
        join actions a on h.id_humain = a.id_humain
        group by h.vulnerabilite
        order by 
            case h.vulnerabilite 
                when 'faible' then 1
                when 'moyenne' then 2
                when 'elevee' then 3
            end
    """)
    data = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify([dict(row) for row in data])

@app.route('/api/sector-ethical-analysis')
def sector_ethical_analysis():
    """Analyse éthique par secteur"""
    conn = get_db()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("""
        select 
            h.localisation as secteur,
            count(distinct a.id_scenario) as scenarios_distincts,
            count(a.id_action) as total_actions,
            count(*) filter (where a.resultat = 'succes') as succes,
            count(*) filter (where a.resultat = 'mitigue') as mitiges,
            count(*) filter (where a.resultat = 'echec') as echecs,
            round(100.0 * count(*) filter (where a.resultat = 'succes') 
                / count(*), 1) as taux_reussite
        from humains h
        join actions a on h.id_humain = a.id_humain
        group by h.localisation
        order by taux_reussite desc
    """)
    data = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify([dict(row) for row in data])

@app.route('/api/law-conflict-analysis')
def law_conflict_analysis():
    """Conflits entre lois"""
    conn = get_db()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("""
        select 
            case s.priorite_loi
                when 1 then 'Loi 1 (Protéger Vie)'
                when 2 then 'Loi 2 (Obéir Ordres)'
                when 3 then 'Loi 3 (Auto-Préservation)'
            end as loi_principale,
            count(distinct s.id_scenario) as dilemmes_identifiés,
            count(*) as actions_liees,
            round(100.0 * count(*) filter (where a.resultat = 'succes') 
                / count(*), 1) as resolution_rate
        from scenarios s
        join actions a on s.id_scenario = a.id_scenario
        group by s.priorite_loi
        order by s.priorite_loi
    """)
    data = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify([dict(row) for row in data])

@app.route('/api/robot-ethical-maturity')
def robot_ethical_maturity():
    """Maturité éthique des robots"""
    conn = get_db()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("""
        select 
            r.nom_robot,
            r.modele,
            count(distinct a.id_scenario) as scenarios_traites,
            round(100.0 * count(*) filter (where a.resultat = 'succes')
                / nullif(count(*), 0), 1) as reussite_rate,
            count(distinct s.priorite_loi) as lois_traitees
        from robots r
        left join actions a on r.id_robot = a.id_robot
        left join scenarios s on a.id_scenario = s.id_scenario
        group by r.id_robot, r.nom_robot, r.modele
        having count(a.id_action) > 0
        order by reussite_rate desc nulls last
        limit 10
    """)
    data = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify([dict(row) for row in data])

@app.route('/api/time-execution-patterns')
def time_execution_patterns():
    """Patterns temporels par type de décision"""
    conn = get_db()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("""
        select 
            s.priorite_loi as loi,
            case 
                when s.priorite_loi = 1 then 'Urgence (Protéger Vie)'
                when s.priorite_loi = 2 then 'Protocole (Obéir)'
                when s.priorite_loi = 3 then 'Sécurité (Auto-Préserv.)'
            end as categorie_decision,
            count(*) as decisions
        from scenarios s
        join actions a on s.id_scenario = a.id_scenario
        group by s.priorite_loi
        order by s.priorite_loi
    """)
    data = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify([dict(row) for row in data])

if __name__ == '__main__':
    app.run(debug=True, port=5000)
