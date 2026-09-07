function isValidDni(value) {
  if (typeof value !== 'string') return false;
  const normalized = value.trim();
  return /^[0-9]{8}$/.test(normalized);
}

function isValidEmail(value) {
  if (typeof value !== 'string') return false;
  const normalized = value.trim();
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalized);
}

function isValidPhone(value) {
  if (typeof value !== 'string') return false;
  const normalized = value.trim();
  return /^[0-9+()\-\s]{7,20}$/.test(normalized);
}

module.exports = {
  isValidDni,
  isValidEmail,
  isValidPhone,
};
