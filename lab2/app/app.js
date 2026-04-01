'use strict';
const express = require('express');
const app = express();
app.use(express.json());

app.get('/', (req, res) => {
  res.json({ message: 'Hello from vanilla Node app, running behind OneAgent', status: 'ok' });
});

app.get('/products', (req, res) => {
  const products = [
    { id: 1, name: 'Telescope', price: 299.99 },
    { id: 2, name: 'Star Map',  price: 19.99  },
    { id: 3, name: 'Moon Lamp', price: 49.99  },
  ];
  res.json({ products, count: products.length });
});

const PORT = 3000;
app.listen(PORT, () => console.log(`App listening on port ${PORT}`));
