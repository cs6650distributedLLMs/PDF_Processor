const convertBytesToMb = (bytes) => {
  return bytes / 1024 / 1024;
};

const isLocalEnv = () => {
  return process.env.NODE_ENV === 'development';
};

module.exports = { convertBytesToMb, isLocalEnv}