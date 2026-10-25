const {
  persistir,
  eliminar,
} = require('../services/upload.service');
const imagenService = require('../services/impl/imagen.service');
const { successResponse } = require('../utils/response');
const { badRequest } = require('../utils/http-error');

/**
 * Galería de imágenes de un registro.
 *
 * `POST /uploads/api/:recurso/:id`   añade una imagen al registro
 * `GET  /uploads/api/:recurso/:id`   lista sus imágenes, la principal primero
 * `DELETE /uploads/api/imagen/:id`   quita una imagen de la galería
 * `PUT /uploads/api/imagen/:id/principal`  cambia cuál es la principal
 *
 * La carga del archivo va en `subirArchivo`, el middleware de multer. Aquí solo
 * se orchestran archivo, disco y base de datos.
 */

/** `POST /uploads/api/:recurso/:id` */
async function agregar(req, res, next) {
  try {
    const { recurso } = req.params;
    const recursoId = Number(req.params.id);

    if (!req.file) {
      throw badRequest('Falta el archivo en el campo "archivo".');
    }

    imagenService.validarRecurso(recurso);

    const ruta = await persistir(req.file, req.contexto.plantaId, recurso);

    try {
      const imagen = await imagenService.agregar(req.contexto, recurso, recursoId, ruta);
      return successResponse(
        res,
        {
          imagen: imagen.ruta,
          idImagen: imagen.id,
          recurso,
          recursoId,
          principal: imagen.principal,
          bytes: req.file.size,
        },
        'Imagen agregada',
        201
      );
    } catch (error) {
      // Si no se pudo registrar, el archivo no se queda huérfano en disco.
      await eliminar(ruta).catch(() => {});
      throw error;
    }
  } catch (error) {
    return next(error);
  }
}

/** `GET /uploads/api/:recurso/:id` */
async function listar(req, res, next) {
  try {
    const { recurso } = req.params;
    const recursoId = Number(req.params.id);

    const imagenes = await imagenService.listar(req.contexto, recurso, recursoId);

    return successResponse(
      res,
      {
        recurso,
        recursoId,
        total: imagenes.length,
        imagenes: imagenes.map((imagen) => ({
          id: imagen.id,
          imagen: imagen.ruta,
          orden: imagen.orden,
          principal: imagen.principal,
        })),
      },
      'Imágenes del registro'
    );
  } catch (error) {
    return next(error);
  }
}

/** `PUT /uploads/api/imagen/:id/principal` */
async function marcarPrincipal(req, res, next) {
  try {
    const imagen = await imagenService.marcarPrincipal(
      req.contexto,
      Number(req.params.id)
    );

    return successResponse(
      res,
      { id: imagen.id, imagen: imagen.ruta, principal: true },
      'Imagen principal actualizada'
    );
  } catch (error) {
    return next(error);
  }
}

/** `DELETE /uploads/api/imagen/:id` */
async function quitar(req, res, next) {
  try {
    const resultado = await imagenService.quitar(req.contexto, Number(req.params.id));

    // El archivo se borra después de quitar la fila: si el borrado del disco
    // falla, queda una fila que apunta a un archivo que sí existe, que es
    // recuperable. Al revés, un archivo huérfano no lo señala nadie.
    const eliminado = await eliminar(resultado.ruta);

    return successResponse(
      res,
      { imagen: resultado.ruta, eliminado, eraPrincipal: resultado.eraPrincipal },
      'Imagen quitada'
    );
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  agregar,
  listar,
  marcarPrincipal,
  quitar,
};