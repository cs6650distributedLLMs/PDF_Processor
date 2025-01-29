import express from 'express';
import mediaRoutes from './routes/media.js';

const app = express();

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.get('/', (req, res) => {
  res.send('Hello World!');
});

app.use('/media', mediaRoutes);

const port = process.env.APP_PORT || 3000;

app.listen(port, () => {
  console.log(`Example app listening on port ${port}`);
});
