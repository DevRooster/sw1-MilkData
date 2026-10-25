const { Op } = require('sequelize');
const { referenciasDe, REFERENCIAS_GLOBALES } = require('../config/referencias.config');
const { badRequest } = require('../utils/http-error');

/**
 * Comprueba que los registros referenciados existan y pertenezcan a la misma
 * planta que quien los referencia.
 *
 * La clave foránea solo garantiza que el id exista. Esta validación es la que
 * evita que una recolección de Huata termine apuntando a la zona de Cusco.
 *
 * El mensaje no distingue entre "no existe" y "es de otra planta": en ambos
 * casos se responde 400 con el mismo texto, para no confirmar la existencia de
 * datos ajenos.
 */

/** Etiquetas legibles para los mensajes de error. */
const NOMBRES = {
  acopiadorId: 'el acopiador',
  ayudanteUsuarioId: 'el ayudante',
  proveedorId: 'el proveedor',
  usuarioId: 'el usuario',
  zonaId: 'la zona',
  unidadId: 'la unidad',
  rutaId: 'la ruta',
  rutaParadaId: 'la parada de la ruta',
  recorridoId: 'el recorrido',
  recorridoParadaId: 'la parada del recorrido',
  recoleccionId: 'la recolección',
  rolId: 'el rol',
};

function etiqueta(campo) {
  return NOMBRES[campo] || `el campo ${campo}`;
}

/**
 * @param {object} modelo        Modelo del registro que se va a escribir.
 * @param {object} datos         Valores que se van a guardar.
 * @param {object} opciones
 * @param {number} opciones.plantaId  Planta contra la que se compara.
 * @returns {Promise<void>}     Lanza 400 si alguna referencia no sirve.
 */
async function validarReferencias(modelo, datos, { plantaId }) {
  if (!modelo || !datos) {
    return;
  }

  const mapa = referenciasDe(modelo);
  const campos = Object.keys(mapa).filter((campo) => {
    const valor = datos[campo];
    return valor !== undefined && valor !== null && valor !== '';
  });

  if (!campos.length) {
    return;
  }

  // Se agrupan por modelo destino para no lanzar una consulta por campo.
  const porModelo = new Map();
  for (const campo of campos) {
    const destino = mapa[campo];
    if (!porModelo.has(destino)) {
      porModelo.set(destino, []);
    }
    porModelo.get(destino).push({ campo, valor: datos[campo] });
  }

  for (const [destino, pares] of porModelo) {
    const ids = [...new Set(pares.map((p) => Number(p.valor)))].filter((n) => Number.isInteger(n));
    if (!ids.length) {
      continue;
    }

    // Las referencias globales no se filtran por planta: existen o no.
    const where = { id: { [Op.in]: ids } };
    if (!REFERENCIAS_GLOBALES.has(destino) && plantaId) {
      where.plantaId = plantaId;
    }

    const encontrados = await destino.findAll({ where, attributes: ['id'] });
    const validos = new Set(encontrados.map((r) => Number(r.id)));

    const invalido = pares.find((p) => !validos.has(Number(p.valor)));
    if (invalido) {
      throw badRequest(
        `${etiqueta(invalido.campo)} indicada (${invalido.valor}) no existe en esta planta.`
      );
    }
  }
}

module.exports = {
  validarReferencias,
};
