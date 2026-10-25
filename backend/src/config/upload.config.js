const path = require('path');
/**
 * Configuración de subida de imágenes.
 *
 * Los archivos viven en `uploads/` dentro de la raíz del proyecto, ordenados
 * por planta y recurso: `uploads/<plantaId>/<recurso>/<uuid>.<ext>`.
 * La columna `imagen` de cada entidad guarda la ruta relativa, no la absoluta,
 * para que la base no dependa de dónde esté desplegado.
 */
const UPLOADS_ROOT = path.join(__dirname, '..', '..', 'uploads');

const RECURSOS = ['planta', 'usuario', 'proveedor', 'producto'];

const TIPOS_PERMITIDOS = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'image/gif': '.gif',
};

const LIMITE_BYTES = Number(process.env.UPLOAD_MAX_BYTES || 5 * 1024 * 1024);

/** Ruta relativa que se guarda en la base, con separadores `/`. */
function rutaRelativa(plantaId, recurso, nombreArchivo) {
  return `/uploads/${plantaId}/${recurso}/${nombreArchivo}`;
}

/**
 * Ruta en disco a partir de la ruta guardada en la base.
 *
 * La columna guarda la ruta relativa como se sirve por HTTP (`/uploads/1/...`),
 * y el middleware estático está montado en `/uploads`, así que hay que quitar
 * ese prefijo antes de resolver contra la carpeta real.
 *
 * Devuelve `null` para todo lo que no sea una ruta bajo `uploads/`: URLs
 * externas, rutas absolutas y cualquier intento de salir con `../`. Es lo que
 * impide que una ruta mal escrita en la base lea o borre un archivo de fuera.
 */
function rutaEnDisco(relativa) {
  if (!relativa || typeof relativa !== 'string') {
    return null;
  }

  // Una URL no es un archivo nuestro: no se sirve ni se borra desde la API.
  if (/^[a-z][a-z0-9+.-]*:/i.test(relativa) || relativa.startsWith('//')) {
    return null;
  }

  const raiz = path.resolve(UPLOADS_ROOT);
  const normalizada = relativa.replace(/\\/g, '/');
  const sinPrefijo = normalizada.replace(/^\/?uploads\//, '').replace(/^\/+/, '');

  // Tiene que seguir siendo una ruta relativa dentro de la carpeta.
  if (!sinPrefijo || path.isAbsolute(sinPrefijo)) {
    return null;
  }

  const absoluta = path.resolve(raiz, sinPrefijo);
  if (absoluta !== raiz && !absoluta.startsWith(raiz + path.sep)) {
    return null;
  }
  return absoluta;
}

const SUBIDA = {
  storage: undefined,
  limits: { fileSize: LIMITE_BYTES, files: 1 },
  fileFilter(_req, file, callback) {
    const extension = TIPOS_PERMITIDOS[file.mimetype];
    if (!extension) {
      return callback(new Error(`Tipo de imagen no permitido: ${file.mimetype}`));
    }
    return callback(null, true);
  },
};

module.exports = {
  UPLOADS_ROOT,
  RECURSOS,
  TIPOS_PERMITIDOS,
  LIMITE_BYTES,
  SUBIDA,
  rutaRelativa,
  rutaEnDisco,
};
