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
    /** Dirección de la finca: el acopiador la necesita para llegar. */
    direccion: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    codigo: {
      type: DataTypes.STRING(50),
      allowNull: false,
      unique: true,
    },
    plantaId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      field: 'planta_id',
    },
    zonaId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      field: 'zona_id',
    },
    /**
     * Ruta activa a la que pertenece el proveedor. Un proveedor está en una
     * sola ruta a la vez (RN37 del documento v7).
     */
    rutaId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      field: 'ruta_id',
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
    // URL de la foto del proveedor. Opcional.
    imagen: {
      type: DataTypes.STRING(255),
      allowNull: true,
      defaultValue: null,
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
