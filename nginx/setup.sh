#!/usr/bin/env bash

# set up the environment; these might not be set.
export HOME="/root"
export PATH="${PATH}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# test that we have a proper setup.
cd $HOME || exit 2

# check that we got the vars we need
if [ -z "$CERTBOT_DOMAINS" ] || [ "$CERTBOT_DOMAINS" = "." ]; then
	echo "The docker-compose script must set CERTBOT_DOMAINS to value to be passed to certbot for --domains" 
	exit 3
fi

if [ -z "$CERTBOT_EMAIL" ] || [ "$CERTBOT_EMAIL" = "." ]; then
	echo "The docker-compose script must set CERTBOT_EMAIL to an email address useful to certbot/letsencrypt for notifications"
	exit 3
fi

if [ -z "$NGINX_FQDN" ] || [ "$NGINX_FQDN" = "." ]; then
	echo "The docker-compose script must set NGINX_FQDN to the (single) fully-qualified domain at the top level"
	exit 3
fi

# run cerbot to set up Nginx
if [ "$CERTBOT_TEST" != "test" ]; then
    certbot --agree-tos --email "${CERTBOT_EMAIL}" --non-interactive --domains "$CERTBOT_DOMAINS" --nginx --agree-tos --rsa-key-size 4096 --redirect || exit 4

    # certbot actually launched Nginx. The simple hack is to stop it; then launch 
    # it again after we've edited the config files.
    /usr/sbin/nginx -s stop && echo "stopped successfully"
fi

# now, add the fields to the virtual host section for https.
set -- proxy-*.conf
if [ "$1" != "proxy-*.conf" ] ; then
	echo "add proxy-specs to configuration from:" "$@"
	sed -e "s/@{FQDN}/${NGINX_FQDN}/g" "$@" > /tmp/proxyspecs.conf || exit 5
	sed -e '/\(^[[:space:]].*\)try_files/r/tmp/proxyspecs.conf' /etc/nginx/sites-available/default  > /tmp/000-default-le-ssl-local.conf || exit 6
	sed -i '/\(^[[:space:]].*\)try_files/d' /tmp/000-default-le-ssl-local.conf || exit 7
	mv /tmp/000-default-le-ssl-local.conf /etc/nginx/sites-available || exit 7.1
	echo "enable the modified site, and disable the ssl defaults"
        rm -rf /etc/nginx/sites-enabled/default || exit 8
        rm -rf /etc/nginx/sites-enabled/000-default-le-ssl-local.conf || exit 9
        ln -s /etc/nginx/sites-available/000-default-le-ssl-local.conf /etc/nginx/sites-enabled/000-default-le-ssl-local.conf || exit 10
fi

