# Use lightweight Node.js 20 Alpine image
FROM node:20-alpine

# Set working directory
WORKDIR /app

# Production mode by default
ENV NODE_ENV=production

# Install system dependencies required for Prism (OpenSSL)
RUN apk add --no-cache openssl

# Copy package files first to leverage cache
COPY package*.json ./

# Copy prisma directory (required for postinstall script)
COPY prisma ./prisma/

# Install dependencies
RUN npm ci --omit=dev

# Copy the rest of the application code
COPY . .

# Generate Prisma Client
RUN npx prisma generate

# Expose the application port
EXPOSE 4000

# Start command (using start script from package.json)
CMD ["npm", "run", "start"]
