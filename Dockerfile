FROM node:22-slim

# System tools install karein
RUN apt-get update && apt-get install -y \
    git \
    bash \
    python3 \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# DeepSeek Harness ko globally install karein
RUN npm install -g @deepseek-ai/dsh

EXPOSE 3080

# Isko safely local loopback interface par bind karein
CMD ["dsh", "web", "--host", "127.0.0.1", "--port", "3080"]
