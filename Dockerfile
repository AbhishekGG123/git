FROM node:24-trixie

RUN apt-get update && apt-get install -y \
    caddy \
    git \
    curl \
    jq \
    ripgrep \
    rsync \
    zip \
    less \
    && rm -rf /var/lib/apt/lists/*

RUN corepack enable && corepack prepare pnpm@11.7.0 --activate

RUN mkdir -p /app/workspace

WORKDIR /app

RUN npm install -g @deepseek-ai/dsh

COPY Caddyfile /etc/caddy/Caddyfile
COPY start.sh /start.sh

RUN chmod +x /start.sh

EXPOSE 8080

CMD ["/start.sh"]
