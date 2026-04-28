FROM php:8.5-cli-bookworm

ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
RUN chmod +x /usr/local/bin/install-php-extensions \
 && install-php-extensions intl bcmath pdo_sqlite zip opcache @composer \
 && apt-get update \
 && apt-get install -y --no-install-recommends git unzip \
 && rm -rf /var/lib/apt/lists/*

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_MEMORY_LIMIT=-1 \
    PATH="/root/.composer/vendor/bin:${PATH}"

RUN composer global config allow-plugins.soyuka/pmu true --no-interaction \
 && composer global require soyuka/pmu

WORKDIR /app
CMD ["bash"]
