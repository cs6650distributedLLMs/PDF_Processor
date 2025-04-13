const path = require('path');

const convertBytesToMb = (bytes) => {
  return bytes / 1024 / 1024;
};

const isLocalEnv = () => {
  return process.env.NODE_ENV === 'development';
};

/**
 * Gets the base name of a file without the extension
 * @param {string} fileName The file name
 * @returns {string} The base name of the file
 */
const getBaseName = (fileName) => {
  const ext = path.extname(fileName);
  return path.basename(fileName, ext);
};

module.exports = { convertBytesToMb, isLocalEnv, getBaseName };