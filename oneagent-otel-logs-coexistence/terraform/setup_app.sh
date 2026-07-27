#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Cloud-init script to automatically provision the App VM with a Vanilla Node.js 
# application. This removes the manual configuration steps so we can focus on
# installing OneAgent + OTel and observing their behavior.
# ─────────────────────────────────────────────────────────────────────────────

# 1. Install Node.js
dnf install -y nodejs

# 2. Create App Directory
mkdir -p /home/ec2-user/otel-app
cd /home/ec2-user/otel-app

# 3. Create a Vanilla Node.js App (No OTel SDK built inside)
# Dynatrace OneAgent will automatically attach to this at the system level.
cat << 'EOF' > app.js
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
EOF

# 4. Create package.json
cat << 'EOF' > package.json
{
  "name": "vanilla-node-app",
  "version": "1.0.0",
  "main": "app.js",
  "dependencies": {
    "express": "^4.18.2"
  }
}
EOF

# 5. Install dependencies
npm install

# Fix Ownership so ec2-user can manage it later if needed
chown -R ec2-user:ec2-user /home/ec2-user/otel-app

# 6. Create Systemd Service for the App
cat << 'EOF' > /etc/systemd/system/otel-app.service
[Unit]
Description=Vanilla Node.js App for OneAgent Test
After=network-online.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user/otel-app
ExecStart=/usr/bin/node app.js
Restart=on-failure
Environment=PORT=3000

[Install]
WantedBy=multi-user.target
EOF

# 7. Start the Application immediately
systemctl daemon-reload
systemctl enable --now otel-app
