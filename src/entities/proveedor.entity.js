const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database.config');

const Proveedor = sequelize.define(
  'proveedor',
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
    apellido: {
      type: DataTypes.STRING(100),
      allowNull: false,
    },
    dni: {
      type: DataTypes.STRING(20),
      allowNull: false,
      unique: true,
      validate: {
        notEmpty: true,
      },
    },
    telefono: {
      type: DataTypes.STRING(30),
      allowNull: true,
    },
    codigo: {
      type: DataTypes.STRING(50),
      allowNull: false,
      unique: true,
    },
    zonaId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      field: 'zona_id',
    },
    usuarioId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      unique: true,
      field: 'usuario_id',
    },
    activo: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true,
    },
  },
  {
    tableName: 'proveedor',
    timestamps: true,
    underscored: true,
    freezeTableName: true,
  }
);

module.exports = Proveedor;
