FROM debian:jessie

ENV DEBIAN_FRONTEND noninteractive
ENV php_conf /etc/php/7.0/fpm/php.ini 
ENV fpm_conf /etc/php/7.0/fpm/pool.d/www.conf

RUN echo "deb http://ftp.se.debian.org/debian/ jessie main" > /etc/apt/sources.list
RUN echo "deb http://security.debian.org/ jessie/updates main" >> /etc/apt/sources.list

RUN apt-get -y update && apt-get -y install wget

RUN echo "deb http://packages.dotdeb.org jessie all" >> /etc/apt/sources.list
RUN echo "deb-src http://packages.dotdeb.org jessie all" >> /etc/apt/sources.list

RUN wget https://www.dotdeb.org/dotdeb.gpg
RUN apt-key add dotdeb.gpg

RUN apt-get update && \
    apt-get -y install bash \
    openssh-client \
    nginx \
    pwgen \
    logrotate \
    mariadb-client \
    supervisor \
    php7.0-cli \
    php7.0-soap \
    php7.0-curl \
    php7.0-dev \
    php7.0-fpm \
    php7.0-gd \
    php7.0-imagick \
    php7.0-intl \
    php7.0-json \
    php7.0-imap \
    php7.0-xml \
    php7.0-mysql \
    php7.0-mcrypt \
    php7.0-opcache \
    php7.0-mbstring \
    php7.0-zip \
    openssh-server \
    libffi-dev \
    curl \
    git \
    python \
    python-dev \
    python-pip \
    ca-certificates \
    libssl-dev \
    gcc \
    nano \
    vim && \
    apt-get autoremove -y && \
    mkdir -p /etc/nginx && \
    mkdir -p /var/www/app && \
    mkdir -p /run/nginx && \
    mkdir -p /var/log/supervisor && \
    wget https://getcomposer.org/composer.phar && \
    mv composer.phar /usr/bin/composer && \
    chmod +x /usr/bin/composer

# Copy our nginx config
RUN rm -Rf /etc/nginx/nginx.conf
ADD conf/nginx/nginx.conf /etc/nginx/nginx.conf
ADD conf/nginx/restrictions /etc/nginx/restrictions
ADD conf/nginx/wordpress /etc/nginx/wordpress

# nginx site conf
RUN mkdir -p /etc/nginx/sites-available/ && \
mkdir -p /etc/nginx/sites-enabled/ && \
rm -Rf /var/www/* && \
mkdir /var/www/html/

ADD conf/nginx/nginx-site.conf /etc/nginx/sites-available/default.conf
ADD conf/php-fpm.conf /etc/php/7.0/fpm/php-fpm.conf

# Symbolic link for php-fpm
RUN ln -s /usr/sbin/php-fpm7.0 /usr/sbin/php-fpm

# tweak php-fpm config
RUN sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" ${php_conf} && \
sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" ${php_conf} && \
sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" ${php_conf} && \
sed -i -e "s/variables_order = \"GPCS\"/variables_order = \"EGPCS\"/g" ${php_conf} && \
sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" ${fpm_conf} && \
sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" ${fpm_conf} && \
sed -i -e "s/pm.max_children = 4/pm.max_children = 4/g" ${fpm_conf} && \
sed -i -e "s/pm.start_servers = 2/pm.start_servers = 3/g" ${fpm_conf} && \
sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" ${fpm_conf} && \
sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" ${fpm_conf} && \
sed -i -e "s/pm.max_requests = 500/pm.max_requests = 200/g" ${fpm_conf} && \
sed -i -e "s/user = nobody/user = www-data/g" ${fpm_conf} && \
sed -i -e "s/group = nobody/group = www-data/g" ${fpm_conf} && \
sed -i -e "s/;listen.mode = 0660/listen.mode = 0666/g" ${fpm_conf} && \
sed -i -e "s/;listen.owner = nobody/listen.owner = www-data/g" ${fpm_conf} && \
sed -i -e "s/;listen.group = nobody/listen.group = www-data/g" ${fpm_conf} && \
sed -i -e "s/listen = 127.0.0.1:9000/listen = \/var\/run\/php-fpm.sock/g" ${fpm_conf} && \
sed -i -e "s/^;clear_env = no$/clear_env = no/" ${fpm_conf} && \
mkdir -p /etc/php/conf.d && \
ln -s /etc/php/7.0/fpm/php.ini /etc/php/conf.d/php.ini && \
find /etc/php/conf.d/ -name "*.ini" -exec sed -i -re 's/^(\s*)#(.*)/\1;\2/g' {} \;

# Add Scripts

ADD scripts/pull /usr/bin/pull
ADD scripts/push /usr/bin/push
ADD scripts/send-router-domains /usr/bin/send-router-domains
RUN chmod 755 /usr/bin/pull && \
    chmod 755 /usr/bin/push && \
    chmod 755 /usr/bin/send-router-domains && \
    mkdir /var/run/sshd && \
    rm -rf /etc/logrotate.d/* && \
    rm -rf /etc/cron.daily/* && \
    rm -rf /etc/cron.d/*

# Add logrotation for Nginx logs
ADD conf/logrotate.d/ /etc/logrotate.d/
ADD conf/logrotate.conf /etc/logrotate.conf

# Add daily crons
ADD conf/cron.d/ /etc/cron.d/

# Correct permission & set up fail2ban
RUN chmod 644 /etc/logrotate.conf && \
	chmod 644 /etc/cron.d/* && \
	wget https://github.com/fail2ban/fail2ban/archive/0.9.7.tar.gz -O /tmp/f2b.tar.gz && \
	tar xvf /tmp/f2b.tar.gz && \
	cd fail2ban-0.9.7 && \
	python setup.py install && \
	cd .. && \
	rm -rf fail2ban-0.9.7 && \
    rm /tmp/f2b.tar.gz && \
	ln -s /usr/local/bin/fail2ban-client /usr/bin/fail2ban-client && \
	ln -s /usr/local/bin/fail2ban-server /usr/bin/fail2ban-server

# copy in code
ADD src/ /var/www/html/

ADD conf/supervisord.conf /etc/supervisord.conf
ADD scripts/start.sh /start.sh
ADD scripts/new /usr/bin/new
ADD scripts/move /usr/bin/move
ADD scripts/ip.pl /root/ip.pl
ADD scripts/fail2ban-supervisor.sh /root/fail2ban-supervisor.sh
ADD conf/fail2ban /etc/fail2ban

RUN mkdir -p /var/run/fail2ban && \
    chmod 755 /usr/bin/new && \
    chmod 755 /start.sh && \
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/bin/wp && \
    mkdir -p /tmp/php/sessions && \
    chmod -R 777 /tmp/php

RUN git clone https://github.com/phpredis/phpredis.git && cd phpredis && git checkout php7 && \
    phpize && ./configure && make && make install && \
    echo "extension=redis.so" > /etc/php/7.0/fpm/conf.d/50-redis.ini && \
    cd .. && rm -r phpredis

EXPOSE 3306 443 80

CMD ["/start.sh"]
