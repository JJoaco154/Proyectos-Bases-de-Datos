create database escuela;

create table alumno(
    id_alumno int primary key GENERATED ALWAYS AS identity, -- seria como auto_increment
    nombre varchar(20),
    apellido varchar(20),
    legajo int,
    nota_final decimal(10,2)    
);

create table profesor(
    id_profesor int primary key GENERATED ALWAYS AS identity,
    nombre varchar(20),
    apellido varchar(20),
    materia varchar(20),
    sueldo decimal(10,2) 
);

create table curso(
    id_curso int primary key GENERATED ALWAYS AS identity,
    nombre varchar(20),
    id_alumno_fk int references alumno(id_alumno),
    id_profesor_fk int references profesor(id_profesor) 
);

create table log_operacion(
    id_operacion int primary key GENERATED ALWAYS AS identity,
    tipo_operacion varchar(20),
    id_alumno_fk int references alumno(id_alumno),
    id_profe int references profesor(id_profesor),
    detalles varchar(40)    
);
ALTER TABLE log_operacion ALTER COLUMN detalles TYPE varchar(100);

INSERT INTO alumno (nombre, apellido, legajo, nota_final) VALUES 
('Juan', 'Pérez', 1001, 8.50),
('María', 'Gómez', 1002, 9.25),
('Carlos', 'López', 1003, 6.00);

INSERT INTO profesor (nombre, apellido, materia, sueldo) VALUES 
('Ana', 'Martínez', 'Matemáticas', 1500.00),
('Luis', 'Rodríguez', 'Historia', 1450.00);

INSERT INTO curso (nombre, id_alumno_fk, id_profesor_fk) VALUES 
('Álgebra I', 1, 1),
('Álgebra I', 2, 1),
('Historia Univ.', 3, 2);

INSERT INTO log_operacion (tipo_operacion, id_alumno_fk, id_profe, detalles) VALUES 
('ALTA', 1, NULL, 'Se registró al alumno Juan Pérez'),
('ALTA', NULL, 1, 'Se registró a la profesora Ana Martínez'),
('INSCRIPCION', 1, 1, 'Alumno 1 inscrito en curso con Profesor');


-- Vista:
create or replace view vista_resumen_alumnos as(
      select 
             a.id_alumno,
             concat(a.nombre, ' ', a.pellido) as nombre_alumno,
             a.legajo,
             a.nota_fianl
             case 
             	 when a.nota_final >= 7 then 'Promociona'
             	 when a.nota_fianl >= 4 then 'Aprobado'
             end as estado_alumno,
             c.nombre as curso,
             concat(p.nombre, ' ', p.apellido) as nombre_profe
      from curso as c
      left join alumno as on a.id_alumno = c.id_alumno_fk
      left join profesor as p on p.id_profesor = c.id_profesor_fk                 
);


-- UDF:
create or replace function fn_promedio_profe(p_id_prfe int)
returns decimal(10,2)
language plpgsql
as $$
declare v_prom decimal(10,2);
begin
	select avg(a.nota_final) into v_prom
    from alumno as a
    left join curso as c on a.id_alumno = c.id_alumno_fk
    where c.id_profesor_fk = p_id_profe;

    return v_prom;
end;
$$;


-- Trigger
create or replace function trigger_cambio_profe_alumno()
returns trigger as $$
begin

    if old.id_profe is distinct from new.id_profe then
        insert into log_operacion(tipo_operacion, id_alumno_fk, id_profe, detalles) 
        values('Cambio de profsor', old.id_alumno_fk, new.id_profe, 'Profe se jubilo');
    end if;

    return new; /
end;
$$ language plpgsql;

create trigger tg_auditar_cambios_profe
after update on curso
for each row
execute function trigger_cambio_profe_alumno();


create or replace function trigger_actualizar_nota_fianl()
returns trigger as $$
begin
 
	 if old.nota_final is distinct from new.nota_final then
        insert into log_operacion(tipo_operacion, id_alumno_fk, id_profe, detalles)
        values('Actualizacion nota alumno', old.id_alumno, null, 'Primer parcial');
     end if;

     returns new;

end;
$$ language plpgsql;

create trigger tg_actualizar_nota_fianl
after update 
on alumno
for each row
execute function trigger_actualizar_nota_fianl();


create or replace function tg() -- si cambio el profe lo deja rejistrado en log_operaciones
returns trigger as $$
begin
	 if old.id_profe is distinct from new.id_profe then
	    insert into log_operacion(tipo_operacion, id_alumno_fk, id_profe, detalles)
	    values('Cambio de profesor', old.id_alumno_fk, new.id_profe, 'Profe nuevo, aura');
     end if;

     returns new;
end;
$$ language plpgsql;

create trigger tg_auditar_profe nuevo
after update on curso 
for each row
execute function tg();


create or replace function tg_validar_edad()
returns trigger as $$
begin
	if new.edad < 16 then
       raise notice 'La edad tiene que ser mayor a 16';
    elsif new.edad > 100 then
       raise notice 'La edad tiene que ser menor a 100';
    end if;

    returns new;
end;
$$ language plpgsql;

create trigger tg_validacion_antes
before insert on alumno
for each row
execute function tg_validar_edad();

create trigger tg_validacion_despues
after insert on alumno
for each row
execute function tg_validar_edad();


create or replace function validacion_aprobar()
returns trigger as $$
begin
     if new.nota >= 4 then
        insert into log_operacion(tipo_operacion, id_alumno_fk, id_profe, detalles)
        values('Cambio de nota', old.id_alumno, null, 'aprobo');
     elsif new.nota < 4 then
        insert into log_operacion(tipo_operacion, id_alumno_fk, id_profe, detalles)
        values('Cambio de nota', old.id_alumno, null, 'desaprobo');
     end if;
   
     returns new;
end;
$$ language plpgsql;

create trigger tg_validar_aprobo
after update on alumno
for each row
execute function validacion_aprobar();



-- Store Procedure

create or replace procedure registrar_alumno_con_log(
    p_nombre varchar, p_apellido varchar, p_legajo int, p_nota_final decimal   
)
language plpgsql 
as $$ 
declare v_id_alumno int;
begin
	 
    if not exists(select 1 from alumno where legajo = p_legajo) then
       raise exception 'No existe alumno con ese legajo';
	elsif p_nota_final <= 0 then
       raise exception 'La nota no puede ser menor o igual a 0';
    end if;

	insert into alumno(nombre, apellido, legajo, nota_final)
	values(p_nombre, p_apellido, p_legajo, p_nota_final)
	returning id_alumno into v_id_alumno; -- esto es como un last_insert_id()

	insert into log_operacion(tipo_operacion, id_alumno_fk, id_profe, detalles)
	values('Alta SP', v_id_alumno, null, 'Alumno registrado exitosamente desde el SP');
    
    commit; 
    
    exception 
        when others then 
        rollback; 

        raise notice 'Ocurrio un error en el SP. Se uso un rollback. Detalles: %', sqlerrm;
        raise exception 'Error al procesar la transaccion %', sqlerrm; 
end;
$$; 

/*
DROP PROCEDURE IF EXISTS registrar_alumno_con_log(varchar, varchar, int, decimal);
DROP PROCEDURE IF EXISTS registrar_alumno_con_log(character varying, character varying, integer, numeric);
 */

call registrar_alumno_con_log('Mario', 'Gimenez', 45690, 7.5);



create or replace procedure registrar_alumno_en_curso(
    p_id_alumno int, p_id_profesor int, p_nombre_curso varchar
)
language plpgsql
as $$
begin

    -- Validaciones:
    if not exists(select 1 from alumno where id_alumno = p_id_alumno) then
         raise exception 'El alumno no existe';
    elsif not exists(select 1 from profesor where id_profe = p_id_profesor) then
         raise exception 'El profesor no existe';
    elsif p_nombre_curso is null then
         raise exception 'El nombre del curso no puede ser nulo';
    elsif exists(select id_profe from curso where id_alumno_fk = p_id_alumno and id_profe = p_id_profesor) then
         raise exception 'El alumno ya tiene un profesor agregador';
    end if;
	
   -- Logica del SP con transaccion
    insert into curso(nombre, id_alumno_fk, id_profesor_fk)
    values(p_nombre_curso, p_id_alumno, p_id_profesor);

    insert into log_operacion(tipo_operacion, id_alumno_fk, id_profe, detalles) 
    values('Insercion de un alumno', p_id_alumno, p_id_profesor, 'Curso: ' || p_nombre_curso);

    commit;

    -- Manejo de errores
    exception
        with others then
        rollback;
     
        raise notice 'Ocurrio error en SP se activo rollback. Detalles: %', sqlerrm;
        raise exception 'Error al realizar la transaccion: %', sqlerrm;
end;
$$;


create or replace procedure actualizar_nota_alumno(
    p_id_alumno int, p_nota_nueva decimal(10,2)
)
language plpgsql
as $$
begin
	  if not exists(select 1 from alumno where id_alumno = p_id_alumno) then
          raise exception 'El alumno no existe'; -- raise exeption: mustra mensaje de lo que paso y detiene la ejecucion del codigo como un exit handler, raise notice solo muetra y continua 
      elsif p_nueva_nota < 0 or p_nueva_nota > 10 then
          raise exception 'La nota tiene que estar entre 0 y 10';
      end if;

      update alumno
      set nota_final = p_nota_nueva
      where id_alumno = p_id_alumno;

      insert into log_operacion(tipo_operacion, id_alumno_fk, id_profe, detalles)
      values('Actualizacion nota', p_id_alumno, null, 'Es un chad');

      commit;

      exception
           when others then
           rollback;
           
           raise notice 'Ocurrio un error en el SP. Se activo rollback: %', sqlerrm;
           raise exception 'Error al realizar la tansaccion: %', sqlerrm
end;
$$;


create or replace procedure sp_registrar_profesor(
    p_id_alumno int, p_nuevo_profesor int
)
language plpgsql
as $$
begin
	if not exists(select 1 from alumno where id_alumno = p_id_alumno) then
       raise exception 'El alumno no existe';
    elsif not exists(select 1 from profesor where id_profesor = p_nuevo_profesor) then
       raise exception 'El profesor no existe';
    end if;

    update curso
    set id_profesor_fk = p_nuevo_profesor
    where id_alumno_fk = p_id_alumno;

    insert into log_operacion(tipo_operacion, id_alumno_fk, id_profe, detalles) 
    values('Cambio de profe en curso', p_id_alumno, p_nuevo_profe, 'Profe titular se fue de vaca');

    commit;

    exception
        when others then
        rollback;
        
        raise notice 'Ocurrio un error se aplico rollback. %' sqlerrm;
        raise exception 'Ocurrio un error la transaccion: %', sqlerrm;
end;
$$;


create or replace procedure sp_baja_alumno(
    p_id_alumno int, p_id_profesor int
)
language plpgsql
as $$
declare v_id_profe int;
begin

     select id_profesor_fk into v_id_profe
     from curso 
     where id_alumno_fk = p_id_alumno;

     
	 if not exists(select 1 from alumno where id_alumno = p_id_alumno) then
         raise exception 'El alumno no existe';
     elsif not exists(select 1 from profesor where id_profesor = p_id_profesor) then
         raise exception 'El profesor no existe';
     elsif v_id_profe != p_id_profesor then
         raise exception 'El alumno tiene asigando a otro profesor';
     end if;

     delete from curso
     where id_alumno_fk = p_id_alumno;

     insert into log_operacion(tipo_operacion, id_alumno_fk, id_profe, detalles)
     values('Baja alumno', p_id_alumno, p_id_profesor, 'El alumno dejo la carrera');

     commit;

     exception
        when others then
          rollback;

           raise notice 'Ocurrio un error se activo rollback: %', sqlerrm;
           raise exception 'Ocurrio un error en la transaccion/SP: %', sqlerrm;
end;
$$;


-- CTE:
with PromedioGeneral as(
     select avg(nota_fianl) as prom_nota
     from alumno
),
AlumnosDescartados as (
     select 
           a.id_alumno,
           a.nombre,
           a.apellido,
           a.nota_final
      from alumnos as a, PromedioGenaral as pg
      where a.nota_final > pg.prom_nota
)
select ad.nombre, ad.apellido, ad.nota_final, count(l.id_operacion) as total_movimientos_log
from AlumnosDescartados as ad 
left join log_operaciones as l on ad.id_alumno = l.id_alumno_fk
group by as.id_alumno, ad.nombre, ad.apellido, ad.nota_final
order by ad.nota_final desc;


-- consulta prueba:
select a.nombre as Alumno, p.nombre as Profe, a.nota_final 
from curso as c 
left join alumno as a on a.id_alumno = c.id_alumno_fk 
left join profesor as p on p.id_profesor = c.id_profesor_fk 
group by a.nombre, p.nombre, a.nota_final 
having a.nota_final >= 7;
