FROM nginx:1.27-alpine

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom nginx config
COPY nginx/default.conf /etc/nginx/conf.d/default.conf

# Copy portfolio static files
COPY portfolio/ /usr/share/nginx/html/

# Remove .DS_Store files
RUN find /usr/share/nginx/html -name '.DS_Store' -delete

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
