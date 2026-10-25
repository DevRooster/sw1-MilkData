const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database.config');

/**
 * Una imagen de un registro: su foto de perfil, la foto de un producto, el logo
 * de una planta.
 *
 * Existe para que un registro pueda tener **varias** imágenes. La columna
 * `imagen` de `usuario`, `producto`, `proveedor` y `planta` es un solo
 * `varchar(255)`: con ella, subir una segunda foto dejaba la primera huérfana en
 * disco porque nada la apuntaba.
 *
 * Esta tabla guarda todas. La columna `imagen` de cada registro sigue siendo la
 * **principal**, que es lo que se ve en las listas: es un dato desnormalizado a
 * propósito, para no tener que buscar en esta tabla cada vez que se pinta un
 * producto.
 */
const Imagen = sequelize.define(
  'imagen',
  {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true,
      allowNull: false,
    },
    // Aísla igual que el resto de lo operativo: una imagen de otra planta no se
    // ve ni se toca.
    plantaId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      field: 'planta_id',
    },
    /**
     * Tipo de registro al que pertenece: `usuario`, `producto`, `proveedor` o
     * `planta`.
     *
     * Es texto y no clave foránea porque el registro al que apunta puede estar
     * en cualquiera de cuatro tablas. Una tabla por recurso sería más purity y
     * cuatro veces más código para lo mismo.
     */
    recurso: {
      type: DataTypes.STRING(30),
      allowNull: false,
    },
    /** Id del registro. Sin clave foránea por lo mismo que `recurso`. */
    recursoId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      field: 'recurso_id',
    },
    /** Ruta relativa, igual que la columna `imagen` del registro. */
    ruta: {
      type: DataTypes.STRING(255),
      allowNull: false,
    },
    /** Orden manual dentro de la galería. Menor va primero. */
    orden: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
    },
    /**
     * Si es la que se muestra como la imagen del registro.
     *
     * Solo una por registro puede serlo; `upload.service` se encarga de quitarle
     * la marca a las demás al poner una nueva.
     */
    principal: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false,
    },
  },
  {
    tableName: 'imagen',
    timestamps: true,
    underscored: true,
    freezeTableName: true,
    indexes: [
      { name: 'idx_imagen_recurso', fields: ['recurso', 'recurso_id'] },
      { name: 'idx_imagen_planta', fields: ['planta_id'] },
    ],
  }
);

module.exports = Imagen;