FROM node:22-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    python3 \
    ca-certificates \
    socat \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g omniroute

WORKDIR /data
VOLUME /data
ENV DATA_DIR=/data
ENV NODE_ENV=production

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 20128

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
