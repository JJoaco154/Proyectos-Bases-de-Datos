# Portafolio de Bases de Datos Relacionales: Festival de Música y Sistema Escolar 

Este repositorio reúne dos proyectos prácticos de diseño, implementación y programación de bases de datos relacionales. Cada proyecto aborda un dominio de negocio distinto y utiliza un sistema de gestión de bases de datos (RDBMS) especializado, aplicando conceptos avanzados como **Triggers, Vistas, Funciones Complejas, Consultas con CTE y Procedimientos Almacenados transaccionales**.

---

##  1. festival_music (MySQL)
Este proyecto modela y gestiona la logística de un festival musical, controlando desde el registro de artistas y escenarios hasta la auditoría automática de los tiempos de presentación y pagos.

###  Ficha Técnica
* **Motor:** MySQL 
* **Paradigma:** Relacional con integridad referencial estricta y lógica programada integrada.

###  Estructura de Tablas
* **`artistas`**: Registra nombre, género musical, país de origen, año de formación y una puntuación media automática.
* **`escenarios`**: Controla los espacios físicos, su ubicación, capacidad máxima y si disponen de equipamiento de sonido propio.
* **`presentaciones`**: Tabla operativa principal que une artistas y escenarios mediante fechas/horas únicas, incluyendo el costo (`cachet`) y el estado actual de la presentación.
* **`auditoria_presentaciones`**: Histórico automatizado que registra los cambios aplicados exclusivamente sobre la duración de los eventos.
* **`log_operaciones`**: Bitácora global de transacciones exitosas y excepciones de la base de datos.

###  Componentes Avanzados Incluidos
* **Trigger (`before_update_duracion_presentacion`)**: Valida que la duración de un concierto esté estrictamente entre 30 y 180 minutos. Si el tiempo cambia, escribe de forma automática el registro previo en la tabla de auditoría.
* **UDF (`obtener_categoria_artista`)**: Función determinada que segmenta a los músicos en categorías (*Novato*, *Telonero*, *Headliner*) basándose en su puntuación media.
* **Procedimientos Almacenados Transaccionales**:
  * `insertar_presentacion_base`: Aplica validaciones de negocio previas (duraciones correctas, existencia del escenario) y genera un log de éxito.
  * `registrar_presentacion_completo`: Envuelve el proceso dentro de una transacción segura (`START TRANSACTION`), garantizando un `ROLLBACK` seguro si el artista no existe.
* **Análisis de Datos**: Consulta optimizada mediante una expresión de tabla común (**CTE**) combinada con la vista resumen para evaluar ingresos de artistas principales.

---

##  2. Sistema Escolar (PostgreSQL)
Diseño de base de datos para la administración académica de una institución escolar, encargado del control de matrículas, asignación de docentes a cursos, y auditorías de notas y novedades.

###  Ficha Técnica
* **Motor:** PostgreSQL (v15+)
* **Paradigma:** Relacional usando identidad generada por sistema (`GENERATED ALWAYS AS IDENTITY`).

###  Estructura de Tablas
* **`alumno`**: Almacena datos básicos, legajos únicos y la calificación acumulada.
* **`profesor`**: Almacena nómina docente, salarios y la materia asignada.
* **`curso`**: Entidad relacional que vincula la asignación académica de alumnos y profesores.
* **`log_operation`**: Repositorio centralizado para el seguimiento de eventos y auditoría del sistema.

###  Componentes Avanzados Incluidos
* **Triggers y Funciones de Disparo (PL/pgSQL)**:
  * `tg_auditar_cambios_profe`: Registra en la bitácora cuando un docente se jubila o es reemplazado en un curso.
  * `tg_actualizar_nota_fianl` y `tg_validar_aprobo`: Auditan los cambios de calificaciones y clasifican dinámicamente si el alumno aprobó o desaprobó.
  * `tg_validar_edad`: Restringe inserciones de alumnos con edades inconsistentes (debe ser entre 16 y 100 años).
* **Función Escalar (`fn_promedio_profe`)**: Calcula de forma dinámica el promedio general de las notas de los alumnos inscritos con un profesor específico.
* **Procedimientos Almacenados Transaccionales**:
  * `registrar_alumno_con_log`: Inserta alumnos controlando excepciones de notas nulas/negativas y aplicando `COMMIT`/`ROLLBACK` explícitos.
  * `registrar_alumno_en_curso`, `actualizar_nota_alumno`, `sp_registrar_profesor`, `sp_baja_alumno`: Completo ecosistema de procedimientos para manejar el ciclo de vida del alumnado.

>  **Nota de Desarrollo / Erreores Tipográficos en el Script:** 
> El script de PostgreSQL fue desarrollado manteniendo intencionalmente ciertos nombres de campos originales presentes en la estructura escolar simulada (como `pellido`, `nota_fianl`, `nota_final`, `prom_nota` o nombres de tablas cruzadas en las consultas de prueba como `alumnos` / `log_operaciones`). Al ejecutar las vistas o el bloque CTE, verifique la concordancia exacta de los nombres de las columnas declaradas para evitar excepciones sintácticas del motor de PostgreSQL.


