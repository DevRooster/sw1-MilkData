const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database.config');

const Unidad = sequelize.define(
  'unidad',
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
    tipo: {
      type: DataTypes.ENUM('furgon', 'motocarga'),
      allowNull: false,
    },
    capacidad: {
      type: DataTypes.FLOAT,
      allowNull: false,
      defaultValue: 0,
    },
    cerrado: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false,
    },
    activo: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true,
    },
  },
  {
    tableName: 'unidad',
    timestamps: true,
    underscored: true,
    freezeTableName: true,
  }
);

module.exports = Unidad;
