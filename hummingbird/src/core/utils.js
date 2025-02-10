export const convertBytesToMb = (bytes) => {
  return bytes / 1024 / 1024;
};

export const isLocalEnv = () => {
  return process.env.NODE_ENV === 'development';
};
