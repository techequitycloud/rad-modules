# Use the official Nginx image from the Docker Hub
FROM nginx:latest

# Copy static files to the Nginx HTML directory
COPY ./html /usr/share/nginx/html

# Expose port 80 for the web server
EXPOSE 80

# Start Nginx when the container launches
CMD ["nginx", "-g", "daemon off;"]
