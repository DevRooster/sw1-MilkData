function layer(req, res, next) {
  req.layerTrace = ['routes'];
  next();
}

module.exports = layer;
