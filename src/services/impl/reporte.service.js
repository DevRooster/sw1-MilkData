const entregaRepository = require('../../repositories/entrega.repository');
const calidadRepository = require('../../repositories/controlCalidad.repository');
const proveedorRepository = require('../../repositories/proveedor.repository');

class ReporteService {
  async contraste(trace = []) {
    trace.push('service');
    const entregas = await entregaRepository.findAll({}, trace);
    const grouped = new Map();

    for (const entrega of entregas) {
      const key = `${entrega.proveedorId}:${entrega.fecha}`;
      const current = grouped.get(key) || {
        proveedorId: entrega.proveedorId,
        fecha: entrega.fecha,
        cantidadCampo: 0,
        cantidadPlanta: 0,
      };
      if (entrega.registradoEn === 'campo') {
        current.cantidadCampo += Number(entrega.cantidad || 0);
      } else if (entrega.registradoEn === 'planta') {
        current.cantidadPlanta += Number(entrega.cantidad || 0);
      }
      grouped.set(key, current);
    }

    return [...grouped.values()].map((item) => {
      const diferencia = item.cantidadPlanta - item.cantidadCampo;
      return {
        ...item,
        diferencia,
        porcentajeDiferencia: item.cantidadCampo ? (diferencia / item.cantidadCampo) * 100 : 0,
      };
    });
  }

  async calidad(trace = []) {
    trace.push('service');
    const controles = await calidadRepository.findAll({}, trace);
    return [buildQualityAverage(null, controles)];
  }

  async calidadProveedor(trace = []) {
    trace.push('service');
    const [proveedores, controles, entregas] = await Promise.all([
      proveedorRepository.findAll({}, trace),
      calidadRepository.findAll({}),
      entregaRepository.findAll({}),
    ]);
    const providerByDelivery = new Map(entregas.map((entrega) => [entrega.id, entrega.proveedorId]));
    const controlsByProvider = new Map();

    for (const control of controles) {
      const proveedorId = providerByDelivery.get(control.entregaId);
      const providerControls = controlsByProvider.get(proveedorId) || [];
      providerControls.push(control);
      controlsByProvider.set(proveedorId, providerControls);
    }

    return proveedores
      .filter((proveedor) => controlsByProvider.has(proveedor.id))
      .map((proveedor) => ({
        proveedorId: proveedor.id,
        muestras: controlsByProvider.get(proveedor.id).length,
        promedios: buildQualityAverage(proveedor.id, controlsByProvider.get(proveedor.id)).promedios,
      }));
  }
}

function average(records, field) {
  const values = records.map((record) => Number(record[field])).filter((value) => Number.isFinite(value));
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
