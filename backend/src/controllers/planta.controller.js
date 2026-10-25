const BaseController = require('./base.controller');
const plantaService = require('../services/impl/planta.service');
const { successResponse } = require('../utils/response');
const { notFound } = require('../utils/http-error');

/**
 * Plantas. A diferencia del resto, no se aísla: una planta es el límite, no
 * algo que esté dentro de él. Por eso los handlers no usan el contexto de
 * sesión, solo exigen un token válido.
 */
class PlantaController extends BaseController {
  constructor() {
    super();
    this.service = plantaService;
    this.bindHandlers();
  }

  bindHandlers() {
    this.list = this.list.bind(this);
    this.findById = this.findById.bind(this);
    this.create = this.create.bind(this);
    this.update = this.update.bind(this);
    this.delete = this.delete.bind(this);
    this.findByCodigo = this.findByCodigo.bind(this);
  }

  /** El contexto es irrelevante aquí, pero `handle` lo exige. */
  _contexto() {
    return {};
  }

  findByCodigo(req, res, next) {
    return this.handle(req, res, next, async (_contexto, trace) => {
      const item = await this.service.findByCodigo(req.params.codigo, trace);
      if (!item) {
        throw notFound();
      }
      return { item };
    }, 'Consulta exitosa');
  }

  /** Crear una planta: solo un admin de otra planta puede hacerlo. */
  create(req, res, next) {
    const trace = req.layerTrace || ['routes'];
    trace.push('controller');
    return Promise.resolve()
      .then(() => plantaService.create({}, req.body, trace))
      .then((item) => successResponse(res, { item, layerTrace: trace }, 'Planta creada', 201))
      .catch(next);
  }
}

module.exports = new PlantaController();
