function toCamelCase(value) {
  if (!value) return value;
  return value.replace(/_([a-z])/g, (_, letter) => letter.toUpperCase());
}

function sanitizeString(value) {
  if (value === null || value === undefined) return value;
  return String(value).trim();
}

function isEmpty(value) {
  if (value === null || value === undefined) return true;
  if (typeof value === 'string') return value.trim() === '';
  if (Array.isArray(value)) return value.length === 0;
  if (typeof value === 'object') return Object.keys(value).length === 0;
  return false;
}

module.exports = {
  toCamelCase,
  sanitizeString,
  isEmpty,
};
