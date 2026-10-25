const { Op } = require('sequelize');
const BaseRepository = require('./base.repository');
const { Imagen } = require('../entities');

class ImagenRepository extends BaseRepository {
  constructor() {
    super(Imagen);
  }

  /**
   * Imágenes de un registro, en el orden en que se muestran.
   *
   * `orden` manda y el id desempata: sin el desempate, dos imágenes con el mismo
   * orden podrían salir en cualquier orden entre llamadas, y la galería
   * reordenaría sola al recargar.
   */
  findDeRecurso(recurso, recursoId, plantaId) {
    // Con `this.` explícito: un método que se quita el receptor pierde el
    // `this.model` que `BaseRepository` deja en el constructor.
    return this.findAll({
      where: { recurso, recursoId, plantaId },
      order: [
        ['orden', 'ASC'],
        ['id', 'ASC'],
      ],
    });
  }

  /** Solo la imagen principal de un registro, o `null`. */
  findPrincipal(recurso, recursoId, plantaId) {
    return this.findOne({
      where: { recurso, recursoId, plantaId, principal: true },
    });
  }

  /** Una imagen por su id, respetando la planta de la sesión. */
  findDeId(id, plantaId) {
    return this.findOne({ where: { id, plantaId } });
  }

  /** La imagen principal de un registro según la ruta guardada. */
  findPrincipalPorRuta(recurso, recursoId, plantaId, ruta) {
    return this.findOne({ where: { recurso, recursoId, plantaId, ruta } });
  }

  /** Todas las imágenes principal de varios registros, de una consulta. */
  findPrincipalesDe(recurso, recursoIds, plantaId) {
    return this.findAll({
      where: { recurso, recursoId: { [Op.in]: recursoIds }, plantaId, principal: true },
    });
  }
}

module.exports = new ImagenRepository();
module.exports.ImagenRepository = ImagenRepository;