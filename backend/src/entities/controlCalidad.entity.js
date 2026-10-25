const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database.config');

const ControlCalidad = sequelize.define(
  'controlCalidad',
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
    recoleccionId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      unique: true,
      field: 'recoleccion_id',
    },
    usuarioId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      field: 'usuario_id',
    },
    grasa: {
      type: DataTypes.FLOAT,
      allowNull: true,
    },
    proteina: {
      type: DataTypes.FLOAT,
      allowNull: true,
    },
    lactosa: {
      type: DataTypes.FLOAT,
      allowNull: true,
    },
    densidad: {
      type: DataTypes.FLOAT,
      allowNull: true,
    },
    temperatura: {
      type: DataTypes.FLOAT,
      allowNull: true,
    },
    aguaAnadida: {
      type: DataTypes.FLOAT,
      allowNull: true,
      field: 'agua_anadida',
    },
    ph: {
      type: DataTypes.FLOAT,
      allowNull: true,
    },
    resultado: {
      type: DataTypes.ENUM('pura', 'adulterada'),
      allowNull: false,
      defaultValue: 'pura',
      // Sin `isIn`, un veredicto inventado llega a MySQL y vuelve como 500. Medido:
      // `resultado: 'dorada'` respondía "Error interno del servidor" en lugar de
      // un 400 que dijera qué veredictos hay.
      //
      // **Ojo: esto hace el `ENUM` sensible a mayúsculas.** MySQL compara el
      // `ENUM` sin distinguir mayúsculas, así que `pura` en minúscula antes
      // entraba; ahora solo entra tal cual. La app manda siempre las constantes
      // exactas del dominio.
      validate: {
        isIn: {
          args: [['pura', 'adulterada']],
          msg: 'El resultado solo admite pura o adulterada.',
        },
      },
    },
  },
  {
    tableName: 'control_calidad',
    timestamps: true,
    underscored: true,
    freezeTableName: true,
  }
);

module.exports = ControlCalidad;
