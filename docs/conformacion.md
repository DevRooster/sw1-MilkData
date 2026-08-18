# Actas del Equipo:

**Proyecto:** MilkData  
**Repositorio:** `sw1-MilkData`

---

## Acta N° 1 — Semana 1

* **Fecha:** 17 de agosto de 2026
* **Asistentes:**
  * Olger Meza Rupa
  * Raphael Enrique Roger Mamani Vilca
  * Ciro Garry K. Machicado Velasquez
  * [Nombre 4]

---

### 1. Definición de la Idea de Proyecto

#### **Idea Elegida**
* **MilkData:** Sistema integral para el registro, control de calidad y trazabilidad de la producción lechera.
* **Justificación:** Digitaliza el pesaje diario por proveedor, registra parámetros de calidad (grasa, proteína, temperatura) y genera reportes automáticos de pago. Resuelve el desorden de las planillas físicas en papel y minimiza errores de cálculo.

#### **Ideas Descartadas**
* **AgroStock** *(Inventario de insumos agrícolas):* Descartado por no alinearse al enfoque de análisis de datos cuantitativos de producción diaria.
* **VetConnect** *(Gestión de citas veterinarias):* Descartado por alejarse del objetivo central de gestión de métricas numéricas y liquidación de pagos.

---

### 2. Organización del Equipo (Sprint 0 - Configuración Inicial)

#### **Asignación de Roles**

| Rol | Responsable |
| :--- | :--- |
| **Product Owner & Líder Técnico** | Olger Meza Rupa |
| **Scrum Master & Backend (API / Rutas)** | Raphael Enrique Roger Mamani Vilca |
| **Desarrollador Frontend (UI / UX)** | Ciro Garry K. Machicado Velasquez |
| **Desarrollador de Base de Datos (Modelado)** | [Nombre 4] |

#### **Acuerdos de Sincronización**
* **Reunión semanal fija:** Miércoles a las **19:00 hrs** (vía Microsoft Teams / Discord).
* **Objetivo:** Sincronizar avances, revisar compromisos y resolver bloqueos.

---

### 3. Compromisos Individuales (Entregables)

* **Olger Meza Rupa**
  * Redactar la visión general del proyecto y los casos de uso principales en el `README.md`.
  * Estructurar el esqueleto inicial del repositorio (`/docs`, `/src`, `/tests`).

* **Raphael Enrique Roger Mamani Vilca**
  * Investigar y definir el framework backend (propuestas: **FastAPI** , **Flask** , **Express**).
  * Implementar el endpoint básico de *health-check* y configurar la conexión a la base de datos local.

* **Ciro Garry K. Machicado Velasquez**
  * Diseñar wireframes de baja fidelidad para 3 pantallas clave: *Registro de pesaje*, *Tablero de calidad* y *Reporte de pagos*.
  * Subir los diseños a la carpeta `/docs/design`.
  * Definir la pila frontend (**React** o **Vue**).

* **[Nombre 4]**
  * Diseñar el Modelo Entidad-Relación (MER) con al menos 4 tablas base: `Proveedores`, `Lotes_Produccion`, `Controles_Calidad` y `Pagos`.
  * Generar y documentar el script SQL inicial en `docs/database_schema.md`.