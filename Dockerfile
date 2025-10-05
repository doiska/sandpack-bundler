# Build stage
FROM node:16-alpine AS builder

WORKDIR /build

# Install git (needed to clone the repo)
RUN apk add --no-cache git

# Clone codesandbox-client repository
RUN git clone https://github.com/codesandbox/codesandbox-client.git .

# Install dependencies
RUN yarn install --frozen-lockfile

# Build internal packages
RUN yarn build:deps

# Build Sandpack bundler (creates www folder)
RUN yarn build:sandpack

# Production stage - Serve with nginx
FROM nginx:alpine

# Copy built bundler from www folder
COPY --from=builder /build/www /usr/share/nginx/html

# Create nginx configuration
RUN echo 'server { \
    listen 8080; \
    server_name _; \
    root /usr/share/nginx/html; \
    index index.html; \
    \
    gzip on; \
    gzip_vary on; \
    gzip_min_length 1024; \
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json; \
    \
    add_header Access-Control-Allow-Origin * always; \
    add_header Access-Control-Allow-Methods "GET, POST, OPTIONS" always; \
    add_header Access-Control-Allow-Headers "Content-Type, Authorization" always; \
    add_header Access-Control-Max-Age 3600 always; \
    \
    if ($request_method = OPTIONS) { \
        return 204; \
    } \
    \
    location / { \
        try_files $uri $uri/ /index.html; \
        add_header X-Frame-Options "SAMEORIGIN" always; \
        add_header X-Content-Type-Options "nosniff" always; \
        add_header X-XSS-Protection "1; mode=block" always; \
    } \
    \
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ { \
        expires 1y; \
        add_header Cache-Control "public, immutable"; \
        access_log off; \
    } \
    \
    location ~* \.html$ { \
        expires -1; \
        add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0"; \
    } \
}' > /etc/nginx/conf.d/default.conf

# Expose port 8080 (Railway compatible)
EXPOSE 8080

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
