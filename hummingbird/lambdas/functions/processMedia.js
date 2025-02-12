import { withLogging } from '../common.js';

const getHandler = () => {};

export const handler = withLogging(getHandler());
