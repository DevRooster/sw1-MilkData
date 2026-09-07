const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database.config');

const ControlCalidad = sequelize.define(
  'controlCalidad',
  {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true,
      allowNull: false,
    },
    entregaId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      unique: true,
      field: 'entrega_id',
    },
    usuarioId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      field: 'usuario_id',
    },
    grasa: {
      type: DataTypes.FLOAT,
      allowNull: true,
    },
    proteina: {
      type: DataTypes.FLOAT,
      allowNull: true,
    },
    lactosa: {
      type: DataTypes.FLOAT,
      allowNull: true,
    },
    densidad: {
      type: DataTypes.FLOAT,
      allowNull: true,
    },
    temperatura: {
      type: DataTypes.FLOAT,
      allowNull: true,
    },
    aguaAnadida: {
      type: DataTypes.FLOAT,
      allowNull: true,
      field: 'agua_anadida',
    },
    ph: {
      type: DataTypes.FLOAT,
      allowNull: true,
    },
    resultado: {
      type: DataTypes.ENUM('pura', 'adulterada'),
      allowNull: false,
      defaultValue: 'pura',
    },
  },
  {
    tableName: 'control_calidad',
    timestamps: true,
    underscored: true,
    freezeTableName: true,
  }
);

module.exports = ControlCalidad;
