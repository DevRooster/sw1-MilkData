/**
 * Verifica que la documentación de Swagger no mienta.
 *
 * La comparación de rutas montadas contra rutas documentadas se hace por HTTP
 * en lugar de leer el stack interno de Express: Express 5 no expone el prefijo
 * con el que se montó un router, así que esa información no es accesible.
 *
 * El distinguidor entre "la ruta no existe" y "el registro no existe" es el
 * formato de la respuesta: una ruta inexistente cae en el final handler de
 * Express y devuelve HTML, mientras que un 404 de la API es JSON.
 */
const { swaggerSpec } = require('../../src/config/swagger.config');
const { app, request, closeDatabase } = require('../helpers/auth');

const SIN_DOCUMENTAR = ['/health', '/api-docs.json'];

/** Rutas de prueba: los parámetros se rellenan con un valor plausible. */
function urlDeEjemplo(ruta) {
  return ruta.replace(/\{(\w+)\}/g, (m, nombre) => {
    if (/Id$/.test(nombre)) return '1';
    if (nombre === 'codigo') return 'SINEXISTENTE';
    return 'prueba';
  });
}

function esHtmlDeRutaInexistente(res) {
  return res.status === 404
    && typeof res.text === 'string'
    && res.text.includes('Cannot ');
}

function metodosDe(ruta) {
  return Object.keys(swaggerSpec.paths[ruta]);
}

afterAll(async () => {
  await closeDatabase();
});

describe('Swagger documenta rutas que existen', () => {
  const documentadas = Object.keys(swaggerSpec.paths)
    .filter((ruta) => !SIN_DOCUMENTAR.includes(ruta));

  test.each(documentadas)('%s está montada', async (ruta) => {
    const url = urlDeEjemplo(ruta);

    for (const metodo of metodosDe(ruta)) {
      // Sin token a propósito: lo que importa es que la ruta exista, y casi
      // todas las de esta API responden 401 cuando no hay token.
      const res = await request(app)[metodo](url);
      expect(esHtmlDeRutaInexistente(res)).toBe(false);
    }
  });
});

describe('El módulo de rutas y recorridos está documentado', () => {
  test.each([
    ['/rutas', ['get', 'post']],
    ['/rutas/{id}', ['get', 'put', 'delete']],
    ['/rutas/codigo/{codigo}', ['get']],
    ['/rutas/{id}/recomendada', ['get']],
    ['/rutas/proveedores/{proveedorId}/sugerencia', ['get']],
    ['/rutas/{id}/paradas', ['post']],
    ['/rutas/{id}/paradas/orden', ['put']],
    ['/rutas/{id}/paradas/{paradaId}', ['delete']],
    ['/recorridos', ['get', 'post']],
    ['/recorridos/{id}', ['get', 'put', 'delete']],
    ['/recorridos/actual', ['get']],
    ['/recorridos/{id}/iniciar', ['post']],
    ['/recorridos/{id}/finalizar', ['post']],
    ['/recorridos/{id}/cancelar', ['post']],
    ['/recorridos/{id}/paradas/{paradaId}/atender', ['post']],
    ['/recorridos/{id}/paradas/{paradaId}/recolectar', ['post']],
    ['/uploads/api', ['get', 'post', 'delete']],
  ])('%s declara %s', (ruta, metodos) => {
    expect(swaggerSpec.paths[ruta]).toBeTruthy();
    for (const metodo of metodos) {
      expect(swaggerSpec.paths[ruta][metodo]).toBeTruthy();
    }
  });
});

describe('Coherencia de los esquemas', () => {
  test('ningún esquema referenciado está ausente', () => {
    const referenciados = new Set();
    const recorrer = (objeto) => {
      if (objeto && typeof objeto === 'object') {
        if (objeto.$ref) referenciados.add(objeto.$ref.replace('#/components/schemas/', ''));
        for (const valor of Object.values(objeto)) recorrer(valor);
      }
    };
    recorrer(swaggerSpec);

    const definidos = swaggerSpec.components.schemas;
    const faltan = [...referenciados].filter((n) => !definidos[n]);

    expect(faltan).toEqual([]);
  });

  test('los endpoints que reciben datos declaran su esquema', () => {
    for (const ruta of Object.keys(swaggerSpec.paths)) {
      if (!/^\/(rutas|recorridos|uploads)/.test(ruta)) continue;

      for (const [metodo, operacion] of Object.entries(swaggerSpec.paths[ruta])) {
        if (metodo !== 'post' && metodo !== 'put') continue;
        // Cancelar acepta un cuerpo opcional con el motivo.
        if (ruta.endsWith('/cancelar')) continue;

        expect(operacion.requestBody).toBeTruthy();
      }
    }
  });

  test('todos los endpoints declaran al menos un código de respuesta', () => {
    for (const [ruta, metodos] of Object.entries(swaggerSpec.paths)) {
      for (const [metodo, operacion] of Object.entries(metodos)) {
        const respuestas = Object.keys(operacion.responses || {});
        expect(respuestas.length).toBeGreaterThan(0);
        void metodo;
        void ruta;
      }
    }
  });

  test('los endpoints protegidos piden token', () => {
    const sinSeguridad = [];
    for (const [ruta, metodos] of Object.entries(swaggerSpec.paths)) {
      if (ruta === '/health') continue;
      if (ruta.startsWith('/auth/login') || ruta.startsWith('/auth/register')) continue;

      for (const [metodo, operacion] of Object.entries(metodos)) {
        const pideToken = (operacion.security || []).some((s) => s.bearerAuth);
        if (!pideToken) sinSeguridad.push(`${metodo.toUpperCase()} ${ruta}`);
      }
    }

    expect(sinSeguridad).toEqual([]);
  });
});
