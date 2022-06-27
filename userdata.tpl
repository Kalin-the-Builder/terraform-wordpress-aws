#!/bin/bash
# AUTOMATIC WORDPRESS INSTALLER IN AWS Ubuntu Server 20.04 LTS (HVM)

# Variables from the Terraform Template
db_username=${db_username}
db_user_password=${db_user_password}
db_name=${db_name}
db_RDS=${db_RDS}

# Install LAMP (Linux, Apache, MySQL & PHP) Server
apt update  -y
apt upgrade -y
apt update  -y
apt upgrade -y
# install Apache 
apt install -y apache2

apt install -y php
apt install -y php php-{pear,cgi,common,curl,mbstring,gd,mysqlnd,bcmath,json,xml,intl,zip,imap,imagick}

# Install the mySQL Package & mySQL Client
apt install -y mysql-client-core-8.0

# Start, Enable Apache & Register to Startup
systemctl start apache2
systemctl enable --now apache2

# Change OWNER and Permission of Directory: /var/www
usermod -a -G www-data ubuntu
chown -R ubuntu:www-data /var/www
find /var/www -type d -exec chmod 2775 {} \;
find /var/www -type f -exec chmod 0664 {} \;

# Installing Wordpress via WP CLI
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp
wp core download --path=/var/www/html --allow-root
wp config create --dbname=$db_name --dbuser=$db_username --dbpass=$db_user_password --dbhost=$db_RDS --path=/var/www/html --allow-root --extra-php <<PHP
define( 'FS_METHOD', 'direct' );
define('WP_MEMORY_LIMIT', '128M');
PHP

# Change Permission of Directory: /var/www/html/
chown -R ubuntu:www-data /var/www/html
chmod -R 774 /var/www/html
rm /var/www/html/index.html
# Enable .htaccess Files in Apache Config using sed Command
sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride all/' /etc/apache2/apache2.conf
a2enmod rewrite

# Configure Apache to Host WordPress
echo '<VirtualHost *:80>
    ServerName wordpress.kalinthebuilder.com
    ServerAdmin kalin.pretorius20@gmail.com
    DocumentRoot /var/www/html/wordpress
    ErrorLog /var/log/apache2/error.log
    CustomLog /var/log/apache2/access.log combined
    </VirtualHost>' >> /etc/apache2/sites-available/wordpress.conf

a2ensite wordpress.conf

# Restart Apache
systemctl restart apache2
echo WordPress Installed

# Secure WordPress with Let's Encrypt SSL
apt-get install python3-certbot-apache -y
certbot --apache -d wordpress.kalinthebuilder.com

echo kalin.pretorius20@gmail.com # Provide Email for Terms of Service

echo A # Agree to Terms of Service

echo N # No to Sharing Email

echo 2 # Redirect - Make all requests redirect to secure HTTPS access.

systemctl restart apache2
echo WordPress Secured