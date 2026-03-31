'use strict';

// ─── OpenTelemetry SDK must be initialized BEFORE express ─────────────────
// The SDK patches Node.js http module at startup time.
// If express loads first, the auto-instrumentation has nothing to intercept.
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');
const { OTLPMetricExporter } = require('@opentelemetry/exporter-metrics-otlp-grpc');
const { PeriodicExportingMetricReader } = require('@opentelemetry/sdk-metrics');

// The app sends to the LOCAL OTel Agent (127.0.0.1:4317)
// The agent is responsible for forwarding to the Collector Gateway
const OTEL_ENDPOINT = process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://127.0.0.1:4317';

const sdk = new NodeSDK({
  serviceName: process.env.OTEL_SERVICE_NAME || 'my-otel-app',
  traceExporter: new OTLPTraceExporter({ url: OTEL_ENDPOINT }),
  metricReader: new PeriodicExportingMetricReader({
    exporter: new OTLPMetricExporter({ url: OTEL_ENDPOINT }),
    exportIntervalMillis: 15000,
  }),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();
console.log('OTel SDK started — sending to', OTEL_ENDPOINT);

// ─── Express App ──────────────────────────────────────────────────────────
const express = require('express');
const app = express();
app.use(express.json());

app.get('/', (req, res) => {
  res.json({ message: 'Hello from my-otel-app', status: 'ok' });
});

app.get('/products', (req, res) => {
  const products = [
    { id: 1, name: 'Telescope', price: 299.99 },
    { id: 2, name: 'Star Map',  price: 19.99  },
    { id: 3, name: 'Moon Lamp', price: 49.99  },
  ];
  res.json({ products, count: products.length });
});

app.post('/orders', (req, res) => {
  const { productId, quantity } = req.body;
  const order = {
    orderId:   `ORD-${Date.now()}`,
    productId: productId || 1,
    quantity:  quantity  || 1,
    status:    'confirmed',
    createdAt: new Date().toISOString(),
  };
  res.status(201).json({ order });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`App listening on port ${PORT}`));
