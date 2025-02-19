import { nodeResolve } from '@rollup/plugin-node-resolve';
import commonjs from '@rollup/plugin-commonjs';
import json from '@rollup/plugin-json';

export default {
  input: './index.js',
  output: {
    file: 'dist/index.mjs',
    compact: true,
    format: 'es',
  },
  plugins: [json(), nodeResolve({ preferBuiltins: true }), commonjs()],
  external: [/@aws-sdk/],
};
