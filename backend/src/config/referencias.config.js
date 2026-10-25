const {
  Rol, Planta, Unidad, Zona, Usuario, Proveedor, Ruta, RutaParada,
  Recorrido, RecorridoParada, Recoleccion, ControlCalidad, Notificacion,
  Asistencia, Producto, Evento,
} = require('../entities');

/**
 * Referencias entre tablas que deben pertenecer a la misma planta.
 *
 * Una clave foránea solo garantiza que el registro exista. Alguien puede
 * enviar un `zonaId` de otra planta y la base lo acepta, dejando datos de una
 * sede apuntando a la zona de otra. Aquí se declara qué campo apunta a qué
 * tabla, para que la validación sea explícita y auditable.
 *
 * Quedan fuera a propósito:
 *  - `plantaId`: es la planta de la sesión, nunca viene del cuerpo.
 *  - `rolId`: `rol` es global por diseño, el mismo rol significa lo mismo en
 *    todas las plantas. Se valida solo que exista.
 */
const REFERENCIAS = {
  [Unidad.name]: {
    acopiadorId: Usuario,
  },
  [Zona.name]: {
    rutaId: Ruta,
    unidadId: Unidad,
  },
  [Usuario.name]: {
    rolId: Rol,
  },
  [Proveedor.name]: {
    zonaId: Zona,
    rutaId: Ruta,
    usuarioId: Usuario,
  },
  [RutaParada.name]: {
    rutaId: Ruta,
    proveedorId: Proveedor,
  },
  [Recorrido.name]: {
    rutaId: Ruta,
    unidadId: Unidad,
    acopiadorId: Usuario,
    ayudanteUsuarioId: Usuario,
  },
  [RecorridoParada.name]: {
    recorridoId: Recorrido,
    rutaParadaId: RutaParada,
    proveedorId: Proveedor,
    recoleccionId: Recoleccion,
  },
  [Recoleccion.name]: {
    proveedorId: Proveedor,
    zonaId: Zona,
    unidadId: Unidad,
    usuarioId: Usuario,
    recorridoParadaId: RecorridoParada,
  },
  [ControlCalidad.name]: {
    recoleccionId: Recoleccion,
    usuarioId: Usuario,
  },
  [Notificacion.name]: {
    proveedorId: Proveedor,
    usuarioId: Usuario,
  },
  [Asistencia.name]: {
    proveedorId: Proveedor,
    usuarioId: Usuario,
    // `eventoId` apunta al evento del catálogo, y va declarado porque la clave
    // foránea solo garantiza que el evento **exista**, no que sea de esta planta.
    // Sin esto, una asistencia de una planta podría apuntar a un evento de otra
    // y la lista saldría con charlas que aquí nunca hubo — que es justo lo que el
    // catálogo de eventos pretende evitar.
    //
    // La asociación se llama `eventoRelacion` porque el nombre `evento` ya lo
    // ocupa la columna de texto, que sigue ahí y sigue siendo obligatoria.
    eventoId: Evento,
  },
};

/**
 * Referencias que no llevan `planta_id` y por eso no se comparan contra la
 * planta del registro. Se validan igual: tiene que existir.
 */
const REFERENCIAS_GLOBALES = new Set([Rol, Planta]);

/**
 * Devuelve las referencias que aplican a un modelo.
 *
 * Un repositorio de prueba puede no tener modelo asociado; en ese caso no hay
 * nada que validar y se devuelven cero referencias.
 *
 * @param {object} modelo
 * @returns {object} mapa `campo -> modelo referenciado`
 */
function referenciasDe(modelo) {
  if (!modelo || !modelo.name) {
    return {};
  }
  return REFERENCIAS[modelo.name] || {};
}

module.exports = {
  REFERENCIAS,
  REFERENCIAS_GLOBALES,
  referenciasDe,
};
