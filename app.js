const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const swaggerUi = require('swagger-ui-express');
const routes = require('./src/routes/index.routes');
const { swaggerSpec } = require('./src/config/swagger.config');
const { errorMiddleware } = require('./src/middlewares/error.middleware');

const app = express();

app.use(cors());
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      ...require('helmet').contentSecurityPolicy.getDefaultDirectives(),
      connectSrc: ["'self'", 'http://localhost:3000', 'http://127.0.0.1:3000'],
    },
  },
}));
app.use(morgan('combined'));
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
