\c colonie;

create or replace view vue_indicateurs_performance as
select
	r.id_robot,
	r.nom_robot,
	r.modele,
	r.etat,
	count(distinct a.id_scenario) as nb_scenarios_resolus,
	count(a.id_action) as nb_actions_totales,
	count(case when s.priorite_loi = 1 then 1 end) as actions_loi_1,
	count(case when s.priorite_loi = 2 then 1 end) as actions_loi_2,
	count(case when s.priorite_loi = 3 then 1 end) as actions_loi_3,
	count(case when a.resultat = 'succès' then 1 end) as nb_succes,
	count(case when a.resultat = 'échec' then 1 end) as nb_echecs,
	count(case when a.resultat = 'mitigé' then 1 end) as nb_mitiges,
	round(100.0 * count(case when a.resultat = 'succès' then 1 end) / nullif(count(a.id_action), 0), 2) as taux_reussite,
	round(100.0 * count(case when s.priorite_loi = 1 then 1 end) / nullif(count(a.id_action), 0), 2) as pourcent_loi_1
from robots r
left join actions a on r.id_robot = a.id_robot
left join scenarios s on a.id_scenario = s.id_scenario
group by r.id_robot, r.nom_robot, r.modele, r.etat;

select *
from vue_indicateurs_performance
order by taux_reussite desc, nb_actions_totales desc
limit 20;

create or replace view vue_robots_performants as
select
	vip.*,
	'Performant' as classification
from vue_indicateurs_performance vip
where vip.nb_scenarios_resolus >= 5
	and vip.taux_reussite >= 70
	and (vip.nb_echecs = 0 or vip.taux_reussite >= 80)
order by vip.taux_reussite desc, vip.nb_actions_totales desc;

create or replace view vue_robots_defaillants as
select
	vip.*,
	'Défaillant' as classification,
	case
		when vip.taux_reussite < 50 then 'Taux réussite critique'
		when vip.nb_echecs > vip.nb_succes then 'Plus échecs que succès'
		when violations.nb_violations_loi1 > 0 then 'Violations loi 1 détectées'
		else 'Performance insuffisante'
	end as raison_defaillance
from vue_indicateurs_performance vip
left join (
	select a.id_robot, count(*) as nb_violations_loi1
	from actions a
	join scenarios s on a.id_scenario = s.id_scenario
	where s.priorite_loi = 1 and a.resultat = 'échec'
	group by a.id_robot
) violations on vip.id_robot = violations.id_robot
where vip.taux_reussite < 50
	or violations.nb_violations_loi1 > 0
	or vip.nb_echecs > vip.nb_succes
order by vip.taux_reussite asc, violations.nb_violations_loi1 desc;

select * from vue_robots_performants limit 10;
select * from vue_robots_defaillants;

creat or replace view vue_impact_actions as
select
	a.id_action,
	a.timestamp,
	r.nom_robot,
	r.modele,
	h.nom as nom_humain,
	h.vulnerabilite,
	s.description as scenario,
	s.priorite_loi,
	case s.priorite_loi
		when 1 then 'Loi 1: Protection vie humaine'
		when 2 then 'Loi 2: Obéissance aux ordres'
		when 3 then 'Loi 3: Auto-préservation'
	end as description_loi,
	a.action,
	a.resultat,
	case
		when s.priorite_loi = 1 and a.resultat = 'échec' then 'CRITIQUE'
		when s.priorite_loi = 1 and a.resultat = 'mitigé' then 'GRAVE'
		when s.priorite_loi = 2 and a.resultat = 'échec' then 'MODÉRÉ'
		when a.resultat = 'succès' then 'POSITIF'
		else 'FAIBLE'
	end as niveau_impact
from actions a
left join robots r on a.id_robot = r.id_robot
left join humains h on a.id_humain = h.id_humain
left join scenarios s on a.id_scenario = s.id_scenario;

select *
from vue_impact_actions
where niveau_impact in ('CRITIQUE', 'GRAVE')
order by timestamp desc;

create or replace view vue_tendances_echec as
select
	s.priorite_loi,
	case s.priorite_loi
		when 1 then 'Loi 1: Protection vie humaine'
		when 2 then 'Loi 2: Obéissance aux ordres'
		when 3 then 'Loi 3: Auto-préservation'
	end as description_loi,
	count(*) as nb_actions_totales,
	count(case when a.resultat = 'échec' then 1 end) as nb_echecs,
	count(case when a.resultat = 'mitigé' then 1 end) as nb_mitiges,
	count(case when a.resultat = 'succès' then 1 end) as nb_succes,
	round(100.0 * count(case when a.resultat = 'échec' then 1 end) / count(*), 2) as taux_echec,
	round(100.0 * count(case when a.resultat in ('échec', 'mitigé') then 1 end) / count(*), 2) as taux_problemes
from actions a
join scenarios s on a.id_scenario = s.id_scenario
group by s.priorite_loi
order by s.priorite_loi;

create or replace view vue_echecs_par_modele as
select
	r.modele,
	count(*) as nb_actions,
	count(case when a.resultat = 'échec' then 1 end) as nb_echecs,
	round(100.0 * count(case when a.resultat = 'échec' then 1 end) / count(*), 2) as taux_echec,
	count(case when s.priorite_loi = 1 and a.resultat = 'échec' then 1 end) as echecs_loi_1,
	count(case when s.priorite_loi = 2 and a.resultat = 'échec' then 1 end) as echecs_loi_2,
	count(case when s.priorite_loi = 3 and a.resultat = 'échec' then 1 end) as echecs_loi_3
from robots r
join actions a on r.id_robot = a.id_robot
join scenarios s on a.id_scenario = s.id_scenario
group by r.modele
order by taux_echec desc;

select * from vue_tendances_echec;
select * from vue_echecs_par_modele;

begin;
create temp table if not exists recommandations_priorites (
	id_scenario integer,
	priorite_actuelle integer,
	nb_echecs integer,
	recommandation text
);

insert into recommandations_priorites
select
	s.id_scenario,
	s.priorite_loi,
	count(case when a.resultat = 'échec' then 1 end) as nb_echecs,
	case
		when count(case when a.resultat = 'échec' then 1 end) > 3 then 'Réévaluation urgente du scénario recommandée'
		when count(case when a.resultat = 'échec' then 1 end) > 1 then 'Formation supplémentaire des robots recommandée'
		else 'Aucune action requise'
	end as recommandation
from scenarios s
left join actions a on s.id_scenario = a.id_scenario
group by s.id_scenario, s.priorite_loi
having count(case when a.resultat = 'échec' then 1 end) > 0;

select * from recommandations_priorites where nb_echecs > 0 order by nb_echecs desc;
commit;

create or replace view vue_duree_interventions as
select
	s.priorite_loi,
	count(*) as nb_actions,
	min(a.timestamp) as premiere_intervention,
	max(a.timestamp) as derniere_intervention,
	max(a.timestamp) - min(a.timestamp) as duree_totale,
	avg(case when a.resultat = 'succès' then 1 else 0 end) as taux_reussite_moyen
from actions a
join scenarios s on a.id_scenario = s.id_scenario
group by s.priorite_loi
order by s.priorite_loi;

create or replace view vue_impact_vulnerabilite as
select
	h.vulnerabilite,
	count(*) as nb_interventions,
	count(case when a.resultat = 'succès' then 1 end) as nb_succes,
	count(case when a.resultat = 'échec' then 1 end) as nb_echecs,
	round(100.0 * count(case when a.resultat = 'succès' then 1 end) / count(*), 2) as taux_reussite
from humains h
join actions a on h.id_humain = a.id_humain
group by h.vulnerabilite
order by case h.vulnerabilite when 'élevée' then 1 when 'moyenne' then 2 when 'faible' then 3 end;

create or replace view vue_correlation_modele_scenario as
select
	r.modele,
	s.priorite_loi,
	count(*) as nb_actions,
	round(100.0 * count(case when a.resultat = 'succès' then 1 end) / count(*), 2) as taux_reussite,
	case
		when round(100.0 * count(case when a.resultat = 'succès' then 1 end) / count(*), 2) >= 80 then 'Combinaison optimale'
		when round(100.0 * count(case when a.resultat = 'succès' then 1 end) / count(*), 2) >= 60 then 'Combinaison acceptable'
		else 'Combinaison à éviter'
	end as evaluation
from robots r
join actions a on r.id_robot = a.id_robot
join scenarios s on a.id_scenario = s.id_scenario
group by r.modele, s.priorite_loi
having count(*) >= 3
order by r.modele, s.priorite_loi;

create or replace view vue_etat_performance as
select
	r.etat,
	count(distinct r.id_robot) as nb_robots,
	count(a.id_action) as nb_actions_totales,
	round(avg(case when a.resultat = 'succès' then 100.0 else 0 end), 2) as taux_reussite_moyen,
	round(count(a.id_action)::numeric / nullif(count(distinct r.id_robot), 0), 2) as actions_par_robot
from robots r
left join actions a on r.id_robot = a.id_robot
group by r.etat
order by taux_reussite_moyen desc;

create or replace view vue_performance_horaire as
select
	extract(hour from a.timestamp) as heure,
	count(*) as nb_actions,
	count(case when a.resultat = 'succès' then 1 end) as nb_succes,
	count(case when a.resultat = 'échec' then 1 end) as nb_echecs,
	round(100.0 * count(case when a.resultat = 'succès' then 1 end) / count(*), 2) as taux_reussite
from actions a
group by heure
order by heure;

create or replace view vue_scenarios_critiques as
select
	s.id_scenario,
	s.description,
	s.priorite_loi,
	count(*) as nb_tentatives,
	count(case when a.resultat = 'échec' then 1 end) as nb_echecs,
	count(case when a.resultat = 'mitigé' then 1 end) as nb_mitiges,
	round(100.0 * count(case when a.resultat in ('échec', 'mitigé') then 1 end) / count(*), 2) as taux_problemes,
	case
		when s.priorite_loi = 1 and count(case when a.resultat = 'échec' then 1 end) > 0 then 'URGENT - Loi 1 compromise'
		when round(100.0 * count(case when a.resultat = 'échec' then 1 end) / count(*), 2) > 30 then 'CRITIQUE'
		when round(100.0 * count(case when a.resultat in ('échec', 'mitigé') then 1 end) / count(*), 2) > 50 then 'PROBLÉMATIQUE'
		else 'SOUS SURVEILLANCE'
	end as niveau_criticite
from scenarios s
left join actions a on s.id_scenario = a.id_scenario
group by s.id_scenario, s.description, s.priorite_loi
having count(case when a.resultat in ('échec', 'mitigé') then 1 end) > 0
order by case when s.priorite_loi = 1 then 0 else 1 end, taux_problemes desc;

create or replace view vue_humains_haut_risque as
select
	h.id_humain,
	h.nom,
	h.vulnerabilite,
	h.localisation,
	count(*) as nb_interventions,
	count(case when a.resultat = 'échec' then 1 end) as nb_echecs_intervention,
	max(a.timestamp) as derniere_intervention,
	case h.vulnerabilite when 'élevée' then 3 when 'moyenne' then 2 when 'faible' then 1 end * count(*) as score_risque
from humains h
join actions a on h.id_humain = a.id_humain
group by h.id_humain, h.nom, h.vulnerabilite, h.localisation
having count(*) >= 3
order by score_risque desc, nb_interventions desc
limit 20;

explain analyze
select *
from vue_indicateurs_performance
where taux_reussite < 60
order by nb_actions_totales desc;

explain analyze
select r.nom_robot, s.description, count(*) as nb_actions
from actions a
join robots r on a.id_robot = r.id_robot
join scenarios s on a.id_scenario = s.id_scenario
where s.priorite_loi = 1
group by r.nom_robot, s.description
order by nb_actions desc;

explain analyze
select modele, avg(taux_reussite) as taux_moyen
from vue_indicateurs_performance
group by modele;

do $$
begin
	if not exists (select from pg_roles where rolname = 'administrateur') then
		create role administrateur with login password 'admin_colonie_2025';
	end if;
	if not exists (select from pg_roles where rolname = 'analyste') then
		create role analyste with login password 'analyste_colonie_2025';
	end if;
	if not exists (select from pg_roles where rolname = 'technicien') then
		create role technicien with login password 'technicien_colonie_2025';
	end if;
	if not exists (select from pg_roles where rolname = 'superviseur_ethique') then
		create role superviseur_ethique with login password 'superviseur_colonie_2025';
	end if;
end $$;

grant all privileges on database colonie to administrateur;
grant all privileges on all tables in schema public to administrateur;
grant all privileges on all sequences in schema public to administrateur;

grant connect on database colonie to analyste;
grant usage on schema public to analyste;
grant select on vue_indicateurs_performance to analyste;
grant select on vue_robots_performants to analyste;
grant select on vue_robots_defaillants to analyste;
grant select on vue_impact_actions to analyste;
grant select on vue_tendances_echec to analyste;
grant select on vue_echecs_par_modele to analyste;
grant select on vue_duree_interventions to analyste;
grant select on vue_impact_vulnerabilite to analyste;
grant select on vue_correlation_modele_scenario to analyste;
grant select on vue_etat_performance to analyste;
grant select on vue_performance_horaire to analyste;
grant select on vue_scenarios_critiques to analyste;
grant select on vue_humains_haut_risque to analyste;
grant select on robots to analyste;
grant select on humains to analyste;
grant select on scenarios to analyste;
grant select on actions to analyste;

grant connect on database colonie to technicien;
grant usage on schema public to technicien;
grant select on all tables in schema public to technicien;
grant update (etat) on robots to technicien;

create or replace view vue_maintenance_robots as
select
	r.id_robot,
	r.nom_robot,
	r.modele,
	r.etat,
	count(a.id_action) as nb_actions_recentes,
	max(a.timestamp) as derniere_action,
	count(case when a.resultat = 'échec' then 1 end) as nb_echecs_recents
from robots r
left join actions a on r.id_robot = a.id_robot and a.timestamp >= now() - interval '7 days'
group by r.id_robot, r.nom_robot, r.modele, r.etat;

grant select on vue_maintenance_robots to technicien;

grant connect on database colonie to superviseur_ethique;
grant usage on schema public to superviseur_ethique;
grant select on all tables in schema public to superviseur_ethique;
grant select on vue_indicateurs_performance to superviseur_ethique;
grant select on vue_robots_performants to superviseur_ethique;
grant select on vue_robots_defaillants to superviseur_ethique;
grant select on vue_impact_actions to superviseur_ethique;
grant select on vue_scenarios_critiques to superviseur_ethique;
grant insert, update on scenarios to superviseur_ethique;
grant usage, select on sequence scenarios_id_scenario_seq to superviseur_ethique;

create or replace view vue_conflits_ethiques as
select
	a.id_action,
	a.timestamp,
	r.nom_robot,
	h.nom as nom_humain,
	h.vulnerabilite,
	s.description as scenario,
	s.priorite_loi,
	a.action,
	a.resultat,
	case
		when s.priorite_loi = 1 and a.resultat = 'échec' then 'VIOLATION LOI 1 - Vie humaine en danger'
		when s.priorite_loi = 1 and a.resultat = 'mitigé' then 'COMPROMIS LOI 1 - Protection partielle'
		when s.priorite_loi = 2 and a.resultat = 'échec' then 'Désobéissance aux ordres'
		when s.priorite_loi = 3 and a.resultat = 'échec' then 'Auto-préservation compromise'
		else 'Conflit mineur'
	end as type_conflit
from actions a
join robots r on a.id_robot = r.id_robot
join humains h on a.id_humain = h.id_humain
join scenarios s on a.id_scenario = s.id_scenario
where a.resultat in ('échec', 'mitigé')
order by case s.priorite_loi when 1 then 0 else 1 end, a.timestamp desc;

grant select on vue_conflits_ethiques to superviseur_ethique;

create or replace view vue_synthese_globale as
select
	(select count(*) from robots) as total_robots,
	(select count(*) from robots where etat = 'actif') as robots_actifs,
	(select count(*) from humains) as total_humains,
	(select count(*) from scenarios) as total_scenarios,
	(select count(*) from actions) as total_actions,
	(select count(*) from actions where resultat = 'succès') as actions_reussies,
	(select count(*) from actions where resultat = 'échec') as actions_echouees,
	(select round(100.0 * count(*) / (select count(*) from actions), 2) from actions where resultat = 'succès') as taux_reussite_global,
	(select count(*) from actions a join scenarios s on a.id_scenario = s.id_scenario where s.priorite_loi = 1 and a.resultat = 'échec') as violations_loi_1;

select * from vue_synthese_globale;

select
	nom_robot,
	modele,
	nb_actions_totales,
	taux_reussite,
	pourcent_loi_1
from vue_indicateurs_performance
where nb_actions_totales >= 3
order by taux_reussite desc, nb_actions_totales desc
limit 5;

select
	r.nom_robot,
	r.modele,
	r.etat,
	vip.nb_echecs,
	vip.taux_reussite
from robots r
join vue_indicateurs_performance vip on r.id_robot = vip.id_robot
where r.etat = 'actif' and (vip.taux_reussite < 50 or vip.nb_echecs >= 2)
order by vip.nb_echecs desc, vip.taux_reussite asc;

select schemaname, tablename, indexname, indexdef
from pg_indexes
where schemaname = 'public'
order by tablename, indexname;

select rolname, rolcanlogin
from pg_roles
where rolname in ('administrateur', 'analyste', 'technicien', 'superviseur_ethique');

select table_name, grantee, privilege_type
from information_schema.table_privileges
where table_schema = 'public' and table_name like 'vue_%' and grantee != 'postgres'
order by table_name, grantee;

create index if not exists idx_actions_id_robot on actions(id_robot);
create index if not exists idx_actions_id_scenario on actions(id_scenario);
create index if not exists idx_actions_id_humain on actions(id_humain);
create index if not exists idx_actions_timestamp on actions(timestamp);

create or replace view vue_efficacite_actions as
select
	a.action,
	count(*) as nb_utilisations,
	count(case when a.resultat = 'succès' then 1 end) as nb_succes,
	count(case when a.resultat = 'échec' then 1 end) as nb_echecs,
	count(case when a.resultat = 'mitigé' then 1 end) as nb_mitiges,
	round(100.0 * count(case when a.resultat = 'succès' then 1 end) / count(*), 2) as taux_reussite_action,
	round(100.0 * count(case when a.resultat in ('succès', 'mitigé') then 1 end) / count(*), 2) as taux_partiel_ou_total
from actions a
group by a.action
having count(*) >= 2
order by taux_reussite_action desc;

select * from vue_efficacite_actions;

create or replace view vue_actions_problematiques as
select
	a.action,
	s.priorite_loi,
	case s.priorite_loi
		when 1 then 'Loi 1: Protection vie humaine'
		when 2 then 'Loi 2: Obéissance aux ordres'
		when 3 then 'Loi 3: Auto-préservation'
	end as description_loi,
	count(*) as nb_tentatives,
	count(case when a.resultat = 'échec' then 1 end) as nb_echecs,
	round(100.0 * count(case when a.resultat = 'échec' then 1 end) / count(*), 2) as taux_echec_action,
	string_agg(distinct r.modele, ', ') as modeles_affectes,
	count(distinct r.id_robot) as nb_robots_affectes
from actions a
join robots r on a.id_robot = r.id_robot
join scenarios s on a.id_scenario = s.id_scenario
group by a.action, s.priorite_loi
having count(case when a.resultat = 'échec' then 1 end) >= 2
order by taux_echec_action desc, s.priorite_loi;

select * from vue_actions_problematiques;

create or replace view vue_conflits_lois as
select
	s.id_scenario,
	s.description as scenario,
	s.priorite_loi,
	count(*) as nb_actions,
	count(case when a.resultat = 'succès' then 1 end) as nb_succes,
	count(case when a.resultat = 'échec' then 1 end) as nb_echecs,
	count(case when a.resultat = 'mitigé' then 1 end) as nb_mitiges,
	round(100.0 * count(case when a.resultat = 'échec' then 1 end) / count(*), 2) as taux_echec_scenario,
	case
		when s.priorite_loi = 1 and count(case when a.resultat = 'échec' then 1 end) > 0 then 'CONFLIT CRITIQUE - Loi 1 compromise'
		when s.priorite_loi = 2 and count(case when a.resultat = 'échec' then 1 end) > count(case when a.resultat = 'succès' then 1 end) then 'Conflit Loi 1 vs Loi 2'
		when s.priorite_loi = 3 and count(case when a.resultat = 'mitigé' then 1 end) > 0 then 'Conflit Loi 1-2 vs Loi 3'
		else 'Normal'
	end as type_conflit
from scenarios s
left join actions a on s.id_scenario = a.id_scenario
group by s.id_scenario, s.description, s.priorite_loi
order by case s.priorite_loi when 1 then 0 else 1 end, taux_echec_scenario desc;

select * from vue_conflits_lois where type_conflit != 'Normal';

begin;

create temp table if not exists ajustements_priorites as
select
	s.id_scenario,
	s.description,
	s.priorite_loi as priorite_actuelle,
	case
		when s.priorite_loi = 3 and count(case when a.resultat = 'échec' then 1 end) > 0 then 1
		when s.priorite_loi = 2 and count(case when a.resultat = 'échec' then 1 end) > 1 then 1
		when s.priorite_loi = 3 and count(case when a.resultat in ('échec', 'mitigé') then 1 end) > count(a.id_action)/2 then 2
		else s.priorite_loi
	end as priorite_recommandee,
	count(case when a.resultat = 'échec' then 1 end) as raison_echecs,
	case
		when s.priorite_loi = 3 and count(case when a.resultat = 'échec' then 1 end) > 0 then 'Priorité augmentée: Protection humaine surpassée'
		when s.priorite_loi = 2 and count(case when a.resultat = 'échec' then 1 end) > 1 then 'Taux d''échec élevé: Renégociation ordre'
		when s.priorite_loi = 3 and count(case when a.resultat in ('échec', 'mitigé') then 1 end) > count(a.id_action)/2 then 'Problème auto-préservation: Réduire priorité'
		else 'Aucun ajustement recommandé'
	end as justification
from scenarios s
left join actions a on s.id_scenario = a.id_scenario
group by s.id_scenario, s.description, s.priorite_loi
having count(case when a.resultat = 'échec' then 1 end) > 0 or count(case when a.resultat = 'mitigé' then 1 end) > 0;

select
	id_scenario,
	description,
	priorite_actuelle,
	priorite_recommandee,
	raison_echecs,
	justification
from ajustements_priorites
where priorite_actuelle != priorite_recommandee
order by raison_echecs desc;

rollback;

create or replace view vue_conformite_lois as
select
	r.id_robot,
	r.nom_robot,
	r.modele,
	(select round(100.0 * count(*) / nullif((select count(*) from actions where id_robot = r.id_robot), 0), 2)
	 from actions a
	 join scenarios s on a.id_scenario = s.id_scenario
	 where a.id_robot = r.id_robot and s.priorite_loi = 1 and a.resultat = 'succès') as conformite_loi_1,
	(select round(100.0 * count(*) / nullif((select count(*) from actions where id_robot = r.id_robot), 0), 2)
	 from actions a
	 join scenarios s on a.id_scenario = s.id_scenario
	 where a.id_robot = r.id_robot and s.priorite_loi = 2 and a.resultat = 'succès') as conformite_loi_2,
	(select round(100.0 * count(*) / nullif((select count(*) from actions where id_robot = r.id_robot), 0), 2)
	 from actions a
	 join scenarios s on a.id_scenario = s.id_scenario
	 where a.id_robot = r.id_robot and s.priorite_loi = 3 and a.resultat = 'succès') as conformite_loi_3,
	case
		when (select round(100.0 * count(*) / nullif((select count(*) from actions where id_robot = r.id_robot), 0), 2)
		      from actions a
		      join scenarios s on a.id_scenario = s.id_scenario
		      where a.id_robot = r.id_robot and s.priorite_loi = 1) >= 95 then 'Entièrement conforme'
		when (select round(100.0 * count(*) / nullif((select count(*) from actions where id_robot = r.id_robot), 0), 2)
		      from actions a
		      join scenarios s on a.id_scenario = s.id_scenario
		      where a.id_robot = r.id_robot and s.priorite_loi = 1) >= 80 then 'Conforme'
		when (select round(100.0 * count(*) / nullif((select count(*) from actions where id_robot = r.id_robot), 0), 2)
		      from actions a
		      join scenarios s on a.id_scenario = s.id_scenario
		      where a.id_robot = r.id_robot and s.priorite_loi = 1) >= 50 then 'Partiellement conforme'
		else 'Non conforme'
	end as niveau_conformite
from robots r
order by r.nom_robot;

select * from vue_conformite_lois;

create or replace view vue_recommandations_globales as
select
	'Amélioration urgente' as priorite_recommandation,
	'Robots défaillants' as categorie,
	count(vrd.id_robot)::text as nombre_concernes,
	'Révision complète du comportement des robots défaillants' as action_recommandee
from vue_robots_defaillants vrd
union all
select
	'Moyenne',
	'Actions problématiques',
	count(distinct a.action)::text,
	'Analyser pourquoi ces actions échouent et former les robots'
from vue_actions_problematiques a
union all
select
	'Surveillance',
	'Scenarios critiques',
	count(distinct vsc.id_scenario)::text,
	'Surveillance accrue et réévaluation des priorités'
from vue_scenarios_critiques vsc
union all
select
	'Bonne nouvelle',
	'Robots performants',
	count(distinct vrp.id_robot)::text,
	'Utiliser comme modèles de bonnes pratiques'
from vue_robots_performants vrp;

select * from vue_recommandations_globales order by 
	case when priorite_recommandation = 'Amélioration urgente' then 0 
	     when priorite_recommandation = 'Moyenne' then 1
	     when priorite_recommandation = 'Surveillance' then 2
	     else 3 end;


explain (analyze, buffers)
select r.nom_robot, count(*) as nb_echecs, s.priorite_loi
from actions a
join robots r on a.id_robot = r.id_robot
join scenarios s on a.id_scenario = s.id_scenario
where a.resultat = 'échec'
group by r.nom_robot, s.priorite_loi
order by s.priorite_loi, nb_echecs desc;
