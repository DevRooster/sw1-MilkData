const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database.config');

/** Catálogo de productos terminados, aislado por planta. */
const Producto = sequelize.define(
  'producto',
  {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true,
      allowNull: false,
    },
    plantaId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      field: 'planta_id',
    },
    nombre: {
      type: DataTypes.STRING(150),
      allowNull: false,
      validate: {
        notEmpty: true,
      },
    },
    descripcion: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    unidadMedida: {
      type: DataTypes.STRING(30),
      allowNull: false,
      defaultValue: 'unidad',
    },
    precioVenta: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: false,
      defaultValue: 0,
      validate: {
        min: 0,
      },
    },
    // URL de la imagen del producto. Opcional.
    imagen: {
      type: DataTypes.STRING(255),
      allowNull: true,
      defaultValue: null,
    },
    estado: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true,
    },
  },
  {
    tableName: 'producto',
    timestamps: true,
    underscored: true,
    freezeTableName: true,
  }
);

module.exports = Producto;
