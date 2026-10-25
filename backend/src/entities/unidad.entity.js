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
    plantaId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      field: 'planta_id',
    },
    /**
     * Acopiador asignado a la unidad: el chófer que la maneja. Es el único
     * que puede arrancar un recorrido con EN RUTA.
     */
    acopiadorId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      field: 'acopiador_id',
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
      // Sin `isIn`, un tipo raro llega a MySQL y sale como 500.
      validate: {
        isIn: {
          args: [['furgon', 'motocarga']],
          msg: 'El tipo solo admite furgon o motocarga.',
        },
      },
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
