const recoleccionRepository = require('../../repositories/recoleccion.repository');
const calidadRepository = require('../../repositories/controlCalidad.repository');
const proveedorRepository = require('../../repositories/proveedor.repository');

/**
 * Reportes. Todos se calculan solo con los datos de la planta de la sesión:
 * el `where` de planta se aplica en cada consulta, igual que en los servicios
 * CRUD, para que un reporte no pueda revelar información de otra planta.
 */
class ReporteService {
  /** Opciones de lectura ya con el filtro de planta dentro de `where`. */
  _options(contexto, where = {}) {
    const plantaId = Number(contexto && contexto.plantaId);
    if (!plantaId) {
      throw new Error('Falta plantaId en el contexto del reporte.');
    }
    return { where: { ...where, plantaId } };
  }

  async contraste(contexto, trace = []) {
    trace.push('service');
    const recolecciones = await recoleccionRepository.findAll(
      this._options(contexto),
      trace
    );
    const grouped = new Map();

    for (const recoleccion of recolecciones) {
      const key = `${recoleccion.proveedorId}:${recoleccion.fecha}`;
      const current = grouped.get(key) || {
        proveedorId: recoleccion.proveedorId,
        fecha: recoleccion.fecha,
        cantidadCampo: 0,
        cantidadPlanta: 0,
      };
      if (recoleccion.registradoEn === 'campo') {
        current.cantidadCampo += Number(recoleccion.cantidad || 0);
      } else if (recoleccion.registradoEn === 'planta') {
        current.cantidadPlanta += Number(recoleccion.cantidad || 0);
      }
      grouped.set(key, current);
    }

    return [...grouped.values()].map((item) => {
      const diferencia = item.cantidadPlanta - item.cantidadCampo;
      return {
        ...item,
        diferencia,
        porcentajeDiferencia: item.cantidadCampo
          ? (diferencia / item.cantidadCampo) * 100
          : 0,
      };
    });
  }

  /** Promedios de calidad globales de la planta. Acepta `proveedorId` para acotar. */
  async calidad(contexto, trace = [], proveedorId = null) {
    trace.push('service');

    if (!proveedorId) {
      const controles = await calidadRepository.findAll(this._options(contexto), trace);
      return [buildQualityAverage(null, controles)];
    }

    const controles = await this._controlesDeProveedor(contexto, proveedorId, trace);
    return [buildQualityAverage(Number(proveedorId), controles)];
  }

  /** Reporte de calidad agrupado por proveedor, dentro de la planta. */
  async calidadProveedor(contexto, trace = []) {
    trace.push('service');
    const where = this._options(contexto);
    const [proveedores, controles, recolecciones] = await Promise.all([
      proveedorRepository.findAll(where, trace),
      calidadRepository.findAll(where),
      recoleccionRepository.findAll(where),
    ]);

    const proveedorPorRecoleccion = new Map(
      recolecciones.map((recoleccion) => [recoleccion.id, recoleccion.proveedorId])
    );
    const controlesPorProveedor = new Map();

    for (const control of controles) {
      const proveedorId = proveedorPorRecoleccion.get(control.recoleccionId);
      const lista = controlesPorProveedor.get(proveedorId) || [];
      lista.push(control);
      controlesPorProveedor.set(proveedorId, lista);
    }

    return proveedores
      .filter((proveedor) => controlesPorProveedor.has(proveedor.id))
      .map((proveedor) => ({
        ...buildQualityAverage(proveedor.id, controlesPorProveedor.get(proveedor.id)),
        proveedor: {
          id: proveedor.id,
          nombre: proveedor.nombre,
          apellido: proveedor.apellido,
          codigo: proveedor.codigo,
        },
      }));
  }

  async _controlesDeProveedor(contexto, proveedorId, trace) {
    const recolecciones = await recoleccionRepository.findAll(
      this._options(contexto, { proveedorId }),
      trace
    );
    const ids = recolecciones.map((recoleccion) => recoleccion.id);
    if (!ids.length) {
      return [];
    }
    return calidadRepository.findAll(
      this._options(contexto, { recoleccionId: ids }),
      trace
    );
  }
}

/**
 * Promedio de un campo. Los valores ausentes (null, undefined o no numéricos)
 * se excluyen del cálculo en lugar de contarse como cero: promediar un `null`
 * como `0` bajaría artificialmente el resultado.
 */
function average(records, field) {
  const values = records
    .map((record) => record[field])
    .filter((value) => value !== null && value !== undefined && value !== '')
    .map(Number)
    .filter((value) => Number.isFinite(value));

  return values.length ? values.reduce((sum, value) => sum + value, 0) / values.length : null;
}

function buildQualityAverage(proveedorId, records) {
  return {
    proveedorId,
    muestras: records.length,
    promedios: {
      grasa: average(records, 'grasa'),
      proteina: average(records, 'proteina'),
      lactosa: average(records, 'lactosa'),
      densidad: average(records, 'densidad'),
      temperatura: average(records, 'temperatura'),
      aguaAnadida: average(records, 'aguaAnadida'),
      ph: average(records, 'ph'),
    },
  };
}

module.exports = new ReporteService();
module.exports.ReporteService = ReporteService;
