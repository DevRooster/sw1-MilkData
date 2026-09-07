const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database.config');

const Zona = sequelize.define(
  'zona',
  {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true,
      allowNull: false,
    },
    nombre: {
      type: DataTypes.STRING(100),
      allowNull: false,
      validate: {
        notEmpty: true,
      },
    },
    ruta: {
      type: DataTypes.STRING(255),
      allowNull: false,
    },
    horaInicio: {
      type: DataTypes.TIME,
      allowNull: true,
    },
    horaFin: {
      type: DataTypes.TIME,
      allowNull: true,
    },
    unidadId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      field: 'unidad_id',
    },
    activo: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true,
    },
  },
  {
    tableName: 'zona',
    timestamps: true,
    underscored: true,
    freezeTableName: true,
  }
);

module.exports = Zona;
