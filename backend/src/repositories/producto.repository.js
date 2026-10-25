const BaseRepository = require('./base.repository');
const { Producto } = require('../entities');

class ProductoRepository extends BaseRepository {
  constructor() {
    super(Producto);
  }
}

module.exports = new ProductoRepository();
module.exports.ProductoRepository = ProductoRepository;
