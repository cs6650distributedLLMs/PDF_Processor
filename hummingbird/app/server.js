import 'dotenv/config';
import express from 'express';
import mediaRoutes from './routes/media.js';
import { init as initializeLogger, getLogger } from './logger.js';

initializeLogger();
const logger = getLogger();

const app = express();

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use((req, res, next) => {
  const start = Date.now();

  res.on('finish', () => {
    logger.info({
      method: req.method,
      statusCode: res.statusCode,
      url: req.originalUrl,
      duration: Date.now() - start,
    });
  });

  next();
});

app.get('/health', (req, res) => {
  res.send({ status: 'ok', service: 'hummingbird', timestamp: Date.now() });
});

app.use('/v1/media', mediaRoutes);

const port = process.env.APP_PORT;

app.listen(port, () => {
  logger.info(`Example app listening on port ${port}`);
});
