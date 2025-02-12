import { nodeResolve } from '@rollup/plugin-node-resolve';
import commonjs from '@rollup/plugin-commonjs';

export default {
  input: './index.js',
  output: {
    file: 'dist/index.mjs',
    compact: true,
    format: 'es',
  },
  plugins: [nodeResolve({ preferBuiltins: true }), commonjs()],
  external: [/@aws-sdk/],
};
