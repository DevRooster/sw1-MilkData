const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database.config');

const Usuario = sequelize.define(
  'usuario',
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
    email: {
      type: DataTypes.STRING(150),
      allowNull: false,
      unique: true,
      validate: {
        isEmail: true,
      },
    },
    password: {
      type: DataTypes.STRING(255),
      allowNull: false,
    },
    rolId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      field: 'rol_id',
    },
    proveedorId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      field: 'proveedor_id',
    },
    activo: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true,
    },
    ultimoAcceso: {
      type: DataTypes.DATE,
      allowNull: true,
    },
  },
  {
    tableName: 'usuario',
    timestamps: true,
    underscored: true,
    freezeTableName: true,
  }
);

module.exports = Usuario;
