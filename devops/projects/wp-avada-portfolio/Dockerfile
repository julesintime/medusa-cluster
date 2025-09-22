# WordPress Avada Portfolio - Production Container
FROM wordpress:latest

# Install additional dependencies
RUN apt-get update && \
    apt-get install -y \
    unzip \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Copy WordPress configuration
COPY wp-config/wp-config.php /var/www/html/
COPY wp-config/.htaccess /var/www/html/
COPY wp-config/php.ini /usr/local/etc/php/conf.d/custom.ini

# Copy WordPress content (themes, plugins, uploads)
COPY wp-content/ /var/www/html/wp-content/

# Copy Avada theme
COPY Avada/ /var/www/html/wp-content/themes/Avada/

# Set proper ownership and permissions
RUN chown -R www-data:www-data /var/www/html/ && \
    find /var/www/html/ -type d -exec chmod 755 {} \; && \
    find /var/www/html/ -type f -exec chmod 644 {} \;

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# Expose port
EXPOSE 80

# Use the default WordPress entrypoint
CMD ["apache2-foreground"]