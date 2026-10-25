const BaseController = require('./base.controller');
const recorridoService = require('../services/impl/recorrido.service');

class RecorridoController extends BaseController {
  constructor() {
    super();
    this.service = recorridoService;
    this.bindHandlers();
  }

  bindHandlers() {
    this.list = this.list.bind(this);
    this.findById = this.findById.bind(this);
    this.create = this.create.bind(this);
    this.update = this.update.bind(this);
    this.delete = this.delete.bind(this);
    this.iniciar = this.iniciar.bind(this);
    this.finalizar = this.finalizar.bind(this);
    this.cancelar = this.cancelar.bind(this);
    this.actual = this.actual.bind(this);
    this.atenderParada = this.atenderParada.bind(this);
    this.recolectarEnParada = this.recolectarEnParada.bind(this);
  }

  /** El recorrido en curso del acopiador autenticado. */
  actual(req, res, next) {
    return this.handle(req, res, next, async (contexto, trace) => ({
      item: await this.service.actual(contexto, trace),
    }), 'Recorrido actual');
  }

  /**
   * EN RUTA. Es el único cambio de estado que arranca la recolección: hasta
   * aquí el recorrido es solo un plan.
   */
  iniciar(req, res, next) {
    return this.handle(req, res, next, async (contexto, trace) => {
      const item = await this.service.iniciar(contexto, req.params.id, trace, req.body || {});
      return { item };
    }, 'Recorrido iniciado');
  }

  finalizar(req, res, next) {
    return this.handle(req, res, next, async (contexto, trace) => {
      const item = await this.service.finalizar(contexto, req.params.id, trace, req.body || {});
      return { item };
    }, 'Recorrido finalizado');
  }

  cancelar(req, res, next) {
    return this.handle(req, res, next, async (contexto, trace) => {
      const item = await this.service.cancelar(contexto, req.params.id, trace, req.body || {});
      return { item };
    }, 'Recorrido cancelado');
  }

  atenderParada(req, res, next) {
    return this.handle(req, res, next, async (contexto, trace) => {
      const item = await this.service.atenderParada(
        contexto, req.params.id, req.params.paradaId, req.body || {}, trace
      );
      return { item };
    }, 'Parada registrada');
  }

  /** Registra la recolección de una parada, ligada a su recorrido. */
  recolectarEnParada(req, res, next) {
    return this.handle(req, res, next, async (contexto, trace) => {
      const item = await this.service.recolectarEnParada(
        contexto, req.params.id, req.params.paradaId, req.body || {}, trace
      );
      return { item };
    }, 'Recolección registrada', 201);
  }
}

module.exports = new RecorridoController();
