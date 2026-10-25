const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database.config');

const Usuario = sequelize.define(
  'usuario',
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
    email: {
      type: DataTypes.STRING(150),
      allowNull: false,
      unique: true,
      validate: {
        isEmail: true,
      },
    },
    password: {
      type: DataTypes.STRING(255),
      allowNull: false,
    },
    rolId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      field: 'rol_id',
    },
    // Define el aislamiento: un usuario solo ve y opera los datos de su planta.
    plantaId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      field: 'planta_id',
    },
    // La relación con Proveedor vive en Proveedor.usuarioId (asociación
    // Usuario.hasOne(Proveedor) en entities/index.js). No se declara aquí una
    // segunda clave foránea en sentido contrario.
    activo: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true,
    },
    ultimoAcceso: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    // URL de la foto de perfil. Opcional.
    // `defaultValue: null` hace que el atributo exista siempre en la instancia,
    // en lugar de venir `undefined` cuando nunca se asignó.
    imagen: {
      type: DataTypes.STRING(255),
      allowNull: true,
      defaultValue: null,
    },
  },
  {
    tableName: 'usuario',
    timestamps: true,
    underscored: true,
    freezeTableName: true,
  }
);

module.exports = Usuario;
