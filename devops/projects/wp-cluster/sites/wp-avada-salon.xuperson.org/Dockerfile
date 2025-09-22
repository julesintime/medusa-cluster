# WordPress Avada Salon - Custom Docker Image
# This builds an immutable WordPress image with baked-in themes and plugins
# Replaces volume-mounted content with containerized deployment

FROM wordpress:6.4-php8.2-apache

LABEL maintainer="labinfra@xuperson.org"
LABEL description="WordPress Avada Salon with custom themes and plugins"
LABEL version="1.0"

# Install additional PHP extensions if needed
RUN apt-get update && apt-get install -y \
    libwebp-dev \
    libavif-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy custom themes (will be created)
COPY ./wp-content/themes/ /usr/src/wordpress/wp-content/themes/

# Copy custom plugins (will be created)
COPY ./wp-content/plugins/ /usr/src/wordpress/wp-content/plugins/

# Copy uploads and other content (optional)
COPY ./wp-content/uploads/ /usr/src/wordpress/wp-content/uploads/

# Set proper ownership
RUN chown -R www-data:www-data /usr/src/wordpress/wp-content

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/wp-admin/install.php || exit 1

# Expose port
EXPOSE 80

# Use default WordPress entrypoint
CMD ["apache2-foreground"]