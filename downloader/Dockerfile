# Stage 1: install yt-dlp into a venv so pip never reaches the final image.
FROM node:22-alpine AS ytdlp

RUN apk add --no-cache python3 py3-pip \
 && python3 -m venv /opt/yt-dlp \
 && /opt/yt-dlp/bin/pip install --no-cache-dir yt-dlp \
 && rm -rf /opt/yt-dlp/lib/python3*/site-packages/pip /opt/yt-dlp/lib/python3*/site-packages/setuptools /opt/yt-dlp/bin/pip*

# Stage 2: runtime — node, ffmpeg/ffprobe, python runtime for yt-dlp, wget for the healthcheck.
FROM node:22-alpine

RUN apk add --no-cache ffmpeg python3 wget \
 && mkdir -p /data && chmod 777 /data

COPY --from=ytdlp /opt/yt-dlp /opt/yt-dlp
ENV PATH="/opt/yt-dlp/bin:$PATH"

WORKDIR /app
COPY package.json ./
COPY src ./src

ENV PORT=3001 DATA_DIR=/data
EXPOSE 3001
CMD ["node", "src/server.js"]
