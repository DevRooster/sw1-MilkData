const express = require('express');
const fs = require('fs');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const swaggerUi = require('swagger-ui-express');
const routes = require('./routes/index.routes');
const { swaggerSpec } = require('./config/swagger.config');
const { errorMiddleware } = require('./middlewares/error.middleware');
const { UPLOADS_ROOT } = require('./config/upload.config');

const app = express();

// Las imagenes se sirven desde uploads/ en la raiz del proyecto.
fs.mkdirSync(UPLOADS_ROOT, { recursive: true });

app.use(cors());
app.use(helmet({
  contentSecurityPolicy: {
    // Las claves van en kebab-case: helmet no normaliza `imgSrc` a `img-src`,
    // y mezclar estilos produce directivas duplicadas.
    directives: {
      ...helmet.contentSecurityPolicy.getDefaultDirectives(),
      'connect-src': ["'self'"],
      // Las imagenes locales se sirven desde /uploads, en el mismo origen.
      'img-src': ["'self'", 'data:'],
    },
  },
  // Los archivos de /uploads se sirven como imagenes, no como scripts.
  crossOriginResourcePolicy: { policy: 'cross-origin' },
}));
app.use(morgan('combined'));
app.use('/uploads', express.static(UPLOADS_ROOT, {
  index: false,
  dotfiles: 'deny',
  maxAge: '7d',
  setHeaders(res) {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Content-Disposition', 'inline');
  },
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.get('/health', (req, res) => {
  res.json({ success: true, data: { status: 'ok' }, message: 'Servicio disponible', errors: [] });
});
app.get('/api-docs.json', (req, res) => {
  res.json(swaggerSpec);
});
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));
app.use('/', routes);
app.use(errorMiddleware);

module.exports = app;
