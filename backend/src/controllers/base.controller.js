const { successResponse } = require('../utils/response');
const { badRequest, notFound } = require('../utils/http-error');
const { POR_PAGINA, LIMITE_MAXIMO, noEsEnteroPositivo } = require('../config/pagination.config');

/**
 * Base de los controllers CRUD.
 *
 * `handle` exige que la petición traiga `req.contexto` (la planta de la
 * sesión). Si no existe, es que la ruta quedó sin `authMiddleware` y se rechaza
 * con 500 en vez de exponer datos.
 */
class BaseController {
  _contexto(req) {
    if (!req.contexto) {
      throw new Error(
        'Petición sin contexto de planta. La ruta debe usar authMiddleware.'
      );
    }
    return req.contexto;
  }

  /**
   * Lee `pagina` y `limite` de la query.
   *
   * Un valor inválido se rechaza con 400 en vez de ignorarse: si el móvil
   * manda `limite=0` por un error de cálculo, conviene que lo sepa y no que
   * reciba en silencio una página de 10.
   */
  _paginacion(req) {
    const { pagina, limite } = req.query || {};
    const paginaNumero = pagina === undefined ? 1 : Number(pagina);
    const limiteNumero = limite === undefined ? POR_PAGINA : Number(limite);

    if (noEsEnteroPositivo(paginaNumero)) {
      throw badRequest('pagina debe ser un entero mayor que cero.');
    }
    if (noEsEnteroPositivo(limiteNumero)) {
      throw badRequest('limite debe ser un entero mayor que cero.');
    }
    if (limiteNumero > LIMITE_MAXIMO) {
      throw badRequest(`limite no puede ser mayor que ${LIMITE_MAXIMO}.`);
    }

    return { pagina: paginaNumero, limite: limiteNumero };
  }

  async handle(req, res, next, operation, message, statusCode) {
    const trace = req.layerTrace || ['routes'];
    trace.push('controller');
    try {
      const data = await operation(this._contexto(req), trace);
      return successResponse(res, { ...data, layerTrace: trace }, message, statusCode);
    } catch (error) {
      return next(error);
    }
  }

  list(req, res, next) {
    return this.handle(req, res, next, async (contexto, trace) => {
      // Se reenvía la query completa para que cada servicio aplique sus
      // filtros (`?estado=`, `?fecha=`...), y encima la paginación ya
      // validada, que tiene prioridad sobre lo que venga sin comprobar.
      const opciones = { ...(req.query || {}), ...this._paginacion(req) };

      // Un filtro que no existe se rechaza en vez de ignorarse.
      //
      // La comprobación va aquí y no en el servicio a propósito: hay servicios
      // que sobrescriben `list` y nunca pasarían por el filtro de la base. Con
      // el guardián puesto solo en la base, `GET /rutas?busqueda=zzzz`
      // devolvía las seis rutas sin avisar de nada. El controller es el único
      // punto por el que pasan todos.
      const admitidos = new Set(['pagina', 'limite', ...this.service.nombresDeFiltro()]);
      const desconocidos = Object.keys(req.query || {})
        .filter((clave) => !admitidos.has(clave));

      if (desconocidos.length > 0) {
        const lista = [...admitidos].filter((c) => c !== 'pagina' && c !== 'limite');
        throw badRequest(
          `Filtro desconocido: ${desconocidos.join(', ')}. `
          + `Este recurso admite: ${lista.length > 0 ? lista.join(', ') : 'ninguno'}.`
        );
      }

      return this.service.list(contexto, trace, opciones);
    }, 'Consulta exitosa');
  }

  findById(req, res, next) {
    return this.handle(req, res, next, async (contexto, trace) => {
      const item = await this.service.findById(contexto, req.params.id, trace);
      return { item };
    }, 'Consulta exitosa');
  }

  create(req, res, next) {
    return this.handle(req, res, next, async (contexto, trace) => {
      const item = await this.service.create(contexto, this._payload(req), trace);
      return { item };
    }, 'Registro creado', 201);
  }

  update(req, res, next) {
    return this.handle(req, res, next, async (contexto, trace) => {
      const item = await this.service.update(contexto, req.params.id, this._payload(req), trace);
      return { item };
    }, 'Registro actualizado');
  }

  delete(req, res, next) {
    return this.handle(req, res, next, async (contexto, trace) => {
      await this.service.delete(contexto, req.params.id, trace);
      return { deleted: true };
    }, 'Registro eliminado');
  }

  /**
   * Recorta un arreglo yatraído a la página pedida y arma el bloque de estado.
   *
   * Los filtros por ruta resuelven sobre un conjunto acotado (los proveedores
   * de una zona, las recolecciones de un día), así que aquí no hace falta
   * consultar el total: ya se sabe.
   */
  _recortar(lista, req) {
    const { pagina, limite } = this._paginacion(req);
    const total = lista.length;
    const desde = (pagina - 1) * limite;

    return {
      items: lista.slice(desde, desde + limite),
      paginacion: {
        pagina,
        limite,
        total,
        totalPaginas: limite > 0 ? Math.ceil(total / limite) : 0,
        tieneAnterior: pagina > 1,
        tieneSiguiente: pagina * limite < total,
      },
    };
  }

  /**
   * Filtro por un parametro de ruta, resuelto en `this.filterMethod`.
   *
   * Cuando el filtro devuelve un único registro va en `data.item`; cuando
   * devuelve varios, van paginados en `data.items`.
   */
  filter(req, res, next) {
    return this.handle(req, res, next, async (contexto, trace) => {
      const value = req.params.value;
      const resultado = await this.service[this.filterMethod](contexto, value, trace);
      const filtro = { campo: this.filterField, valor: value };

      if (!Array.isArray(resultado)) {
        return { item: resultado || null, filtro };
      }
      return { ...this._recortar(resultado, req), filtro };
    }, 'Consulta exitosa');
  }

  /**
   * Asigna la imagen de un registro. La API no recibe binarios: el cliente
   * sube la imagen a su almacenamiento y envía la URL.
   */
  setImagen(req, res, next) {
    return this.handle(req, res, next, async (contexto, trace) => {
      if (!Object.prototype.hasOwnProperty.call(req.body || {}, 'imagen')) {
        throw badRequest('El campo imagen es obligatorio.');
      }

      const item = await this.service.update(
        contexto,
        req.params.id,
        { imagen: req.body.imagen },
        trace
      );
      return { item };
    }, 'Imagen actualizada');
  }

  /** Filtro auxiliar con un metodo libre del servicio que devuelve una lista. */
  filterWith(metodo, campo) {
    return (req, res, next) => this.handle(req, res, next, async (contexto, trace) => {
      const value = req.params.value;
      const resultado = await this.service[metodo](contexto, value, trace);
      const filtro = { campo, valor: value };

      if (!Array.isArray(resultado)) {
        return { item: resultado || null, filtro };
      }
      return { ...this._recortar(resultado, req), filtro };
    }, 'Consulta exitosa');
  }

  /** Filtro que devuelve un unico registro en `data.item`. */
  findWith(metodo, mensaje = 'Consulta exitosa') {
    return (req, res, next) => this.handle(req, res, next, async (contexto, trace) => {
      const item = await this.service[metodo](contexto, req.params.value, trace);
      if (!item) {
        throw notFound();
      }
      return { item };
    }, mensaje);
  }

  _payload(req) {
    return req.body || {};
  }
}

module.exports = BaseController;
