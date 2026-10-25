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
    plantaId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      field: 'planta_id',
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
      // **Texto libre y además enlazado al evento del catálogo.** Las dos cosas
      // existen a la vez a propósito:
      //
      // - El texto es lo que había antes y sigue siendo obligatorio. Una
      //   asistencia apuntada sin elegir evento tiene que poder decir *qué* pasó,
      //   y `allowNull: false` no se toca porque cambiarlo obligaría a reescribir
      //   datos que ya están en la base.
      // - `eventoId` es el enlace al evento del catálogo, **opcional**. Permite
      //   que las asistencias nuevas se apunten a un evento real y que se puedan
      //   listar por él, sin obligar a migrar las viejas.
      //
      // La razón de que sigan las dos: cambiar `allowNull` o borrar el texto
      // obligaría a tocar cada fila que ya existe, y esas filas dicen cosas
      // —"reunion de ruta" escrito con minúsculas y sin tilde— que no están en
      // ningún evento del catálogo.
      //
      // La asociación se llama `eventoRelacion` y no `evento` porque la columna de
      // arriba ya ocupa ese nombre; dos cosas con el mismo nombre en la misma
      // tabla no pueden convivir.
      validate: {
        len: {
          args: [1, 150],
          msg: 'El evento no puede pasar de 150 caracteres.',
        },
      },
    },
    eventoId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      field: 'evento_id',
      // **Nullable a propósito**, y no por pereza: las asistencias ya escritas
      // no tienen evento del catálogo y no se pueden inventar uno a posteriori
      // sin adivinar a cuál se refiere cada texto.
    },
    fecha: {
      type: DataTypes.DATEONLY,
      allowNull: false,
      // `allowNull` no coge el `""`: no es `null`, es una cadena, y MySQL la
      // convierte en "Invalid date" y responde con un **500**. Medido. Con
      // `isDate` el mismo caso da un 400 diciendo cuál era el formato.
      validate: {
        isDate: {
          msg: 'La fecha no es válida. Se escribe como AAAA-MM-DD.',
        },
      },
    },
    registradoPor: {
      type: DataTypes.ENUM('QR', 'manual'),
      allowNull: false,
      field: 'registrado_por',
      // El `ENUM` de MySQL rechaza los valores raros, pero lo hace **al escribir**,
      // con un aviso de truncamiento que sale como 500. Con `isIn` el rechazo
      // ocurre antes y con un mensaje que dice qué valores valen.
      validate: {
        isIn: {
          args: [['QR', 'manual']],
          msg: 'Solo se admite QR o manual.',
        },
      },
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
