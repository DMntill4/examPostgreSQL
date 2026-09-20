# Proyecto Académico: Especificación Oficial

## 1. Introducción

Las organizaciones actuales requieren sistemas de información que les permitan administrar de manera estructurada, segura y trazable los procesos asociados a la **Seguridad y Salud en el Trabajo (SST)** y al **Plan Estratégico de Seguridad Vial (PESV)**. Estos procesos involucran múltiples tipos de información, entre ellos organizaciones, trabajadores, cargos, documentos, módulos, formatos, evaluaciones, etapas de gestión y configuraciones específicas para cada empresa.

Cuando esta información se administra mediante archivos independientes, hojas de cálculo o documentos dispersos, pueden presentarse dificultades relacionadas con la duplicidad de datos, inconsistencias, falta de trazabilidad, pérdida de información y poca capacidad para generar indicadores de seguimiento.

Para resolver esta problemática se propone desarrollar una base de datos relacional utilizando **PostgreSQL**, orientada a soportar una plataforma de gestión de SST y PESV bajo un modelo **multi-tenant**, permitiendo que múltiples organizaciones utilicen el mismo sistema manteniendo sus datos separados lógicamente.

El modelo de datos contempla entidades relacionadas con empresas o `tenants`, personas, cargos, módulos, sistemas SST, plantillas, formatos, etapas del ciclo PHVA, evaluaciones, localización geográfica y mecanismos de control de edición. Asimismo, incorpora estructuras para la generación de información consolidada y seguimiento mediante vistas especializadas.

A través del desarrollo de este proyecto, los estudiantes aplicarán los conocimientos adquiridos sobre **modelado de bases de datos, normalización, lenguaje SQL, restricciones de integridad, relaciones entre tablas, consultas, vistas, procedimientos, funciones, triggers, índices y administración básica de PostgreSQL**.

El proyecto permitirá abordar un escenario similar a los utilizados en aplicaciones empresariales reales, fortaleciendo las competencias necesarias para diseñar soluciones de almacenamiento de datos robustas, escalables y mantenibles.

---

## 2. Planteamiento del Problema

Una organización dedicada a prestar servicios de gestión de **Seguridad y Salud en el Trabajo y Plan Estratégico de Seguridad Vial** necesita desarrollar una plataforma tecnológica que pueda ser utilizada por diferentes empresas.

Cada empresa debe poder configurar su información de manera independiente, incluyendo:

- Datos generales de la organización.
- Tamaño de la empresa.
- Personas vinculadas.
- Cargos y responsabilidades.
- Sistemas de gestión habilitados.
- Módulos asociados al SST y PESV.
- Etapas del ciclo PHVA.
- Plantillas documentales.
- Formatos.
- Evaluaciones.
- Documentos generados.
- Seguimiento del avance.
- Ubicación geográfica.
- Control de edición de documentos.

Debido a que varias organizaciones utilizarán simultáneamente la plataforma, es necesario garantizar el aislamiento lógico de la información mediante una arquitectura de datos **multiempresa o multi-tenant**.

Además, la plataforma deberá permitir consultar el grado de avance de las empresas respecto a los documentos exigidos para cada etapa del proceso y facilitar la generación de indicadores de cumplimiento.

El principal problema consiste entonces en:

> **¿Cómo diseñar e implementar una base de datos relacional en PostgreSQL que permita gestionar de forma centralizada, segura, normalizada y escalable la información asociada a los procesos SST y PESV de múltiples organizaciones?**

---

## 3. Objetivo General

**Diseñar e implementar una base de datos relacional en PostgreSQL para soportar una plataforma multi-tenant de gestión de Seguridad y Salud en el Trabajo (SST) y Plan Estratégico de Seguridad Vial (PESV), aplicando técnicas de modelado, normalización, integridad referencial, programación SQL y optimización de consultas.**

---

## 4. Objetivos Específicos

1. **Analizar los requerimientos de información** asociados a la gestión de SST y PESV, identificando las principales entidades, atributos, reglas de negocio y relaciones necesarias para el sistema.
2. **Interpretar y documentar el modelo entidad-relación** propuesto para la plataforma, identificando entidades principales, entidades de parametrización y relaciones entre los diferentes componentes.
3. **Diseñar un modelo de datos multi-tenant** que permita almacenar información correspondiente a múltiples organizaciones manteniendo la independencia lógica de los datos.
4. **Aplicar técnicas de normalización** para disminuir la redundancia y garantizar consistencia e integridad en la información almacenada.
5. **Implementar el modelo físico en PostgreSQL**, utilizando tablas, claves primarias, claves foráneas, restricciones y tipos de datos adecuados.
6. **Implementar operaciones CRUD** mediante instrucciones SQL para la gestión de organizaciones, personas, cargos, módulos, plantillas, formatos y evaluaciones.
7. **Construir consultas SQL** que permitan recuperar y analizar información relacionada con los sistemas SST y PESV.
8. **Implementar consultas utilizando JOIN**, subconsultas, funciones de agregación, agrupamiento y expresiones condicionales.
9. **Diseñar vistas y vistas materializadas** orientadas a la generación de indicadores y reportes de seguimiento.
10. **Implementar funciones y procedimientos almacenados en PL/pgSQL** que automaticen operaciones relacionadas con la administración de la información.
11. **Implementar triggers** que permitan controlar procesos automáticos de auditoría, actualización o validación de datos.
12. **Diseñar índices** que permitan mejorar el rendimiento de las consultas utilizadas con mayor frecuencia.
13. **Implementar mecanismos de integridad y validación** mediante restricciones como `PRIMARY KEY`, `FOREIGN KEY`, `UNIQUE`, `CHECK` y `NOT NULL`.
14. **Analizar el funcionamiento del modelo PHVA** dentro de la estructura de datos para identificar el avance de cada organización.
15. **Construir consultas de indicadores** que permitan determinar el porcentaje de cumplimiento documental de una empresa.
16. **Aplicar mecanismos básicos de concurrencia**, analizando el uso de estructuras de bloqueo para evitar la edición simultánea de determinados recursos.
17. **Documentar técnicamente la base de datos**, incluyendo diccionario de datos, relaciones, restricciones y principales consultas.

---

## 5. Alcance del Proyecto

El proyecto comprenderá el diseño y construcción de una base de datos PostgreSQL orientada a la administración de información de una plataforma SST/PESV.

El sistema maneja los siguientes componentes principales:

| Componente | Función |
| :--- | :--- |
| **Empresas** | Administrar las organizaciones registradas |
| **Personas** | Gestionar usuarios o trabajadores asociados a cada empresa |
| **Cargos** | Definir cargos dentro de las organizaciones |
| **Sistemas SST** | Configurar sistemas habilitados para cada organización |
| **Módulos** | Organizar los componentes funcionales del sistema |
| **Etapas PHVA** | Clasificar procesos según Planear, Hacer, Verificar y Actuar |
| **Plantillas** | Gestionar documentos base |
| **Formatos** | Definir formatos asociados a módulos |
| **Evaluaciones** | Registrar instrumentos o plantillas de evaluación |
| **Ubicación Geográfica** | Administrar países, departamentos y municipios |
| **Bloqueos** | Controlar la edición simultánea de recursos |
| **Indicadores** | Determinar nivel de avance y cumplimiento |
| **Vistas Materializadas** | Facilitar consultas consolidadas |
