FROM node:22-alpine

RUN apk add --no-cache ffmpeg python3 py3-pip wget \
 && pip install --no-cache-dir --break-system-packages yt-dlp

WORKDIR /app
COPY package.json ./
COPY src ./src

ENV PORT=3001 DATA_DIR=/data
EXPOSE 3001
CMD ["node", "src/server.js"]
