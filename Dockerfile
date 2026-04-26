FROM node:18-bullseye-slim

WORKDIR /app

# Install dependencies for Playwright
RUN apt-get update && apt-get install -y \\
    libnss3 \\
    libnspr4 \\
    libatk1.0-0 \\
    libatk-bridge2.0-0 \\
    libcups2 \\
    libdrm2 \\
    libxkbcommon0 \\
    libxcomposite1 \\
    libxdamage1 \\
    libxfixes3 \\
    libxrandr2 \\
    libgbm1 \\
    libasound2 \\
    && rm -rf /var/lib/apt/lists/*

COPY package.json package-lock.json* ./
RUN npm install

COPY . .

CMD ["node", "hub-main.js"]
