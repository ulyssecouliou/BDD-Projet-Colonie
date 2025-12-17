-- database qui fonctionne avec la totalité des requêtes

create database colonie;

\c colonie

drop table if exists actions cascade;
drop table if exists scenarios cascade;
drop table if exists humains cascade;
drop table if exists robots cascade;

create table robots (
    id_robot integer serial primary key,
    nom_robot text not null unique,
    modele text not null,
    etat text not null
);

create table humains (
    id_humain integer serial primary key,
    nom text not null,
    vulnerabilite text not null ,
    localisation text
);

create table scenarios (
    id_scenario integer serial primary key,
    description text not null,
    priorite_loi integer not null 
);

create table actions (
    id_action integer serial primary key,
    id_robot integer references robots(id_robot) ,
    id_humain integer references humains(id_humain) ,
    id_scenario integer references scenarios(id_scenario) ,
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

drop table if exists actions cascade;
drop table if exists scenarios cascade;
drop table if exists humains cascade;
drop table if exists robots cascade;

create table robots (
    id_robot integer serial primary key,
    nom_robot text not null unique,
    modele text not null,
    etat text not null
);

create table humains (
    id_humain integer serial primary key,
    nom text not null,
    vulnerabilite text not null ,
    localisation text
);

create table scenarios (
    id_scenario integer serial primary key,
    description text not null,
    priorite_loi integer not null 
);

create table actions (
    id_action integer serial primary key,
    id_robot integer references robots(id_robot) ,
    id_humain integer references humains(id_humain) ,
    id_scenario integer references scenarios(id_scenario) ,
    action text not null,
    timestamp timestamp not null,
    resultat text not null
);

create index idx_actions_robot on actions(id_robot);
create index idx_actions_scenario on actions(id_scenario);
create index idx_scenarios_priorite on scenarios(priorite_loi);
create index idx_robots_etat on robots(etat);

