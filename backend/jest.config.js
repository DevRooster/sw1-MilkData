module.exports = {
  testEnvironment: 'node',
  collectCoverageFrom: [
    'src/**/*.js',
    '!src/app.js',
    '!src/entities/**',
  ],
  coverageReporters: ['text-summary', 'lcov'],
  coverageThreshold: {
    global: {
      statements: 80,
      branches: 70,
      functions: 80,
      lines: 80,
    },
  },
  testPathIgnorePatterns: ['/node_modules/', '/tests/helpers/'],

  // Dos suites a la vez, no una por núcleo.
  //
  // Cada worker de Jest abre su propio pool de conexiones contra MySQL, y
  // MySQL vive dentro de Docker Desktop: en una máquina de 8 GB, lanzar una
  // suite por núcleo deja tan poco para la base que la **primera** consulta de
  // cada worker —un `findOne` sobre una tabla de seis filas— se pasa de los 5
  // segundos y revienta el `beforeAll`. Medido: 80 timeouts y cero fallos de
  // aserción, con un juego distinto de ficheros cada vez según la carga.
  //
  // Los scripts `test:integration` y `test:rutas` ya usaban `--runInBand`; esto
  // hace que `npm test` no se porte de otra manera.
  maxWorkers: 2,

  // 30 segundos en vez de los 5 por defecto de Jest.
  //
  // No es para toleratear consultas lentas: una consulta de integración tarda
  // milisegundos. Es para el arranque, donde abrir el pool y cargar el seed
  // compite por la RAM con Docker. Con 5 segundos, el primer hook de cada suite
  // es una moneda al aire y los fallos que salen son de la máquina, no del
  // código —y un fallo que no significa nada enseña a ignorar los que sí.
  testTimeout: 30000,
  hookTimeout: 30000,
};
