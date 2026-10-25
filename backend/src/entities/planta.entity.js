const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database.config');

/**
 * Raíz del aislamiento. Todo registro operativo pertenece a una planta, y
 * un usuario solo ve los datos de la suya.
 *
 * El documento v7 contemplates multi-planta con `planta_id` en casi todas las
 * tablas. Aquí se implementa desde el inicio para no tener que migrar después.
 */
const Planta = sequelize.define(
  'planta',
  {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true,
      allowNull: false,
    },
    nombre: {
      type: DataTypes.STRING(120),
      allowNull: false,
      unique: true,
      validate: {
        notEmpty: true,
      },
    },
    codigo: {
      type: DataTypes.STRING(20),
      allowNull: false,
      unique: true,
      validate: {
        notEmpty: true,
      },
    },
    direccion: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    imagen: {
      type: DataTypes.STRING(255),
      allowNull: true,
      defaultValue: null,
    },
    activo: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true,
    },
  },
  {
    tableName: 'planta',
    timestamps: true,
    underscored: true,
    freezeTableName: true,
  }
);

module.exports = Planta;
