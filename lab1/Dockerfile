# ── Stage 1: Install dependencies ──────────────────────────
FROM node:20-alpine AS deps

WORKDIR /app

# Copy package.json first (Docker layer cache trick)
# If package.json hasn't changed, npm install is skipped on rebuild
COPY package.json .
RUN npm install --omit=dev

# ── Stage 2: Final image ────────────────────────────────────
FROM node:20-alpine

WORKDIR /app

# Copy installed node_modules from deps stage
COPY --from=deps /app/node_modules ./node_modules

# Copy app source
COPY app.js .
COPY package.json .

# The port our Express app listens on
EXPOSE 3000

# Start the app
CMD ["node", "app.js"]
