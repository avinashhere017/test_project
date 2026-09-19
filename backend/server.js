require('dotenv').config();

const express = require('express');
const cors = require('cors');

const connectDb = require('./config/db');
const itemsRouter = require('./routes/items');

const app = express();

app.use(cors());
app.use(express.json());

app.use('/api/items', itemsRouter);

const PORT = process.env.PORT || 5000;

connectDb()
  .then(() => {
    app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
  })
  .catch((err) => {
    console.error('MongoDB connection error:', err);
    process.exit(1);
  });
