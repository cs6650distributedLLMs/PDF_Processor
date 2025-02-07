import express from 'express';
import mediaRoutes from './routes/media.js';

const app = express();

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.get('/health', (req, res) => {
  res.send({ status: 'ok' });
});

app.use('/v1/media', mediaRoutes);

const port = process.env.APP_PORT || 9000;

app.listen(port, () => {
  console.log(`Example app listening on port ${port}`);
});
