# Gunakan base image Nginx resmi dari Docker Hub
FROM nginx:alpine

# Salin file index.html kustom ke direktori web root Nginx
COPY index.html /usr/share/nginx/html/index.html

# Expose port 80
EXPOSE 80

# Perintah default untuk menjalankan Nginx saat kontainer dimulai
CMD ["nginx", "-g", "daemon off;"]
