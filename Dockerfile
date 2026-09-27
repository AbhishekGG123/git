FROM node:22-alpine

# System tools install karein jo harness ko chahiye
RUN apk add --no-cache git bash python3 make g++

# DeepSeek Harness ko globally install karein
RUN npm install -g @deepseek-ai/dsh

EXPOSE 3080

# Local proxy bypass ke saath harness ko start karein
CMD ["dsh", "web", "--host", "0.0.0.0", "--port", "3080"]
