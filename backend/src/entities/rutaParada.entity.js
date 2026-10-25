const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database.config');

/**
 * Parada de una ruta: un proveedor, en una posición del recorrido.
 * `orden` es el orden recomendado que el acopiador ya conoce.
 */
const RutaParada = sequelize.define(
  'rutaParada',
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
    rutaId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      field: 'ruta_id',
    },
    proveedorId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      field: 'proveedor_id',
    },
    orden: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 1,
    },
    /** Hora estimada de recojo, para que el móvil avise al chofer. */
    horaEstimada: {
      type: DataTypes.TIME,
      allowNull: true,
    },
    activa: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true,
    },
  },
  {
    tableName: 'ruta_parada',
    timestamps: true,
    underscored: true,
    freezeTableName: true,
    indexes: [
      { unique: true, fields: ['ruta_id', 'proveedor_id'], name: 'uq_ruta_parada_proveedor' },
      { unique: true, fields: ['ruta_id', 'orden'], name: 'uq_ruta_parada_orden' },
    ],
  }
);

module.exports = RutaParada;
