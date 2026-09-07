const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database.config');

const Asistencia = sequelize.define(
  'asistencia',
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
    usuarioId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      field: 'usuario_id',
    },
    evento: {
      type: DataTypes.STRING(150),
      allowNull: false,
    },
    fecha: {
      type: DataTypes.DATEONLY,
      allowNull: false,
    },
    registradoPor: {
      type: DataTypes.ENUM('QR', 'manual'),
      allowNull: false,
      field: 'registrado_por',
    },
  },
  {
    tableName: 'asistencia',
    timestamps: true,
    underscored: true,
    freezeTableName: true,
  }
);

module.exports = Asistencia;
