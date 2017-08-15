#!/bin/bash
shopt -s dotglob nullglob

# Always chown webroot for better mounting
chown -Rf www-data. /var/www/html

# Display PHP error's or not
if [[ "$ERRORS" != "1" ]] ; then
	echo php_flag[display_errors] = off >> /etc/php/php-fpm.conf
else
	echo php_flag[display_errors] = on >> /etc/php/php-fpm.conf
fi

# Display Version Details or not
if [[ "$HIDE_NGINX_HEADERS" == "0" ]] ; then
	sed -i "s/server_tokens off;/server_tokens on;/g" /etc/nginx/nginx.conf
else
	sed -i "s/expose_php = On/expose_php = Off/g" /etc/php/conf.d/php.ini
fi

# Increase the memory_limit
if [ ! -z "$PHP_MEM_LIMIT" ]; then
	sed -i "s/memory_limit = 128M/memory_limit = ${PHP_MEM_LIMIT}M/g" /etc/php/conf.d/php.ini
fi

# Increase the post_max_size
if [ ! -z "$PHP_POST_MAX_SIZE" ]; then
	sed -i "s/post_max_size = 100M/post_max_size = ${PHP_POST_MAX_SIZE}M/g" /etc/php/conf.d/php.ini
fi

# Increase the upload_max_filesize
if [ ! -z "$PHP_UPLOAD_MAX_FILESIZE" ]; then                                                                      
	sed -i "s/upload_max_filesize = 100M/upload_max_filesize= ${PHP_UPLOAD_MAX_FILESIZE}M/g" /etc/php/conf.d/php.ini
fi

echo -e "Checking if there is an old data dir to copy"
if [ -d "/data-old" ]; then
	echo -e "Found old datadir, is the new data dir empty?"
	if [ ! "$(ls -A /data)" ]; then
		echo -e "New data-dir is empty, copying files."
		rsync -av /data-old/ /data/
	else
		echo -e "New data-dir was not empty, doing nothing."
	fi
fi

if [ ! -d "/data/etc" ]; then

	mkdir -p /data/
	mkdir /data/sites
	mkdir /data/logs
	mkdir /data/php-fpm.d
	mkdir /data/nginx.d
	mkdir /data/nginx.d.disabled
	mkdir /data/etc
	cp /etc/passwd /data/etc/
	cp /etc/shadow /data/etc/
	cp /etc/group /data/etc/
	touch /data/etc/hosts
	cat /etc/hosts > /data/etc/hosts
	touch /data/etc/phpcommon.conf

	cat > "/data/etc/phpcommon.conf" << EOF
	listen.owner = www-data
	listen.group = www-data
	php_admin_value[disable_functions] = exec,passthru,shell_exec,system
	pm = ondemand
	pm.process_idle_timeout = 10s
	pm.max_children = 2
	pm.start_servers = 2
	pm.min_spare_servers = 1
	pm.max_spare_servers = 2
	php_value[session.save_path] = /tmp/php/sessions
EOF

else
	cp /data/etc/passwd /etc/passwd
	cp /data/etc/shadow /etc/shadow
	cp /data/etc/group /etc/group
	cat /data/etc/hosts >> /etc/hosts
fi

touch /data/etc/blocked_ips.conf

send-router-domains

# Ugly hack to get cron to start working
mv /etc/cron.d/logrotate_init /etc/cron.d/logrotate
mv /etc/cron.d/php_init /etc/cron.d/php

# Start supervisord and services
/usr/bin/supervisord -n -c /etc/supervisord.conf
