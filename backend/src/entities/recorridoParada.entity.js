const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database.config');

/**
 * Parada de un recorrido: la ejecución de una parada de ruta en una unidad y
 * una fecha concretas. Se crea al arrancar el recorrido, copiando las paradas
 * de la ruta, y se va marcando conforme avanza.
 */
const RecorridoParada = sequelize.define(
  'recorridoParada',
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
    recorridoId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      field: 'recorrido_id',
    },
    rutaParadaId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      field: 'ruta_parada_id',
    },
    proveedorId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      field: 'proveedor_id',
    },
    orden: {
      type: DataTypes.INTEGER,
      allowNull: false,
    },
    estado: {
      type: DataTypes.ENUM('PENDIENTE', 'ATENDIDA', 'OMITIDA'),
      allowNull: false,
      defaultValue: 'PENDIENTE',
      // Estas paradas las sella el servicio al iniciar el recorrido; esta
      // validación solo evita que un estado inventado llegue a MySQL y vuelva
      // como 500.
      validate: {
        isIn: {
          args: [['PENDIENTE', 'ATENDIDA', 'OMITIDA']],
          msg: 'El estado de la parada no es valido.',
        },
      },
    },
    horaLlegada: {
      type: DataTypes.TIME,
      allowNull: true,
    },
    horaSalida: {
      type: DataTypes.TIME,
      allowNull: true,
    },
    /** Recolección generada en esta parada, si se recogió leche. */
    recoleccionId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      field: 'recoleccion_id',
    },
    litros: {
      type: DataTypes.FLOAT,
      allowNull: true,
    },
    observaciones: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
  },
  {
    tableName: 'recorrido_parada',
    timestamps: true,
    underscored: true,
    freezeTableName: true,
    indexes: [
      { unique: true, fields: ['recorrido_id', 'orden'], name: 'uq_rec_parada_orden' },
      { fields: ['recorrido_id', 'estado'], name: 'idx_rec_parada_estado' },
    ],
  }
);

module.exports = RecorridoParada;
