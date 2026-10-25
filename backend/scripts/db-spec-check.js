const { swaggerSpec } = require('../src/config/swagger.config');

const refs = new Set();
const recorrer = (o) => {
  if (o && typeof o === 'object') {
    if (o.$ref) refs.add(o.$ref);
    for (const v of Object.values(o)) recorrer(v);
  }
};
recorrer(swaggerSpec);

const def = swaggerSpec.components.schemas;
const faltan = [...refs]
  .map((r) => r.replace('#/components/schemas/', ''))
  .filter((n) => !def[n]);

console.log('TOTAL RUTAS:', Object.keys(swaggerSpec.paths).length);
console.log('ESQUEMAS FALTANTES:', faltan.length ? faltan.join(', ') : '(ninguno)');

for (const ruta of Object.keys(swaggerSpec.paths)
  .filter((p) => /ruta|recorrido|upload/.test(p))) {
  for (const [metodo, op] of Object.entries(swaggerSpec.paths[ruta])) {
    const contenido = op.requestBody
      ? op.requestBody.content['application/json']?.schema?.$ref
        || op.requestBody.content['multipart/form-data']?.schema?.$ref
        || ''
      : '';
    console.log(
      `  ${metodo.toUpperCase().padEnd(6)} ${ruta.padEnd(50)} ${contenido.replace('#/components/schemas/', '')}`
    );
  }
}
