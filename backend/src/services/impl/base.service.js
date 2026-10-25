const { notFound } = require('../../utils/http-error');
const { validarReferencias } = require('../referencias.service');
const { POR_PAGINA } = require('../../config/pagination.config');

/** Un objeto plano, sin clases ni funciones: algo que se pueda mezclar campo a campo. */
function esObjetoPlano(valor) {
  return valor !== null && typeof valor === 'object' && !Array.isArray(valor);
}

/**
 * Junta dos trozos de `where` sin pisarse.
 *
 * Hace falta porque **dos filtros distintos pueden apuntar a la misma columna**:
 * `desde` y `hasta` escriben los dos en `fecha`, uno con `[Op.gte]` y el otro
 * con `[Op.lte]`. Con `Object.assign`, el segundo machaca al primero y el rango se
 * convierte solo en una de sus dos mitades —sin avisar, porque no hay error—.
 *
 * Medido: `?desde=2027-01-01&hasta=2027-12-31` devolvía los registros de 2026
 * porque `hasta` se comió a `desde`.
 *
 * Se mezclan las claves normales **y las de símbolo**, porque los operadores de
 * Sequelize (`Op.gte`, `Op.lte`, ...) son precisamente símbolos y son la mitad
 * del motivo de este helper.
 */
function juntaWhere(base, trozo) {
  if (!esObjetoPlano(base) || !esObjetoPlano(trozo)) {
    return trozo;
  }

  const salida = { ...base };
  const claves = [...Object.keys(trozo), ...Object.getOwnPropertySymbols(trozo)];

  for (const clave of claves) {
    const valor = trozo[clave];

    // Si los dos lados son objetos —`{ [Op.gte]: x }` contra `{ [Op.lte]: y }`— se
    // acumulan. Si no, gana el que llega: un filtro explícito manda sobre lo
    // que hubiera, que es lo mismo que hacía `Object.assign` antes.
    salida[clave] = esObjetoPlano(salida[clave]) && esObjetoPlano(valor)
      ? { ...salida[clave], ...valor }
      : valor;
  }

  return salida;
}

/** Normaliza una instancia de Sequelize (o un objeto plano) a objeto plano. */
function toPlainObject(record) {
  if (!record) {
    return null;
  }
  return typeof record.toJSON === 'function' ? record.toJSON() : { ...record };
}

/**
 * Base de los servicios CRUD, con aislamiento por planta.
 *
 * Toda lectura y escritura se limita a `contexto.plantaId`, que viene de la
 * sesión (el JWT) y nunca del cuerpo de la petición. Un cliente no puede ver
 * ni escribir datos de otra planta.
 *
 * Las tablas que no se aíslan (rol, planta) se declaran con
 * `aislarPorPlanta: false` y reciben un contexto sin plantaId.
 *
 * Las escrituras pasan además por `validarReferencias`, que comprueba que los
 * registros referenciados pertenezcan a la misma planta que quien los apunta.
 *
 * @param {object} repository
 * @param {Function} [toDTO]
 * @param {object} [opciones]
 * @param {boolean} [opciones.aislarPorPlanta=true]
 */
class BaseService {
  constructor(repository, toDTO = toPlainObject, opciones = {}) {
    this.repository = repository;
    this.toDTO = toDTO;
    this.aislarPorPlanta = opciones.aislarPorPlanta !== false;
  }

  _plantaId(contexto) {
    const id = contexto && contexto.plantaId;
    if (!id) {
      throw new Error(
        'Falta plantaId en el contexto. Toda operación necesita la planta de la sesión.'
      );
    }
    return Number(id);
  }

  _where(contexto, where = {}) {
    if (!this.aislarPorPlanta) {
      return where;
    }
    return { ...where, plantaId: this._plantaId(contexto) };
  }

  _options(contexto, options = {}) {
    if (!this.aislarPorPlanta) {
      return options;
    }
    return { ...options, where: this._where(contexto, options.where) };
  }

  /**
   * Relaciones a traer con cada lectura. Vacío por defecto.
   *
   * Antes esto no existía y cada servicio que necesitaba nombres metía su propio
   * `include` sobrescribiendo `list` y `findById` enteros. Eso salía caro: la
   * copia de la lógica de paginación y de aislamiento se iba a desincronizar de
   * la base en cuanto esta cambiara, y ya había pasado —`recolecciones` nunca
   * llegó a declarar el suyo, así que su lista devolvía `proveedor: null` y la
   * app tenía que enseñar "Proveedor #1" donde debería decir "Juan Pérez".
   *
   * Declararlo aquí, en un método, quita esa clase de olvido.
   */
  _incluir() {
    return [];
  }

  /**
   * `_options` con las relaciones de `_incluir()` encima, si las hay.
   *
   * `include` solo se añade cuando hay algo que incluir: poner `include: []`
   * cambia la forma de la consulta sin cambiar el resultado, y ensucia las
   * pruebas que comparan las opciones que llegan a la consulta.
   */
  _opcionesDeLectura(contexto, options = {}) {
    const base = this._options(contexto, options);
    const declaradas = this._incluir();

    if (declaradas.length === 0) {
      return base;
    }

    // El `include` del llamante se respeta y se antepone al nuestro, y se
    // descartan las asociaciones que ya estaban. Sin ese filtro, un servicio que
    // pase a mano `ruta` y además lo declare en `_incluir()` metería la misma
    // relación dos veces, y Sequelize no lo perdona.
    const yaPedidas = new Set(
      (base.include || []).map((i) => i.association || i)
    );
    const faltan = declaradas.filter(
      (i) => !yaPedidas.has(i.association || i)
    );

    return faltan.length > 0 ? { ...base, include: [...(base.include || []), ...faltan] } : base;
  }

  /**
   * Vuelve a leer un registro recién escrito para traer sus relaciones.
   *
   * Hace falta porque `create` y `update` no tienen forma de devolverlas: la
   * fila acaba de insertarse y el DTO sale con las relaciones a `null`. Sin
   * esto, la respuesta a un alta sería peor que la de un `GET` de la misma fila,
   * que es justo la clase de sorpresa que hace que la app parezca intermitente.
   */
  async _conRelaciones(registro) {
    const incluir = this._incluir();

    if (incluir.length === 0) {
      return registro;
    }

    // `reload` solo existe en una instancia de Sequelize. Un repositorio que
    // devuelva un objeto plano no tiene nada que recargar, y entonces la
    // relación simplemente no viene: es una degradación, no un fallo. Sin esta
    // comprobación, un doble en las pruebas —o un repositorio alternativo— se
    // encontraría con un `TypeError` al escribir en vez de al leer.
    if (typeof registro.reload !== 'function') {
      return registro;
    }

    return registro.reload({ include: incluir });
  }

  /**
   * Listado paginado: devuelve los registros de la página junto con el estado
   * de la paginación.
   *
   * El conteo y las filas salen de una sola consulta (`findAndCountAll`). Con
   * dos consultas separadas alguien podría escribir entre medias y el `total`
   * no correspondría a los datos devueltos.
   *
   * Los servicios que cambian la forma del listado (agregar conteos, filtrar)
   * sobrescriben este método respetando la misma firma y devolviendo
   * `{ items, paginacion }`.
   *
   * @param {object} opciones
   * @param {number} [opciones.pagina=1]
   * @param {number} [opciones.limite=10]
   */
  /**
   * Filtros de listado que este recurso entiende.
   *
   * Un mapa de nombre de query a una funcion que devuelve la condicion de
   * Sequelize: `{ activo: (v) => ({ activo: v === 'true' }) }`. Lo sobrescribe
   * cada servicio que admita filtros.
   *
   * Existe por un motivo concreto: **antes, un filtro desconocido se ignoraba**.
   * `GET /unidades?tipo=motocarga` devolvia las cuatro unidades, dos de ellas
   * furgon, y la appensenaba una lista "filtrada" que no lo estaba. Un filtro
   * que no filtra es peor que uno que da error, porque quien lo usa no se
   * entera de que esta viendo de mas.
   *
   * Ahora lo desconocido se rechaza con un 400 que dice que se admite. Que cada
   * recurso declare lo suyo es lo que hace posible.
   */
  _filtros() {
    return {};
  }

  /**
   * Nombres de filtro que este recurso admite en su listado.
   *
   * Lo consulta el controller para rechazar lo que no reconoce. Por defecto son
   * las claves de `_filtros()`, y un servicio que sobrescribe `list` y aplica
   * sus filtros a mano lo declara aquí, porque si no el controller creería que
   * no admite ninguno y le rechazaría las consultas que él sí sabe responder.
   *
   * Existe como método aparte de `_filtros()` por eso: `_filtros()` construye el
   * `where`, y un servicio que construye el suyo no debería construir dos.
   */
  nombresDeFiltro() {
    return Object.keys(this._filtros());
  }

  /**
   * Traduce los filtros de la query a un `where`.
   *
   * **Lo que no reconoce se ignora, no se rechaza.** El rechazo vive en
   * `BaseController.list`, que es donde se sabe qué vino de una petición HTTP.
   * Aqui no se puede rechazar: `list` tambien la llaman otros servicios con sus
   * propias opciones (`where`, `include`, `order`), y esas no son filtros de
   * usuario sino condiciones internas que hay que respetar.
   *
   * Que el controller haya dejado pasar algo desconocido no significa que se
   * aplique: significa que no molesta. Un filtro que no existe nunca cambia el
   * resultado, que es justo lo que se queria evitar, y el 400 ya se ha dado
   * antes de llegar aqui.
   *
   * Los valores vacios se saltan sin mas: `?busqueda=` no es un filtro, es una
   * caja de busqueda vacia, y no debe devolver 400 por escribir y borrar.
   */
  _whereDeFiltros(query) {
    const reglas = this._filtros();
    let where = {};

    for (const clave of Object.keys(query || {})) {
      const valor = query[clave];

      // Los valores vacios se saltan sin mas: `?busqueda=` no es un filtro, es
      // una caja de busqueda vacia, y no debe devolver 400 por escribir y borrar.
      if (valor === undefined || valor === null || valor === '') {
        continue;
      }

      const construir = reglas[clave];
      if (construir === undefined) {
        continue;
      }

      // `juntaWhere` y no `Object.assign`: dos filtros pueden escribir en la
      // misma columna —`desde` y `hasta` sobre `fecha`— y con `Object.assign` el
      // segundo borraría al primero sin dejar rastro.
      where = juntaWhere(where, construir(valor));
    }

    return where;
  }

  async list(contexto, trace = [], { pagina = 1, limite = POR_PAGINA, ...resto } = {}) {
    trace.push('service');
    const numeroPagina = Number(pagina);
    const numeroLimite = Number(limite);

    // El `where` que venga en `resto` se mezcla con el de los filtros, no se
    // sustituye. Un llamante interno puede querer sus propias condiciones (por
    // ejemplo `activo: true`) y un filtro declarado puede querer las suyas; si
    // el segundo `where` pisara al primero, la condición interna se perdería
    // sin que nadie se diera cuenta.
    const where = { ...(resto.where || {}), ...this._whereDeFiltros(resto) };

    // `where` solo se pasa si hay algo que decir. Para las tablas que no se aíslan
    // por planta, `_options` devuelve las opciones tal cual, y añadir un
    // `where: {}` vacío cambiaría la forma de la llamada sin cambiar el
    // resultado: ruido para quien lea la consulta, y ruido para la prueba que
    // la comprueba.
    //
    // **El guard cuenta también las claves de símbolo, y no es un detalle.** Un
    // filtro como `busqueda` devuelve `{ [Op.or]: [...] }` y no tiene ni una sola
    // clave de texto: con `Object.keys(...).length` el `where` salía vacío, el
    // guard lo tiraba, y `?busqueda=Perez` devolvía **todos** los proveedores
    // como si no hubiera filtrado nada. Medido, y llevaba así desde que el filtro
    // de búsqueda se escribió.
    const diceAlgo = Object.keys(where).length + Object.getOwnPropertySymbols(where).length > 0;
    const opciones = diceAlgo ? { ...resto, where } : { ...resto };

    const { count, rows } = await this.repository.findAndCountAll({
      ...this._opcionesDeLectura(contexto, opciones),
      limit: numeroLimite,
      offset: (numeroPagina - 1) * numeroLimite,
    }, trace);

    return {
      items: rows.map((registro) => this.toDTO(registro)),
      paginacion: this._paginacion(numeroPagina, numeroLimite, count),
    };
  }

  _paginacion(pagina, limite, total) {
    const totalPaginas = limite > 0 ? Math.ceil(total / limite) : 0;
    return {
      pagina,
      limite,
      total,
      totalPaginas,
      tieneAnterior: pagina > 1,
      tieneSiguiente: pagina < totalPaginas,
    };
  }

  async findById(contexto, id, trace = []) {
    trace.push('service');
    const registro = await this.repository.findOne(
      this._opcionesDeLectura(contexto, { where: { id } }),
      trace
    );
    if (!registro) {
      throw notFound();
    }
    return this.toDTO(registro);
  }

  async create(contexto, data, trace = []) {
    trace.push('service');
    const datos = this.aislarPorPlanta
      ? { ...data, plantaId: this._plantaId(contexto) }
      : data;

    await this._validarReferencias(contexto, datos);

    const creado = await this.repository.create(datos, trace);
    return this.toDTO(await this._conRelaciones(creado));
  }

  async update(contexto, id, data, trace = []) {
    trace.push('service');
    // Un plantaId del cuerpo se descarta: nadie mueve registros entre plantas.
    const { plantaId: _ignorado, ...cambios } = data || {};

    const registro = await this.repository.findOne(
      this._opcionesDeLectura(contexto, { where: { id } }),
      trace
    );
    if (!registro) {
      throw notFound();
    }

    await this._validarReferencias(contexto, cambios, registro);

    await registro.update(cambios);
    return this.toDTO(await this._conRelaciones(registro));
  }

  /**
   * Comprueba que los registros referenciados existan y sean de la misma planta.
   *
   * Al actualizar solo se validan los campos presentes en el cuerpo: los que
   * no se tocaron se comprobaron al crearse. El modelo se toma del registro
   * existente, porque quien llama puede haber cambiado la fila que edita.
   */
  async _validarReferencias(contexto, datos, registroExistente = null) {
    const modelo = registroExistente
      ? registroExistente.constructor
      : this.repository.model;

    if (!modelo) {
      return;
    }

    const plantaId = registroExistente
      ? registroExistente.plantaId
      : contexto.plantaId;

    await validarReferencias(modelo, datos, { plantaId });
  }

  async delete(contexto, id, trace = []) {
    trace.push('service');
    const registro = await this.repository.findOne({
      where: this._where(contexto, { id }),
    }, trace);
    if (!registro) {
      throw notFound();
    }
    await registro.destroy();
    return true;
  }

  /** Lista los registros cuyo campo equivale a `value`, dentro de la planta. */
  async listByField(contexto, field, value, trace = [], options = {}) {
    trace.push('service');
    const registros = await this.repository.findAllByField(
      field,
      value,
      this._opcionesDeLectura(contexto, options)
    );
    return registros.map((registro) => this.toDTO(registro));
  }

  /** Primer registro cuyo campo equivale a `value`, dentro de la planta. */
  async findOneByField(contexto, field, value, trace = [], options = {}) {
    trace.push('service');
    const registro = await this.repository.findByField(
      field,
      value,
      this._opcionesDeLectura(contexto, options)
    );
    return this.toDTO(registro);
  }
}

module.exports = BaseService;
module.exports.toPlainObject = toPlainObject;
