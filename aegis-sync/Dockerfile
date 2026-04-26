FROM node:22-bookworm
RUN apt-get update && apt-get install -y libgtk-3-0 libdbus-glib-1-2 libxt6 libnss3 libasound2 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY package*.json ./
RUN npm install
RUN npx playwright install firefox
COPY . .
RUN mkdir -p audit vault logs
EXPOSE 1337
CMD ["node", "hub-main.js"]
