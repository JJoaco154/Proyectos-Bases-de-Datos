# Portafolio de Bases de Datos Relacionales: Festival de Música y Sistema Escolar 

 En este repositorio reuní dos proyectos prácticos que armé para diseñar, implementar y programar bases de datos relacionales desde cero. Cada uno apunta a un modelo de negocio totalmente distinto y corre en un motor especializado (MySQL y PostgreSQL). El objetivo principal fue meter mano en lógica programada avanzada, aplicando conceptos como **Triggers, Vistas, Funciones Complejas, Consultas con CTE y Procedimientos Almacenados transaccionales**.

---

##  1. festival_music (MySQL)
Este proyecto lo armé para modelar y gestionar toda la logística de un festival de música. Controla desde el registro de los artistas y los escenarios hasta la auditoría automática de los tiempos de show y los pagos.

###  Ficha Técnica
* **Motor:** MySQL 
* **Paradigma:** Relacional con integridad referencial estricta y lógica programada integrada.

###  Estructura de Tablas
* **`artistas`**: Guarda nombre, género musical, país, año de formación y una puntuación media que se calcula automáticamente.
* **`escenarios`**: Controla los espacios físicos, su ubicación, capacidad máxima y si tienen equipos de sonido propios.
* **`presentaciones`**: La tabla central. Une a los artistas con los escenarios usando fechas y horas únicas. También maneja los costos (cachet) y el estado del show.
* **`auditoria_presentaciones`**: Un histórico automatizado que registra los cambios que se hagan específicamente en la duración de los eventos.
* **`log_operaciones`**: Mi bitácora global para trackear transacciones exitosas y errores en la base de datos.

###  Componentes Avanzados que aplique
* **Trigger (`before_update_duracion_presentacion`)**: Valida que la duración de un concierto esté sí o sí entre 30 y 180 minutos. Si el tiempo cambia, guarda automáticamente el registro viejo en la tabla de auditoría.
* **UDF (`obtener_categoria_artista`)**: Una función que segmenta a los músicos en categorías (Novato, Telonero, Headliner) según su puntuación media.
* **Procedimientos Almacenados Transaccionales**:
  * `insertar_presentacion_base`:Envuelve el proceso en una transacción segura (START TRANSACTION), asegurando un ROLLBACK si el artista no existe.
  * `registrar_presentacion_completo`: Envuelve el proceso dentro de una transacción segura (`START TRANSACTION`), garantizando un `ROLLBACK` seguro si el artista no existe.
* **Análisis de Datos**: Optimicé una consulta usando una expresión de tabla común (CTE) combinada con una vista resumen para evaluar los ingresos de los artistas principales.

---

##  2. Sistema Escolar (PostgreSQL)
Acá diseñé una base de datos orientada a la administración académica de una escuela. Se encarga del control de matrículas, la asignación de profesores a los cursos, y las auditorías de notas y novedades.

###  Ficha Técnica
* **Motor:** PostgreSQL 
* **Paradigma:** Relacional usando identidad generada por sistema (`GENERATED ALWAYS AS IDENTITY`).

###  Estructura de Tablas
* **`alumno`**: Datos básicos, legajos únicos y la calificación acumulada.
* **`profesor`**:Nómina docente, salarios y la materia que dicta cada uno.
* **`curso`**: La tabla intermedia que vincula a los alumnos con sus respectivos profesores.
* **`log_operation`**: El repositorio centralizado que armé para seguir los eventos y auditar el sistema.

###  Componentes Avanzados que aplique
* **Triggers y Funciones de Disparo (PL/pgSQL)**:
  * `tg_auditar_cambios_profe`: Deja asentado en la bitácora cuándo un docente se jubila o es reemplazado en un curso.
  * `tg_actualizar_nota_fianl` y `tg_validar_aprobo`:  Auditan los cambios de notas y clasifican en tiempo real si el alumno aprobó o no.
  * `tg_validar_edad`: Una restricción para que no se puedan meter alumnos con edades inconsistentes (debe ser entre 16 y 100 años).
* **Función Escalar (`fn_promedio_profe`)**: Calcula dinámicamente el promedio general de las notas de los alumnos anotados con un profesor en específico.
* **Procedimientos Almacenados Transaccionales**:
  * `registrar_alumno_con_log`:Inserta alumnos controlando excepciones de notas nulas o negativas, aplicando COMMIT y ROLLBACK explícitos.
  * `registrar_alumno_en_curso`, `actualizar_nota_alumno`, `sp_registrar_profesor`, `sp_baja_alumno`: Todo un ecosistema de procedimientos para manejar el ciclo de vida completo del alumnado.

>  **Nota de Desarrollo / Erreores Tipográficos en el Script:** 
> Cuando desarrollé el script de PostgreSQL, decidí mantener a propósito algunos nombres de campos originales que venían de la estructura escolar simulada (como pellido, nota_fianl, nota_final, prom_nota o nombres de tablas cruzadas en las pruebas como alumnos / log_operaciones). Si vas a ejecutar las vistas o el bloque CTE, acordate de revisar la concordancia exacta de estos nombres para que el motor de Postgres no te tire una excepción de sintaxis.

