create database if not exists festival_music;
use festival_music;

-- 1. TABLAS
create table artistas (
    id_artista int auto_increment primary key,
    nombre_artista varchar(100) not null unique,
    genero varchar(50),
    pais_origen varchar(50),
    anio_formacion year,
    puntuacion_media decimal(3,2) default 0.00
);

create table escenarios (
    id_escenario int auto_increment primary key,
    nombre_escenario varchar(100) not null,
    capacidad int not null,
    ubicacion varchar(200),
    tiene_sonido_propio boolean default false
);

create table presentaciones (
    id_presentacion int auto_increment primary key,
    id_artista int not null,
    id_escenario int not null,
    fecha_hora_inicio datetime not null,
    duracion int not null,
    cachet decimal(12,2) default 0,
    estado enum('Confirmada', 'Cancelada', 'Finalizada') default 'Confirmada',
    foreign key (id_artista) references artistas(id_artista) on delete cascade,
    foreign key (id_escenario) references escenarios(id_escenario) on delete cascade,
    unique key unique_presentacion (id_escenario, fecha_hora_inicio)
);

create table auditoria_presentaciones (
    id_auditoria int auto_increment primary key,
    id_presentacion int not null,
    duracion_anterior int not null,
    duracion_nueva int not null,
    fecha_modificacion timestamp default current_timestamp,
    usuario varchar(100),
    foreign key (id_presentacion) references presentaciones(id_presentacion) on delete cascade
);

create table log_operaciones (
    id_log int auto_increment primary key,
    fecha_hora timestamp default current_timestamp,
    tipo_operacion varchar(50),
    descripcion text,
    id_artista int null,
    id_presentacion int null
);

-- 2. INSERCIÓN DE DATOS
insert into artistas (nombre_artista, genero, pais_origen, anio_formacion, puntuacion_media) values
('The Stellar Notes', 'Rock Alternativo', 'Reino Unido', 2015, 4.8),
('ElectroSoul', 'Musica Electronica', 'Alemania', 2018, 4.2),
('Los Cantores del Sur', 'Folklore', 'Argentina', 2010, 4.9),
('Jazz Fusion Collective', 'Jazz', 'Estados Unidos', 2012, 3.5),
('Metal Eclipse', 'Heavy Metal', 'Suecia', 2008, 2.8),
('Sinfonia Andina', 'Musica Andina', 'Peru', 2016, 4.6),
('Rhythm & Beats', 'Hip Hop', 'Canada', 2020, 3.2),
('Acoustic Dreams', 'Folk Acustico', 'Irlanda', 2019, 4.0);

insert into escenarios (nombre_escenario, capacidad, ubicacion, tiene_sonido_propio) values
('Escenario Principal', 15000, 'Zona Norte', true),
('Escenario Secundario', 8000, 'Zona Sur', true),
('Carpa Acustica', 3000, 'Zona Este', false),
('Escenario Experimental', 5000, 'Zona Oeste', true);

insert into presentaciones (id_artista, id_escenario, fecha_hora_inicio, duracion, cachet, estado) values
(1, 1, '2024-07-15 20:00:00', 90, 15000.00, 'Confirmada'),
(1, 2, '2024-07-16 18:00:00', 60, 8000.00, 'Confirmada'),
(2, 1, '2024-07-15 22:00:00', 75, 12000.00, 'Confirmada'),
(3, 3, '2024-07-16 16:00:00', 120, 5000.00, 'Finalizada'),
(4, 2, '2024-07-17 20:00:00', 90, 7000.00, 'Confirmada'),
(5, 4, '2024-07-17 22:30:00', 60, 3000.00, 'Cancelada'),
(6, 1, '2024-07-18 19:00:00', 110, 18000.00, 'Confirmada'),
(3, 1, '2024-07-18 21:30:00', 70, 12000.00, 'Confirmada');

-- 3. VISTA
create or replace view vista_resumen_artistas as
select 
    a.id_artista, 
    a.nombre_artista, 
    a.genero, 
    a.pais_origen, 
    a.puntuacion_media, 
    count(p.id_presentacion) as total_presentaciones, 
    coalesce(sum(p.cachet), 0) as ingresos_totales
from artistas as a
left join presentaciones as p on a.id_artista = p.id_artista
group by a.id_artista, a.nombre_artista, a.genero, a.pais_origen, a.puntuacion_media
order by ingresos_totales desc;

-- 4. TRIGGER AUDITORÍA
delimiter //
create trigger before_update_duracion_presentacion 
before update on presentaciones
for each row
begin
    if NEW.duracion < 30 or NEW.duracion > 180 then
        signal sqlstate '45000'
        set message_text = 'La duracion debe estar entre 30 y 180 minutos';
    end if;
     
    if NEW.duracion != OLD.duracion then
        insert into auditoria_presentaciones(id_presentacion, duracion_anterior, duracion_nueva, fecha_modificacion, usuario)
        values(NEW.id_presentacion, OLD.duracion, NEW.duracion, now(), user());
    end if;
end //
delimiter ;

-- 5. FUNCIÓN UDF
delimiter //
create function obtener_categoria_artista(puntuacion_media decimal(3,2))
returns varchar(20)
deterministic
begin
    declare v_categoria varchar(20);
      
    if puntuacion_media < 3.0 then
        set v_categoria = 'Novato';
    elseif puntuacion_media >= 3.0 and puntuacion_media <= 4.5 then
        set v_categoria = 'Telonero';
    elseif puntuacion_media > 4.5 then
        set v_categoria = 'Headliner';
    end if;
      
    return v_categoria;
end //
delimiter ;

-- 6. CONSULTA CON CTE
with ResumenArtistas as (
    select 
        nombre_artista, 
        puntuacion_media, 
        obtener_categoria_artista(puntuacion_media) as categoria, 
        total_presentaciones, 
        ingresos_totales
    from vista_resumen_artistas
)
select nombre_artista, puntuacion_media, categoria, total_presentaciones, ingresos_totales
from ResumenArtistas
where total_presentaciones >= 2
order by ingresos_totales desc;

-- 7. STORED PROCEDURES
delimiter $$
create procedure insertar_presentacion_base(
    in p_id_artista int,
    in p_id_escenario int,
    in p_fecha_hora_inicio datetime,
    in p_duracion int,
    in p_cachet decimal(12,2)
)
begin
    declare v_id int;
    declare v_msg varchar(255);
    
    declare exit handler for sqlexception
    begin
        get diagnostics condition 1 v_msg = message_text;
        insert into log_operaciones(fecha_hora, tipo_operacion, descripcion, id_artista, id_presentacion)
        values(now(), 'Error SP base', concat('Error en SP base: ', v_msg), p_id_artista, null);
        resignal;
    end;
     
    if p_cachet <= 0 then
        signal sqlstate '45000' set message_text = 'El cachet no puede ser negativo o cero';
    elseif p_duracion < 30 or p_duracion > 180 then
        signal sqlstate '45000' set message_text = 'La duracion tiene que estar entre 30 y 180 min';
    elseif not exists (select 1 from escenarios where id_escenario = p_id_escenario) then
        signal sqlstate '45000' set message_text = 'El escenario no existe';
    end if;
    
    insert into presentaciones(id_artista, id_escenario, fecha_hora_inicio, duracion, cachet, estado)
    values(p_id_artista, p_id_escenario, p_fecha_hora_inicio, p_duracion, p_cachet, 'Confirmada');
    
    set v_id = last_insert_id();
    
    insert into log_operaciones(fecha_hora, tipo_operacion, descripcion, id_artista, id_presentacion)
    values(now(), 'Alta presentacion', 'Se registro una nueva presentacion', p_id_artista, v_id);

end $$
delimiter ;

delimiter $$
create procedure registrar_presentacion_completo(
    in p_id_artista int,
    in p_id_escenario int,
    in p_fecha_hora_inicio datetime,
    in p_duracion int,
    in p_cachet decimal(12,2)
)
begin
    declare exit handler for sqlexception
    begin
        rollback;
        insert into log_operaciones(fecha_hora, tipo_operacion, descripcion, id_artista, id_presentacion)
        values(now(), 'Error alta presentacion', 'Error al registrar presentacion transaccional', p_id_artista, null);
    end;
      
    start transaction;
      
    if not exists (select 1 from artistas where id_artista = p_id_artista) then
        signal sqlstate '45000' set message_text = 'El artista no existe en la bdd';
    end if;
      
    call insertar_presentacion_base(p_id_artista, p_id_escenario, p_fecha_hora_inicio, p_duracion, p_cachet);
      
    commit;
      
    select 'Transaccion exitosa' as mensaje;
end $$
delimiter ;