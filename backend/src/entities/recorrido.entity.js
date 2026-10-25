const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database.config');

/**
 * Recorrido: la ejecución real de una ruta por parte de una unidad.
 *
 * El recorrido no empieza al crearse. Arranca cuando el acopiador marca
 * `EN_RUTA` (EN CAMINO), y en ese momento se guarda `horaInicio`. Sin ese
 * cambio de estado no hay recoil, y por lo tanto no hay recolección.
 */
const Recorrido = sequelize.define(
  'recorrido',
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
    rutaId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      field: 'ruta_id',
    },
    unidadId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      field: 'unidad_id',
    },
    /** El acopiador es el chófer de la unidad. Es quien arranca el recorrido. */
    acopiadorId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      field: 'acopiador_id',
    },

    // --- Ayudante: opcional ---
    // Si es personal interno, se enlaza a un usuario de la misma planta y solo
    // se guarda su id. Si es externo, se registran sus datos a mano.
    ayudanteUsuarioId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      field: 'ayudante_usuario_id',
    },
    ayudanteNombre: {
      type: DataTypes.STRING(100),
      allowNull: true,
    },
    ayudanteApellido: {
      type: DataTypes.STRING(100),
      allowNull: true,
    },
    ayudanteDni: {
      type: DataTypes.STRING(20),
      allowNull: true,
    },
    ayudanteCelular: {
      type: DataTypes.STRING(30),
      allowNull: true,
    },

    estado: {
      type: DataTypes.ENUM('PLANIFICADO', 'EN_RUTA', 'FINALIZADO', 'CANCELADO'),
      allowNull: false,
      defaultValue: 'PLANIFICADO',
      // La máquina de estados la vigila el servicio; esta validación solo evita
      // que un estado inventado llegue a MySQL y vuelva como 500.
      validate: {
        isIn: {
          args: [['PLANIFICADO', 'EN_RUTA', 'FINALIZADO', 'CANCELADO']],
          msg: 'El estado del recorrido no es valido.',
        },
      },
    },
    fecha: {
      type: DataTypes.DATEONLY,
      allowNull: false,
      // `allowNull` no coge el `""`: no es `null`, es una cadena, y MySQL la
      // convierte en "Invalid date" y responde con un **500**. Con `isDate` el
      // mismo caso da un 400 diciendo cuál era el formato.
      validate: {
        isDate: {
          msg: 'La fecha no es válida. Se escribe como AAAA-MM-DD.',
        },
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
    // Solo la fecha: la hora exacta ya está en horaInicio / horaFin. Se
    // declaran como DATEONLY para que el móvil reciba "2026-10-03" y no un
    // ISO con hora y zona horaria.
    fechaInicio: {
      type: DataTypes.DATEONLY,
      allowNull: true,
      // Son opcionales, pero **`allowNull: true` tampoco coge el `""`**: si
      // alguien manda la cadena vacía, MySQL la convierte en "Invalid date" y
      // responde con un **500**. Con `isDate` da un 400. Un campo opcional que
      // se deja en blanco tiene que mandarse **ausente**, no vacío.
      validate: {
        isDate: {
          msg: 'La fecha de inicio no es válida. Se escribe como AAAA-MM-DD.',
        },
      },
    },
    fechaFin: {
      type: DataTypes.DATEONLY,
      allowNull: true,
      // Igual que `fechaInicio`: cadena vacía es 500, no "sin fecha".
      validate: {
        isDate: {
          msg: 'La fecha de fin no es válida. Se escribe como AAAA-MM-DD.',
        },
      },
    },
    kilometrajeInicio: {
      type: DataTypes.FLOAT,
      allowNull: true,
      field: 'kilometraje_inicio',
    },
    kilometrajeFin: {
      type: DataTypes.FLOAT,
      allowNull: true,
      field: 'kilometraje_fin',
    },
    observaciones: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
  },
  {
    tableName: 'recorrido',
    timestamps: true,
    underscored: true,
    freezeTableName: true,
    indexes: [
      { fields: ['planta_id', 'fecha'], name: 'idx_recorrido_planta_fecha' },
      { fields: ['estado'], name: 'idx_recorrido_estado' },
    ],
  }
);

module.exports = Recorrido;
