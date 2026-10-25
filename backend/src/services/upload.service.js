const fs = require('fs/promises');
const crypto = require('crypto');
const { Op } = require('sequelize');
const {
  RECURSOS,
  TIPOS_PERMITIDOS,
  rutaRelativa,
  rutaEnDisco,
} = require('../config/upload.config');
const { badRequest, notFound } = require('../utils/http-error');
const {
  Planta, Usuario, Proveedor, Producto,
} = require('../entities');

/** Modelo y recurso al que se puede adjuntar una imagen. */
const DESTINOS = {
  planta: Planta,
  usuario: Usuario,
  proveedor: Proveedor,
  producto: Producto,
};

/** Nombre nuevo del archivo: UUID, sin depender del nombre que envió el cliente. */
function nombreArchivo(mimetype) {
  const extension = TIPOS_PERMITIDOS[mimetype];
  return `${crypto.randomUUID()}${extension}`;
}

function validarRecurso(recurso) {
  if (!RECURSOS.includes(recurso)) {
    throw badRequest(
      `Recurso inválido. Usa uno de: ${RECURSOS.join(', ')}.`
    );
  }
  return recurso;
}

/**
 * Guarda el archivo subido y devuelve su ruta relativa.
 * @param {object} archivo  Resultado de multer en memoria.
 * @param {number} plantaId
 * @param {string} recurso
 */
async function persistir(archivo, plantaId, recurso) {
  const nombre = nombreArchivo(archivo.mimetype);
  const destino = rutaEnDisco(rutaRelativa(plantaId, recurso, nombre));

  await fs.mkdir(require('path').dirname(destino), { recursive: true });
  await fs.writeFile(destino, archivo.buffer);

  return rutaRelativa(plantaId, recurso, nombre);
}

/** Borra el archivo de una imagen. No falla si ya no existe. */
async function eliminar(relativa) {
  if (!relativa || /^https?:\/\//i.test(relativa)) {
    // Es una URL externa: la API no es dueña del archivo.
    return false;
  }
  const destino = rutaEnDisco(relativa);
  if (!destino) {
    return false;
  }
  try {
    await fs.unlink(destino);
    return true;
  } catch (error) {
    if (error.code === 'ENOENT') {
      return false;
    }
    throw error;
  }
}

/**
 * Adjunta la imagen a un registro y borra la anterior si era local.
 *
 * Mantiene también la galería: la imagen que se pone aquí queda como principal y
 * la anterior se desmarca, pero **no se borra del disco**. Antes de que existiera
 * la galería, subir otra imagen dejaba el archivo anterior huérfano; ahora queda
 * en la galería del registro y se puede volver a poner.
 *
 * @param {object} contexto  `{ plantaId }` de la sesión.
 * @param {string} recurso   `usuario`, `producto`, `proveedor` o `planta`.
 * @param {number} id        Id del registro.
 * @param {string} relativa  Ruta de la imagen, o `null` para dejar la anterior.
 */
async function adjuntar(contexto, recurso, id, relativa) {
  validarRecurso(recurso);

  const modelo = DESTINOS[recurso];
  const registro = await modelo.findOne({
    where: { id, plantaId: contexto.plantaId },
  });
  if (!registro) {
    throw notFound('Registro no encontrado.');
  }

  await registro.update({ imagen: relativa });

  // La galería se toca con el modelo y no con `imagen.service` para no crear una
  // dependencia circular: `imagen.service` usa estas mismas funciones de disco.
  if (relativa) {
    const { Imagen } = require('../entities');

    const existentes = await Imagen.findAll({
      where: { recurso, recursoId: id, plantaId: contexto.plantaId },
      order: [['orden', 'ASC'], ['id', 'ASC']],
    });

    const repetida = existentes.find((imagen) => imagen.ruta === relativa);
    if (repetida) {
      await repetida.update({ principal: true });
    } else {
      await Imagen.create({
        plantaId: contexto.plantaId,
        recurso,
        recursoId: id,
        ruta: relativa,
        orden: existentes.length,
        principal: true,
      });
    }

    // Solo una puede ser principal. A las demás se les quita la marca.
    await Imagen.update(
      { principal: false },
      {
        where: {
          recurso,
          recursoId: id,
          plantaId: contexto.plantaId,
          ruta: { [Op.ne]: relativa },
        },
      }
    );
  }

  return registro.imagen;
}

module.exports = {
  DESTINOS,
  validarRecurso,
  nombreArchivo,
  persistir,
  eliminar,
  adjuntar,
};
