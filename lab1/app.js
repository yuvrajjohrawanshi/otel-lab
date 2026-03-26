'use strict';

// ─────────────────────────────────────────────
// 1. OPENTELEMETRY — must be first, before everything else
// ─────────────────────────────────────────────
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');
const { OTLPMetricExporter } = require('@opentelemetry/exporter-metrics-otlp-grpc');
const { PeriodicExportingMetricReader } = require('@opentelemetry/sdk-metrics');

const sdk = new NodeSDK({
  // Where to send traces — points to our Collector service in K8s
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://otel-collector:4317',
  }),
  // Where to send metrics — same Collector, every 10 seconds
  metricReader: new PeriodicExportingMetricReader({
    exporter: new OTLPMetricExporter({
      url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://otel-collector:4317',
    }),
    exportIntervalMillis: 10000,
  }),
  // Auto-instruments Express, HTTP, incoming requests — zero manual work
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();
console.log('OTel SDK started');

// ─────────────────────────────────────────────
// 2. EXPRESS APP — loaded after OTel is running
// ─────────────────────────────────────────────
const express = require('express');
const app = express();
app.use(express.json());

// ─────────────────────────────────────────────
// 3. ENDPOINTS
// ─────────────────────────────────────────────

// GET / — health check / hello
app.get('/', (req, res) => {
  res.json({ message: 'Hello from my app', status: 'ok' });
});

// GET /products — fake product catalog
app.get('/products', (req, res) => {
  const products = [
    { id: 1, name: 'Telescope', price: 299.99 },
    { id: 2, name: 'Star Map',  price: 19.99  },
    { id: 3, name: 'Moon Lamp', price: 49.99  },
  ];
  res.json({ products, count: products.length });
});

// POST /orders — fake order creation
app.post('/orders', (req, res) => {
  const { productId, quantity } = req.body;
  const order = {
    orderId:   `ORD-${Date.now()}`,
    productId: productId || 1,
    quantity:  quantity  || 1,
    status:    'confirmed',
    createdAt: new Date().toISOString(),
  };
  console.log('Order created:', order.orderId);
  res.status(201).json({ order });
});

// ─────────────────────────────────────────────
// 4. START SERVER
// ─────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`App listening on port ${PORT}`);
});
