create database colonie;

\c colonie

create or replace table robots (
    id_robot integer serial primary key,
    nom_robot text unique,
    modele text,
    etat text
);

create or replace table humains (
    id_humain integer serial primary key,
    nom text,
    vulnerabilite text,
    localisation text
);

create or replace table scenarios (
    id_scenario integer serial primary key,
    description text,
    priorite_loi integer
);

create or replace table actions (
    id_action integer serial primary key,
    id_robot integer references robots(id_robot),
    id_humain integer references humains(id_humain),
    id_scenario integer references scenarios(id_scenario),
    action text,
    timestamp timestamp,
    resultat text
);

create index idx_actions_robot on actions(id_robot);
create index idx_actions_scenario on actions(id_scenario);
create index idx_scenarios_priorite on scenarios(priorite_loi);
create index idx_robots_etat on robots(etat);
