-- database qui fonctionne avec la totalité des requêtes

create database colonie;

\c colonie


create or REPLACE table robots (
    id_robot serial primary key,
    nom_robot text not null unique,
    modele text not null,
    etat text not null
);

create or REPLACE table humains (
    id_humain serial primary key,
    nom text not null,
    vulnerabilite text not null,
    localisation text
);

create or REPLACE table scenarios (
    id_scenario serial primary key,
    description text not null,
    priorite_loi integer not null
);

create or REPLACE table actions (
    id_action serial primary key,
    id_robot integer references robots(id_robot),
    id_humain integer references humains(id_humain),
    id_scenario integer references scenarios(id_scenario),
    action text not null,
    timestamp timestamp not null,
    resultat text not null
);

create index idx_actions_robot on actions(id_robot);
create index idx_actions_scenario on actions(id_scenario);
create index idx_scenarios_priorite on scenarios(priorite_loi);
create index idx_robots_etat on robots(etat);



-- database qui fonctionne avec le dashboard
create database colonie1;

\c colonie1



create or replace table robots (
    id_robot serial primary key,
    nom_robot text not null unique,
    modele text not null,
    etat text not null
);

create or replace table humains (
    id_humain serial primary key,
    nom text not null,
    vulnerabilite text not null,
    localisation text
);

create or replace table scenarios (
    id_scenario serial primary key,
    description text not null,
    priorite_loi integer not null
);

create or replace table actions (
    id_action serial primary key,
    id_robot integer references robots(id_robot),
    id_humain integer references humains(id_humain),
    id_scenario integer references scenarios(id_scenario),
    action text not null,
    timestamp timestamp not null,
    resultat text not null
);

create index idx_actions_robot on actions(id_robot);
create index idx_actions_scenario on actions(id_scenario);
create index idx_scenarios_priorite on scenarios(priorite_loi);
create index idx_robots_etat on robots(etat);
