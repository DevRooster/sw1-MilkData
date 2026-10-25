const BaseController = require('./base.controller');
const rutaService = require('../services/impl/ruta.service');

class RutaController extends BaseController {
  constructor() {
    super();
    this.service = rutaService;
    this.bindHandlers();
  }

  bindHandlers() {
    this.list = this.list.bind(this);
    this.findById = this.findById.bind(this);
    this.create = this.create.bind(this);
    this.update = this.update.bind(this);
    this.delete = this.delete.bind(this);
    this.findByCodigo = this.findByCodigo.bind(this);
    this.recomendada = this.recomendada.bind(this);
    this.sugerencia = this.sugerencia.bind(this);
    this.agregarParada = this.agregarParada.bind(this);
    this.reordenarParadas = this.reordenarParadas.bind(this);
    this.quitarParada = this.quitarParada.bind(this);
  }

  findByCodigo(req, res, next) {
    return this.handle(req, res, next, async (contexto, trace) => {
      const item = await this.service.findByCodigo(contexto, req.params.codigo, trace);
      return { item };
    }, 'Consulta exitosa');
  }

  /**
   * Ruta recomendada: paradas en orden, con el estado de cada una en el
   * recorrido indicado. Es lo que consume el móvil del acopiador.
   */
  recomendada(req, res, next) {
    return this.handle(req, res, next, async (contexto, trace) => {
      const recorridoId = req.query.recorridoId ? Number(req.query.recorridoId) : null;
      const data = await this.service.recomendada(contexto, req.params.id, trace, { recorridoId });
      return { ruta: data };
    }, 'Ruta recomendada');
  }

  /** Sugiere en qué ruta debería entrar un proveedor que aún no tiene. */
  sugerencia(req, res, next) {
    return this.handle(req, res, next, async (contexto, trace) => {
      return this.service.sugerirRuta(contexto, req.params.proveedorId, trace);
    }, 'Sugerencia de ruta');
  }

  agregarParada(req, res, next) {
    return this.handle(req, res, next, async (contexto, trace) => {
      const item = await this.service.agregarParada(contexto, req.params.id, req.body, trace);
      return { item };
    }, 'Parada agregada', 201);
  }

  reordenarParadas(req, res, next) {
    return this.handle(req, res, next, async (contexto, trace) => {
      const ordenes = Array.isArray(req.body) ? req.body : req.body.ordenes;
      const ruta = await this.service.reordenarParadas(contexto, req.params.id, ordenes, trace);
      return { ruta };
    }, 'Orden actualizado');
  }

  quitarParada(req, res, next) {
    return this.handle(req, res, next, async (contexto, trace) => {
      return this.service.quitarParada(contexto, req.params.id, req.params.paradaId, trace);
    }, 'Parada quitada');
  }
}

module.exports = new RutaController();
