#!/usr/bin/env bash

source /mnt/hdd/raspiblitz.conf

# command info
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$1" = "-help" ]; then
  echo "the RaspiBlitz Web Interface(s)"
  echo "blitz.web.sh on"
  echo "blitz.web.sh off"
  echo "blitz.web.sh listen localhost"
  echo "blitz.web.sh listen any"
  exit 1
fi

# using ${APOST} is a workaround to be able to use sed with '
APOST=\'  # close tag for linters: '


###################
# FUNCTIONS
###################
function set_nginx_blitzweb_listen() {
   # first parameter to function should be either "localhost" or "any"
   listen_to=${1}

   if [ -f "/etc/nginx/sites-available/blitzweb.conf" ]; then
       if ! grep -Eq '^\s*#?\s*listen 127.0.0.1:443 ssl default_server;$' /etc/nginx/sites-available/blitzweb.conf; then
           echo "Error: missing expected line for: lo:v4 https"
           exit 1
       else
           if grep -Eq '^\s*#\s*listen 127.0.0.1:443 ssl default_server;$' /etc/nginx/sites-available/blitzweb.conf; then
           #echo "found: lo:v4 https (disabled line)"
               if [ ${listen_to} = "localhost" ]; then
                   sudo sed -i -E 's/#\s*(listen 127.0.0.1:443 ssl default_server;)/\1/g' /etc/nginx/sites-available/blitzweb.conf
               fi
           else
               #echo "found: lo:v4 https (enabled line)"
               if [ ${listen_to} = "any" ]; then
                   sudo sed -i -E 's/(listen 127.0.0.1:443 ssl default_server;)/#\1/g' /etc/nginx/sites-available/blitzweb.conf
               fi
          fi

       fi

       if ! grep -Eq '^\s*#?\s*listen \[::1\]:443 ssl default_server;$' /etc/nginx/sites-available/blitzweb.conf; then
           echo "Error: missing expected line for: lo:v6 https"
           exit 1
       else
           if grep -Eq '^\s*#\s*listen \[::1\]:443 ssl default_server;$' /etc/nginx/sites-available/blitzweb.conf; then
               #echo "found: lo:v6 https (disabled line)"
               if [ ${listen_to} = "localhost" ]; then
                   sudo sed -i -E 's/#\s*(listen \[::1\]:443 ssl default_server;)/\1/g' /etc/nginx/sites-available/blitzweb.conf
               fi
           else
               #echo "found: lo:v6 https (enabled line)"
               if [ ${listen_to} = "any" ]; then
                   sudo sed -i -E 's/(listen \[::1\]:443 ssl default_server;)/#\1/g' /etc/nginx/sites-available/blitzweb.conf
               fi
           fi

       fi

       if ! grep -Eq '^\s*#?\s*listen 443 ssl default_server;$' /etc/nginx/sites-available/blitzweb.conf; then
           echo "Error: missing expected line for: any:v4 https"
           exit 1
       else
           if grep -Eq '^\s*#\s*listen 443 ssl default_server;$' /etc/nginx/sites-available/blitzweb.conf; then
               #echo "found: any:v4 https (disabled line)"
               if [ ${listen_to} = "any" ]; then
                   sudo sed -i -E 's/#\s*(listen 443 ssl default_server;)/\1/g' /etc/nginx/sites-available/blitzweb.conf
               fi
           else
               #echo "found: any:v4 https (enabled line)"
               if [ ${listen_to} = "localhost" ]; then
                   sudo sed -i -E 's/(listen 443 ssl default_server;)/#\1/g' /etc/nginx/sites-available/blitzweb.conf
               fi
           fi

       fi

       if ! grep -Eq '^\s*#?\s*listen \[::\]:443 ssl default_server;$' /etc/nginx/sites-available/blitzweb.conf; then
           echo "Error: missing expected line for: any:v6 https"
           exit 1
       else
           if grep -Eq '^\s*#\s*listen \[::\]:443 ssl default_server;$' /etc/nginx/sites-available/blitzweb.conf; then
               #echo "found: any:v6 https (disabled line)"
               if [ ${listen_to} = "any" ]; then
                   sudo sed -i -E 's/#\s*(listen \[::\]:443 ssl default_server;)/\1/g' /etc/nginx/sites-available/blitzweb.conf
               fi
           else
               #echo "found: any:v6 https (enabled line)"
               if [ ${listen_to} = "localhost" ]; then
                   sudo sed -i -E 's/(listen \[::\]:443 ssl default_server;)/#\1/g' /etc/nginx/sites-available/blitzweb.conf
               fi
           fi
       fi
   fi
}



###################
# SWITCH ON
###################
if [ "$1" = "1" ] || [ "$1" = "on" ]; then

  echo "Turning ON: Web"

  # install
  sudo apt-get update >/dev/null
  sudo apt-get install -y nginx apache2-utils >/dev/null

  # make sure that it is enabled and started
  sudo systemctl enable nginx >/dev/null
  sudo systemctl start nginx

  # general nginx settings
  if ! grep -Eq '^\s*server_names_hash_bucket_size.*$' /etc/nginx/nginx.conf; then
    # ToDo(frennkie) verify this
    sudo sed -i -E '/^.*server_names_hash_bucket_size [0-9]*;$/a \tserver_names_hash_bucket_size 128;' /etc/nginx/nginx.conf
  fi

  if [ -f /etc/ssl/certs/dhparam.pem ]; then
    #can take 5-10+ minutes on a Raspberry Pi 3
    echo "Running \"sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048\" next."
    echo "This can take 5-10 minutes on a Raspberry Pi 3 - please be patient!"
    sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
  fi

  sudo cp /home/admin/assets/nginx/snippets/* /etc/nginx/snippets/

  ### Welcome Server on HTTP Port 80
  sudo rm -f /etc/nginx/sites-enabled/default
  sudo rm -f /var/www/html/index.nginx-debian.html

  if ! [ -f /etc/nginx/sites-available/public.conf ]; then
    sudo cp /home/admin/assets/nginx/sites-available/public.conf /etc/nginx/sites-available/public.conf
  fi

  if ! [ -d /var/www/letsencrypt/.well-known/acme-challenge ]; then
    sudo mkdir -p /var/www/letsencrypt/.well-known/acme-challenge >/dev/null
  fi

  # copy webroot
  if ! [ -d /var/www/public ]; then
    sudo cp -a /home/admin/assets/nginx/www_public/ /var/www/public
    sudo chown www-data:www-data /var/www/public
  fi

  sudo ln -sf /etc/nginx/sites-available/public.conf /etc/nginx/sites-enabled/public.conf

  ### RaspiBlitz Webserver on HTTPS 443

  # copy webroot
  if ! [ -d /var/www/blitzweb ]; then
      sudo cp -a /home/admin/assets/nginx/www_blitzweb/ /var/www/blitzweb
      sudo chown www-data:www-data /var/www/blitzweb
  fi

  # make sure jinja2 is installed and install j2cli
  sudo apt-get install python3-jinja2 >/dev/null
  sudo -H python3 -m pip install j2cli


  # create nginx app-data dir and use LND cert by default
  sudo mkdir /mnt/hdd/app-data/nginx/ 2>/dev/null
  sudo ln -sf /mnt/hdd/lnd/tls.cert /mnt/hdd/app-data/nginx/tls.cert
  sudo ln -sf /mnt/hdd/lnd/tls.key /mnt/hdd/app-data/nginx/tls.key

  # config
  sudo cp /home/admin/assets/blitzweb.conf /etc/nginx/sites-available/blitzweb.conf
  sudo ln -sf /etc/nginx/sites-available/blitzweb.conf /etc/nginx/sites-enabled/

  if ! [ -f /etc/nginx/.htpasswd ]; then
    PASSWORD_B=$(sudo cat /mnt/hdd/${network}/${network}.conf | grep rpcpassword | cut -c 13-)
    echo "${PASSWORD_B}" | sudo htpasswd -c -i /etc/nginx/.htpasswd admin
    sudo chown www-data:www-data /etc/nginx/.htpasswd
    sudo chmod 640 /etc/nginx/.htpasswd

  else
    sudo chown www-data:www-data /etc/nginx/.htpasswd
    sudo chmod 640 /etc/nginx/.htpasswd
  fi

  # restart NGINX
  sudo systemctl restart nginx


###################
# SWITCH OFF
###################
elif [ "$1" = "0" ] || [ "$1" = "off" ]; then

  echo "Turning OFF: Web"

  sudo systemctl stop nginx
  sudo systemctl disable nginx >/dev/null


###################
# LISTEN
###################
elif [ "$1" = "listen" ]; then

  if [ "$2" = "localhost" ] || [ "$2" = "any" ]; then
    echo "Setting NGINX to listen on: ${2}"
    set_nginx_blitzweb_listen "${2}"
  else
    echo "# FAIL: parameter not known - run with -h for help"
  fi

else
  echo "# FAIL: parameter not known - run with -h for help"
fi
