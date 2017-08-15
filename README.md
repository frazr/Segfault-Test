# Segfault Test Environment

### Installation

Tested with:
docker-compose version 1.11.2, build dfed245
Docker version 17.03.1-ce, build c6d412e

Install the required dependencied (docker-compose & docker-engine).

### docker-compose.yml
```sh
version: '2'
services:
  web:
    build: ./
    privileged: true 
    volumes:
     - "../my_volumes/data:/data"
    ports:
     - "80:80"
    links:
     - "db:db"
  db:
    image: mysql
    ports:
     - "3306:3306"
    environment:
     MYSQL_ROOT_PASSWORD: dev
     MYSQL_USER: dev
     MYSQL_PASSWORD: dev
     MYSQL_DATABASE: dev
    volumes:
     - "../my_volumes/data_mysql:/var/lib/mysql"
```

I'm using a folder named "my_volumes" beneath the working directory to store the container data. Set this up according to your local environment.

### Creating your site

```sh
# In the working directory type the following
docker-compose exec web bash

# Inside the container type
new site example.com

# Proceed and install wordpress in the /data/sites/site/public_html folder
# Set up wp-config to connect to db with details in the docker-compose.yml file

# Enable Core Dump format
echo '/tmp/coredump-%e.%p' > /proc/sys/kernel/core_pattern

# Set ulimit
ulimit -c

# Add rlimit to your PHP-FPM pool configuration
echo "rlimit_core = unlimited" >> /data/php-fpm.d/site.conf

# Restart php-fpm7
supervisorctl restart php-fpm7
```

