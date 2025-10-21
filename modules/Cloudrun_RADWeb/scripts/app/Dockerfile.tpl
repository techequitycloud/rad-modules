# Use the official Nginx image from the Docker Hub
FROM nginx:alpine

# Copy the custom Nginx configuration to the container
# This will overwrite the default Nginx config and enable extensionless URLs
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy all the website assets (HTML, CSS, JS, images) to the Nginx HTML directory
COPY . /usr/share/nginx/html/

# Expose port 80 for the web server
EXPOSE 80

# Start Nginx when the container launches
CMD ["nginx", "-g", "daemon off;"]
