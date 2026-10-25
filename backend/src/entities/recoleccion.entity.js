const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database.config');

/**
 * Recolección de leche en campo o en planta.
 *
 * Antes se llamaba `entrega`. El documento v7 la denomina `recoleccion`,
 * porque el acto es recolectar leche, no entregarla. La tabla y la columna
 * `control_calidad.recoleccion_id` se renombraron en la migración.
 */
const Recoleccion = sequelize.define(
  'recoleccion',
  {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true,
      allowNull: false,
    },
    plantaId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      field: 'planta_id',
    },
    proveedorId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      field: 'proveedor_id',
    },
    zonaId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      field: 'zona_id',
    },
    unidadId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      field: 'unidad_id',
    },
    usuarioId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      field: 'usuario_id',
    },
    /**
     * Parada del recorrido en la que se recogió, si aplica. Permite saber
     * que visita del día generó cada recolección.
     */
    recorridoParadaId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      unique: true,
      field: 'recorrido_parada_id',
    },
    cantidad: {
      type: DataTypes.FLOAT,
      allowNull: false,
      defaultValue: 0,
    },
    fecha: {
      type: DataTypes.DATEONLY,
      allowNull: false,
      // `allowNull` no coge el `""`: no es `null`, es una cadena, y MySQL la
      // convierte en "Invalid date" y responde con un **500**. Con `isDate` el
      // mismo caso da un 400 diciendo cuál era el formato.
      validate: {
        isDate: {
          msg: 'La fecha no es válida. Se escribe como AAAA-MM-DD.',
        },
      },
    },
    hora: {
      type: DataTypes.TIME,
      allowNull: true,
    },
    temperatura: {
      type: DataTypes.FLOAT,
      allowNull: true,
    },
    registradoEn: {
      type: DataTypes.ENUM('campo', 'planta'),
      allowNull: false,
      field: 'registrado_en',
      // Sin `isIn`, un valor raro llega a MySQL y sale como 500. Con esto da un
      // 400 que dice dónde se puede anotar la recogida.
      validate: {
        isIn: {
          args: [['campo', 'planta']],
          msg: 'Solo se admite campo o planta.',
        },
      },
    },
    sincronizado: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false,
    },
  },
  {
    tableName: 'recoleccion',
    timestamps: true,
    underscored: true,
    freezeTableName: true,
  }
);

module.exports = Recoleccion;
