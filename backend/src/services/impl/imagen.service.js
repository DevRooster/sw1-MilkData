const {
  Planta, Usuario, Proveedor, Producto, Imagen,
} = require('../../entities');
const imagenRepository = require('../../repositories/imagen.repository');
const { badRequest, notFound, httpError } = require('../../utils/http-error');

/** Modelo al que apunta cada recurso. */
const DESTINOS = {
  planta: Planta,
  usuario: Usuario,
  proveedor: Proveedor,
  producto: Producto,
};

/** Recursos que aceptan galería. */
const RECURSOS = Object.keys(DESTINOS);

/** Máximo de imágenes por registro. */
const LIMITE_POR_REGISTRO = 10;

function validarRecurso(recurso) {
  if (!RECURSOS.includes(recurso)) {
    throw badRequest(`Recurso inválido. Usa uno de: ${RECURSOS.join(', ')}.`);
  }
  return recurso;
}

/**
 * Busca el registro destino y se asegura de que sea de la planta de la sesión.
 *
 * Es la misma comprobación que hace `upload.service.adjuntar`: sin ella, un
 * admin podría colgar imágenes de un registro de otra planta.
 */
async function registroDe(recurso, id, plantaId) {
  validarRecurso(recurso);
  const modelo = DESTINOS[recurso];
  const registro = await modelo.findOne({ where: { id, plantaId } });

  if (!registro) {
    throw notFound('Registro no encontrado.');
  }

  return registro;
}

/**
 * Añade una imagen a la galería de un registro.
 *
 * La primera en llegar es la principal. A partir de ahí la principal solo cambia
 * si se pide explícitamente, para que subir una foto nueva no robe el sitio a
 * la que ya estaba.
 */
async function agregar(contexto, recurso, recursoId, ruta) {
  const registro = await registroDe(recurso, recursoId, contexto.plantaId);

  const existentes = await imagenRepository.findDeRecurso(
    recurso, recursoId, contexto.plantaId
  );

  if (existentes.length >= LIMITE_POR_REGISTRO) {
    throw httpError(
      `Ese registro ya tiene ${LIMITE_POR_REGISTRO} imágenes, que es el máximo.`,
      400,
    );
  }

  // La ruta no se repite: dos filas apuntando al mismo archivo no aportan nada y
  // harían que borrar una dejara la otra colgando de un archivo que ya no existe.
  const repetida = existentes.find((imagen) => imagen.ruta === ruta);
  if (repetida) {
    return repetida;
  }

  const imagen = await Imagen.create({
    plantaId: contexto.plantaId,
    recurso,
    recursoId,
    ruta,
    orden: existentes.length,
    principal: existentes.length === 0,
  });

  // La columna `imagen` del registro apunta a la principal, para que las listas
  // no tengan que consultar esta tabla.
  if (imagen.principal) {
    await registro.update({ imagen: ruta });
  }

  return imagen;
}

/** Imágenes de un registro, la principal primero. */
async function listar(contexto, recurso, recursoId) {
  await registroDe(recurso, recursoId, contexto.plantaId);
  const imagenes = await imagenRepository.findDeRecurso(
    recurso, recursoId, contexto.plantaId
  );

  const principal = imagenes.find((imagen) => imagen.principal);
  const resto = imagenes.filter((imagen) => imagen !== principal);

  return principal ? [principal, ...resto] : resto;
}

/** Marca una imagen como principal y actualiza la columna del registro. */
async function marcarPrincipal(contexto, imagenId) {
  const imagen = await imagenRepository.findDeId(imagenId, contexto.plantaId);
  if (!imagen) {
    throw notFound('Imagen no encontrada.');
  }

  // Solo se desmarca la que ya lo era: si no, se borrarían todas las marcas y
  // quedaría el registro sin principal, que es justo lo que se quiere evitar.
  await Imagen.update(
    { principal: false },
    {
      where: {
        recurso: imagen.recurso,
        recursoId: imagen.recursoId,
        plantaId: contexto.plantaId,
        principal: true,
        id: { [require('sequelize').Op.ne]: imagen.id },
      },
    }
  );

  await imagen.update({ principal: true });

  const registro = await registroDe(
    imagen.recurso, imagen.recursoId, contexto.plantaId
  );
  await registro.update({ imagen: imagen.ruta });

  return imagen;
}

/**
 * Quita una imagen de la galería.
 *
 * Si era la principal, la siguiente pasa a serlo: el registro no puede quedar
 * sin imagen apuntando a una que ya no existe.
 */
async function quitar(contexto, imagenId) {
  const imagen = await imagenRepository.findDeId(imagenId, contexto.plantaId);
  if (!imagen) {
    throw notFound('Imagen no encontrada.');
  }

  const eraPrincipal = imagen.principal;
  const { recurso, recursoId, ruta } = imagen;
  await imagen.destroy();

  if (!eraPrincipal) {
    return { ruta, eraPrincipal: false };
  }

  const registro = await registroDe(recurso, recursoId, contexto.plantaId);
  const siguiente = await imagenRepository.findDeRecurso(
    recurso, recursoId, contexto.plantaId
  );

  if (siguiente.length) {
    await siguiente[0].update({ principal: true });
    await registro.update({ imagen: siguiente[0].ruta });
  } else {
    await registro.update({ imagen: null });
  }

  return { ruta, eraPrincipal: true };
}

module.exports = {
  DESTINOS,
  RECURSOS,
  LIMITE_POR_REGISTRO,
  validarRecurso,
  registroDe,
  agregar,
  listar,
  marcarPrincipal,
  quitar,
};