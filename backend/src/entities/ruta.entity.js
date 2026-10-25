const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database.config');

/**
 * Ruta de recolección: la que el acopiador/chófer ya conoce y sabe recorrer.
 *
 * Una ruta tiene paradas ordenadas (`ruta_parada`). Un proveedor pertenece a
 * una sola ruta activa a la vez, que se guarda en `proveedor.ruta_id`.
 */
const Ruta = sequelize.define(
  'ruta',
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
    nombre: {
      type: DataTypes.STRING(120),
      allowNull: false,
      validate: { notEmpty: true },
    },
    codigo: {
      type: DataTypes.STRING(20),
      allowNull: false,
      validate: { notEmpty: true },
    },
    descripcion: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    horaInicio: {
      type: DataTypes.TIME,
      allowNull: true,
    },
    horaFin: {
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
    tableName: 'ruta',
    timestamps: true,
    underscored: true,
    freezeTableName: true,
    indexes: [{ unique: true, fields: ['planta_id', 'codigo'], name: 'uq_ruta_planta_codigo' }],
  }
);

module.exports = Ruta;
