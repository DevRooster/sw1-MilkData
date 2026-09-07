const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database.config');

const Notificacion = sequelize.define(
  'notificacion',
  {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true,
      allowNull: false,
    },
    proveedorId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      field: 'proveedor_id',
    },
    usuarioId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      field: 'usuario_id',
    },
    tipo: {
      type: DataTypes.ENUM('adulteracion', 'reunion', 'capacitacion'),
      allowNull: false,
    },
    titulo: {
      type: DataTypes.STRING(150),
      allowNull: false,
    },
    mensaje: {
      type: DataTypes.TEXT,
      allowNull: false,
    },
    leida: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false,
    },
    enviada: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false,
    },
    fechaEnvio: {
      type: DataTypes.DATE,
      allowNull: true,
      field: 'fecha_envio',
    },
  },
  {
    tableName: 'notificacion',
    timestamps: true,
    underscored: true,
    freezeTableName: true,
  }
);

module.exports = Notificacion;
