const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database.config');

const Entrega = sequelize.define(
  'entrega',
  {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true,
      allowNull: false,
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
    cantidad: {
      type: DataTypes.FLOAT,
      allowNull: false,
      defaultValue: 0,
    },
    fecha: {
      type: DataTypes.DATEONLY,
      allowNull: false,
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
    },
    sincronizado: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false,
    },
  },
  {
    tableName: 'entrega',
    timestamps: true,
    underscored: true,
    freezeTableName: true,
  }
);

module.exports = Entrega;
