FROM node:22-slim

# System utilities aur socat install karein
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

# Environment setup variables inject karein jo 403 blocks bypass karte hain
ENV HOST=0.0.0.0
ENV PORT=3080

# DeepSeek Harness ko --no-open block proxy ke sath start karein
CMD dsh web --host 127.0.0.1 --port 3081 & sleep 5 && socat TCP-LISTEN:3080,fork,reuseaddr TCP:127.0.0.1:3081
