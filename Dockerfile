FROM node:22-slim

# System tools install karein jo native modules build karne me kaam aate hain
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

# Production layer settings ke sath run karein
CMD ["dsh", "web", "--host", "0.0.0.0", "--port", "3080"]
