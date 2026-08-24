# Acta N° 1 — Semana 1

**Proyecto:** MilkData  
**Repositorio:** sw1-MilkData  
**Fecha:** 17 de agosto de 2026  

## Asistentes
- Olger Meza Rupa
- Raphael Enrique Roger Mamani Vilca
- Ciro Garry K. Machicado Velasquez
- [Nombre 4]

---

## 1. Definición de la Idea de Proyecto

### Idea Elegida
**MilkData**: Sistema integral para el registro, control de calidad y trazabilidad de la producción lechera para la planta de acopio de la **Municipalidad de Huata**.

**Justificación**: Digitaliza el pesaje diario por proveedor (~500 productores), registra parámetros de calidad (densidad para detección de adulteración), envía notificaciones push a proveedores y genera reportes automáticos. Resuelve el desorden de los registros manuales en hojas y minimiza errores de cálculo.

**Alcance específico (App Móvil)**:
- Registro de proveedores y acopiadores (con soporte offline)
- Registro de entregas diarias de leche
- Análisis de densidad (detección de adulteración)
- Notificaciones push (adulteración, reuniones, capacitaciones)
- Gestión de reuniones y control de asistencia (QR)
- Reportes y estadísticas de entregas

### Ideas Descartadas
- **AgroStock (Inventario de insumos agrícolas)**: Descartado por no alinearse al enfoque de análisis de datos cuantitativos de producción diaria.
- **VetConnect (Gestión de citas veterinarias)**: Descartado por alejarse del objetivo central de gestión de métricas numéricas y liquidación de pagos.

---

## 2. Organización del Equipo (Sprint 0 - Configuración Inicial)

### Asignación de Roles

| Rol | Responsable |
|-----|-------------|
| Product Owner & Líder Técnico | Olger Meza Rupa |
| Scrum Master & Backend (---) | Raphael Enrique Roger Mamani Vilca |
| Desarrollador Frontend (UI/UX - App Móvil) | Ciro Garry K. Machicado Velasquez |
| Desarrollador de Base de Datos (Modelado) | [Nombre 4] |

### Acuerdos de Sincronización
- **Reunión semanal fija**: Miércoles a las 19:00 hrs (vía Microsoft Teams / Discord).
- **Objetivo**: Sincronizar avances, revisar compromisos y resolver bloqueos.
- **Comunicación con cliente**: Coordinación con el regidor de la Municipalidad de Huata para visitas y validaciones.

---

## 3. Compromisos Individuales (Entregables)

### Olger Meza Rupa
- Redactar la visión general del proyecto y los casos de uso principales en el `README.md`.
- Estructurar el esqueleto inicial del repositorio (`/docs`, `/src`, `/tests`).
- Contactar al regidor de la Municipalidad de Huata para coordinar la visita.

### Raphael Enrique Roger Mamani Vilca
- Implementar el backend con **---** (API REST).
- Configurar el endpoint de **health-check** y conexión a base de datos.
- Crear el módulo base de **proveedores** (CRUD).

### Ciro Garry K. Machicado Velasquez
- Diseñar wireframes de baja fidelidad para 3 pantallas clave:
  1. Registro de entrega de leche (con soporte offline)
  2. Panel de notificaciones
  3. Gestión de reuniones y asistencia (QR)
- Definir la pila tecnológica para la app móvil (React Native / Flutter).

### [Nombre 4]
- Diseñar el **Modelo Entidad-Relación (MER)** con al menos 6 tablas base:
  1. Proveedores
  2. Acopiadores
  3. Entregas
  4. Controles de Densidad
  5. Notificaciones
  6. Reuniones / Asistencia
- Generar y documentar el script SQL inicial en `docs/database_schema.md`.

<!-- ---

## 4. Próximos Pasos

| Actividad | Responsable | Fecha límite |
|-----------|-------------|--------------|
| Visita a planta de Huata (validación de requerimientos) | Todo el equipo | 27 de agosto |
| Presentación de prototipo inicial | Olger, Ciro | 31 de agosto |
| Primer sprint review | Todo el equipo | 3 de septiembre |

---

## 5. Observaciones
- El proyecto se desarrollará en colaboración con la **Municipalidad de Huata**.
- La aplicación móvil debe funcionar en **zonas sin cobertura** (modo offline).
- Las notificaciones deben incluir un **encabezado distintivo** de la planta.
- Existen **dos formas de acopio**: directo (proveedor lleva a planta) y por acopiador (recolección en zonas). -->