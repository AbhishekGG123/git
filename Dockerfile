FROM node:22-slim

# socat aur system dependencies install karein
RUN apt-get update && apt-get install -y \
    git \
    bash \
    python3 \
    make \
    g++ \
    socat \
    && rm -rf /var/lib/apt/lists/*

# DeepSeek Harness install karein
RUN npm install -g @deepseek-ai/dsh

EXPOSE 3080

# Background me traffic internally reroute karne ke liye entrypoint script chalayein
CMD socat TCP-LISTEN:3080,fork,reuseaddr TCP:127.0.0.1:3081 & dsh web --host 127.0.0.1 --port 3081
