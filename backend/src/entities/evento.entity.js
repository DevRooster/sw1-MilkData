const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database.config');

/**
 * Un evento al que se puede asistir: una capacitación, una reunión de ruta, una
 * visita.
 *
 * **Nace del uso real del módulo de Asistencias.** Allí el evento era un texto
 * libre de 150 caracteres: cada quien escribía "Reunión de ruta", "reunion de
 * ruta", "Reunión Ruta Norte" o "REUNION RUTA NORTE", y buscar una charla concreta
 * no encontraba las tres primeras. Con entidad propia el evento se escribe una
 * vez y se elige.
 *
 * El `nombre` es único **dentro de una planta**, no en la base entera: dos plantas
 * pueden tener su propia "Capacitación de abril" sin pelearse.
 */
const Evento = sequelize.define(
  'evento',
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
      // Mismo `len` que el `evento` de texto libre que había antes: sin esto, un
      // nombre de 160 caracteres llega a MySQL y vuelve como **500** en vez de un
      // 400 que diga cuál era el tope.
      validate: {
        len: {
          args: [1, 150],
          msg: 'El nombre del evento no puede pasar de 150 caracteres.',
        },
      },
    },
    fecha: {
      type: DataTypes.DATEONLY,
      allowNull: false,
      // **Obligatoria a propósito.** Un evento sin día no se puede buscar por
      // rango ni ordenar, y un "próximo evento" sin fecha hay que acordarse de él.
      //
      // `allowNull` no basta: mandar `""` no es mandar `null`, y MySQL convierte
      // la cadena vacía en "Invalid date" y responde con un **500**. Medido. Con
      // `isDate` el mismo caso da un 400 diciendo cuál era el formato.
      validate: {
        isDate: {
          msg: 'La fecha no es válida. Se escribe como AAAA-MM-DD.',
        },
      },
    },
    lugar: {
      type: DataTypes.STRING(150),
      allowNull: true,
    },
    descripcion: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
  },
  {
    tableName: 'evento',
    timestamps: true,
    underscored: true,
    freezeTableName: true,
  }
);

module.exports = Evento;