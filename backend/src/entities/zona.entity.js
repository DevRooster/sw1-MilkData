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
    plantaId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      field: 'planta_id',
    },
    /**
     * Ruta a la que pertenece la zona. Antes era un texto libre; ahora la
     * ruta es una entidad con paradas ordenadas.
     */
    rutaId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      field: 'ruta_id',
    },
    nombre: {
      type: DataTypes.STRING(100),
      allowNull: false,
      validate: {
        notEmpty: true,
      },
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
