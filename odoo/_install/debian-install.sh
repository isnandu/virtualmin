#!/bin/bash
################################################################################
# Script for Installation: ODOO server on Debian 8 with Webmin
# Credits: André Schenkels, ICTSTUDIO 2014
# Author: isnandu
#-------------------------------------------------------------------------------
#  
# This script will install ODOO Server on
# clean Debian 8 Server with Webmin panel
#-------------------------------------------------------------------------------
# USAGE:
#
# debian-install
#
# EXAMPLE:
# ./debian-install 
#
################################################################################
 
##Change this parameters with you own data
OE_DOMAIN="crm.domain.tld"
OE_USER="crm"
OE_DB_USER="SuperUser"

##Directories for Odoo
OE_HOME="/home/${OE_USER}/domains/${OE_DOMAIN}/opt/${OE_USER}"
OE_HOME_EXT="/home/${OE_USER}/domains/${OE_DOMAIN}/opt/${OE_USER}/${OE_USER}-server"
OE_DIR_ETC="/home/${OE_USER}/domains/${OE_DOMAIN}/etc"

#The default port where this Odoo instance will run under (provided you use the command -c in the terminal)
#Set to true if you want to install it, false if you don't need it or have it already installed.
INSTALL_WKHTMLTOPDF="False"
#Set the default Odoo port (you still have to use -c /etc/odoo-server.conf for example to use this.)
OE_PORT="8069"
#Choose the Odoo version which you want to install. For example: 9.0, 8.0, 7.0 or saas-6. When using 'trunk' the master version will be installed.
#IMPORTANT! This script contains extra libraries that are specifically needed for Odoo 9.0
OE_VERSION="9.0"
#set the superadmin password
OE_CONFIG="${OE_USER}-server"

##
###  Create Virtualmin 'user' folders
## Before the system  installed, you need to perform the creation of the folders where Odoo will be installed into the virtualmin domain directory.
mkdir /home/${OE_USER}/domains/${OE_DOMAIN}/bin.odoo
mkdir /home/${OE_USER}/domains/${OE_DOMAIN}/opt
mkdir -p /home/${OE_USER}/etc/init.d

##
###  WKHTMLTOPDF download links
## === Ubuntu Trusty x64 & x32 === (for other distributions please replace these two links,
## in order to have correct version of wkhtmltox installed, for a danger note refer to 
## https://www.odoo.com/documentation/8.0/setup/install.html#deb ):
WKHTMLTOX_X64=http://nightly.odoo.com/extra/wkhtmltox-0.12.1.2_linux-jessie-amd64.deb
WKHTMLTOX_X32=http://nightly.odoo.com/extra/wkhtmltox-0.12.1.2_linux-jessie-i386.deb

#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n---- Update Server ----"
apt-get update
apt-get upgrade -y

#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------
#echo -e "\n---- Install PostgreSQL Server ----"
#apt-get install postgresql -y
	
#echo -e "\n---- PostgreSQL $PG_VERSION Settings  ----"
#sed -i s/"#listen_addresses = 'localhost'"/"listen_addresses = '*'"/g /etc/postgresql/9.1/main/postgresql.conf

#echo -e "\n---- Creating the ODOO PostgreSQL User  ----"
#su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true

#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------
echo -e "\n---- Install tool packages ----"
apt-get install wget subversion git bzr bzrtools python-pip -y
	
echo -e "\n---- Install python packages ----"
apt-get install python-dateutil python-feedparser python-ldap python-libxslt1 python-lxml python-mako python-openid python-psycopg2 python-pybabel python-pychart python-pydot python-pyparsing python-reportlab python-simplejson python-tz python-vatnumber python-vobject python-webdav python-werkzeug python-xlwt python-yaml python-zsi python-docutils python-psutil python-mock python-unittest2 python-jinja2 python-pypdf python-decorator python-requests python-passlib libjpeg-dev -y
	
echo -e "\n---- Install python libraries ----"
pip install gdata
# De lo contrario no se podrá compilar y recibirá el error 'compile failed'
apt-get build-dep python-imaging
# Ejecutar la instalación con python-pip
pip install -I pillow
	
echo -e "\n---- Create ODOO system user ----"
adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER

echo -e "\n---- Create Log directory ----"
mkdir /var/log/$OE_USER
chown $OE_USER:$OE_USER /var/log/$OE_USER

#--------------------------------------------------
# Install Wkhtmltopdf if needed
#--------------------------------------------------
if [ $INSTALL_WKHTMLTOPDF = "True" ]; then
  echo -e "\n---- Install wkhtml and place shortcuts on correct place for ODOO 9 ----"
  #pick up correct one from x64 & x32 versions:
  if [ "`getconf LONG_BIT`" == "64" ];then
      _url=$WKHTMLTOX_X64
      _basename=amd64
  else
      _url=$WKHTMLTOX_X32
      _basename=i386
  fi
  sudo wget -O $OE_HOME/wkhtmltox-0.12.1.2_linux-jessie-$_basename.deb $_url
  sudo dpkg -i $OE_HOME/wkhtmltox-0.12.1.2_linux-jessie-$_basename.deb
  sudo apt-get install -f
  sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin
  sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin
else
  echo "Wkhtmltopdf isn't installed due to the choice of the user!"
fi

#--------------------------------------------------
# Install ODOO
#--------------------------------------------------
echo -e "\n==== Installing ODOO Server ===="
git clone --branch $OE_VERSION https://www.github.com/odoo/odoo $OE_HOME_EXT/

echo -e "\n---- Create custom module directory ----"
mkdir $OE_HOME/custom
mkdir $OE_HOME/custom/addons

echo -e "\n---- Setting permissions on home folder ----"
chown -R $OE_USER:$OE_USER $OE_HOME/*

echo -e "* Create server config file"
if [ $OE_VERSION = "10.0" ]; then
	cp $OE_HOME_EXT/debian/odoo.conf $OE_DIR_ETC/$OE_CONFIG.conf
else
	cp $OE_HOME_EXT/debian/openerp-server.conf $OE_DIR_ETC/$OE_CONFIG.conf
fi
chown $OE_USER:$OE_USER $OE_DIR_ETC/$OE_CONFIG.conf
chmod 640 $OE_DIR_ETC/$OE_CONFIG.conf

echo -e "* Change server config file"

# Generate random password for DB admin
OE_DB_PASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8 ; echo '')

sed -i s/"db_host = .*"/"db_host = localhost"/g $OE_DIR_ETC/$OE_CONFIG.conf
sed -i s/"db_user = .*"/"db_user = $OE_DB_USER"/g $OE_DIR_ETC/$OE_CONFIG.conf
sed -i s/"; admin_passwd.*"/"admin_passwd = $OE_DB_PASS"/g $OE_DIR_ETC/$OE_CONFIG.conf
echo 'logfile = /var/log/$OE_USER/$OE_CONFIG$1.log' >> $OE_DIR_ETC/$OE_CONFIG.conf
echo "addons_path= ${OE_HOME_EXT}/addons" >> $OE_DIR_ETC/$OE_CONFIG.conf

echo -e "* Make the new user in PostgreSQL"
sudo -u postgres createuser -s -e $OE_DB_USER
sudo -u postgres psql -c "ALTER USER $(OE_DB_USER) WITH PASSWORD '$(OE_DB_PASS)';"

echo -e "* Create startup file"
echo '#!/bin/sh' >> $OE_HOME_EXT/start.sh
echo '-u $OE_USER $OE_HOME_EXT/openerp-server --config=$OE_DIR_ETC/$OE_CONFIG.conf' >> $OE_HOME_EXT/start.sh
chmod 755 $OE_HOME_EXT/start.sh

#--------------------------------------------------
# Adding ODOO as a deamon (initscript)
#--------------------------------------------------

echo -e "* Create init file"
echo '#!/bin/sh' >> ~/$OE_CONFIG
echo '### BEGIN INIT INFO' >> ~/$OE_CONFIG
echo '# Provides: $OE_CONFIG' >> ~/$OE_CONFIG
echo '# Required-Start: $remote_fs $syslog' >> ~/$OE_CONFIG
echo '# Required-Stop: $remote_fs $syslog' >> ~/$OE_CONFIG
echo '# Should-Start: $network' >> ~/$OE_CONFIG
echo '# Should-Stop: $network' >> ~/$OE_CONFIG
echo '# Default-Start: 2 3 4 5' >> ~/$OE_CONFIG
echo '# Default-Stop: 0 1 6' >> ~/$OE_CONFIG
echo '# Short-Description: Enterprise Business Applications' >> ~/$OE_CONFIG
echo '# Description: ODOO Business Applications' >> ~/$OE_CONFIG
echo '### END INIT INFO' >> ~/$OE_CONFIG
echo 'PATH=/bin:/sbin:/usr/bin' >> ~/$OE_CONFIG
echo "DAEMON=$OE_HOME_EXT/openerp-server" >> ~/$OE_CONFIG
echo "NAME=$OE_CONFIG" >> ~/$OE_CONFIG
echo "DESC=$OE_CONFIG" >> ~/$OE_CONFIG
echo '' >> ~/$OE_CONFIG
echo '# Specify the user name (Default: odoo).' >> ~/$OE_CONFIG
echo "USER=$OE_USER" >> ~/$OE_CONFIG
echo '' >> ~/$OE_CONFIG
echo '# Specify an alternate config file (Default: /etc/openerp-server.conf).' >> ~/$OE_CONFIG
echo "CONFIGFILE=\"$OE_DIR_ETC/$OE_CONFIG.conf\"" >> ~/$OE_CONFIG
echo '' >> ~/$OE_CONFIG
echo '# pidfile' >> ~/$OE_CONFIG
echo 'PIDFILE=/var/run/$NAME.pid' >> ~/$OE_CONFIG
echo '' >> ~/$OE_CONFIG
echo '# Additional options that are passed to the Daemon.' >> ~/$OE_CONFIG
echo 'DAEMON_OPTS="-c $CONFIGFILE"' >> ~/$OE_CONFIG
echo '[ -x $DAEMON ] || exit 0' >> ~/$OE_CONFIG
echo '[ -f $CONFIGFILE ] || exit 0' >> ~/$OE_CONFIG
echo 'checkpid() {' >> ~/$OE_CONFIG
echo '[ -f $PIDFILE ] || return 1' >> ~/$OE_CONFIG
echo 'pid=`cat $PIDFILE`' >> ~/$OE_CONFIG
echo '[ -d /proc/$pid ] && return 0' >> ~/$OE_CONFIG
echo 'return 1' >> ~/$OE_CONFIG
echo '}' >> ~/$OE_CONFIG
echo '' >> ~/$OE_CONFIG
echo 'case "${1}" in' >> ~/$OE_CONFIG
echo 'start)' >> ~/$OE_CONFIG
echo 'echo -n "Starting ${DESC}: "' >> ~/$OE_CONFIG
echo 'start-stop-daemon --start --quiet --pidfile ${PIDFILE} \' >> ~/$OE_CONFIG
echo '--chuid ${USER} --background --make-pidfile \' >> ~/$OE_CONFIG
echo '--exec ${DAEMON} -- ${DAEMON_OPTS}' >> ~/$OE_CONFIG
echo 'echo "${NAME}."' >> ~/$OE_CONFIG
echo ';;' >> ~/$OE_CONFIG
echo 'stop)' >> ~/$OE_CONFIG
echo 'echo -n "Stopping ${DESC}: "' >> ~/$OE_CONFIG
echo 'start-stop-daemon --stop --quiet --pidfile ${PIDFILE} \' >> ~/$OE_CONFIG
echo '--oknodo' >> ~/$OE_CONFIG
echo 'echo "${NAME}."' >> ~/$OE_CONFIG
echo ';;' >> ~/$OE_CONFIG
echo '' >> ~/$OE_CONFIG
echo 'restart|force-reload)' >> ~/$OE_CONFIG
echo 'echo -n "Restarting ${DESC}: "' >> ~/$OE_CONFIG
echo 'start-stop-daemon --stop --quiet --pidfile ${PIDFILE} \' >> ~/$OE_CONFIG
echo '--oknodo' >> ~/$OE_CONFIG
echo 'sleep 1' >> ~/$OE_CONFIG
echo 'start-stop-daemon --start --quiet --pidfile ${PIDFILE} \' >> ~/$OE_CONFIG
echo '--chuid ${USER} --background --make-pidfile \' >> ~/$OE_CONFIG
echo '--exec ${DAEMON} -- ${DAEMON_OPTS}' >> ~/$OE_CONFIG
echo 'echo "${NAME}."' >> ~/$OE_CONFIG
echo ';;' >> ~/$OE_CONFIG
echo '*)' >> ~/$OE_CONFIG
echo 'N=/etc/init.d/${NAME}' >> ~/$OE_CONFIG
echo 'echo "Usage: ${NAME} {start|stop|restart|force-reload}" >&2' >> ~/$OE_CONFIG
echo 'exit 1' >> ~/$OE_CONFIG
echo ';;' >> ~/$OE_CONFIG
echo '' >> ~/$OE_CONFIG
echo 'esac' >> ~/$OE_CONFIG
echo 'exit 0' >> ~/$OE_CONFIG

echo -e "* Security Init File"
mv ~/$OE_CONFIG /etc/init.d/$OE_CONFIG
chmod 755 /etc/init.d/$OE_CONFIG
chown root: /etc/init.d/$OE_CONFIG

echo -e "* Start ODOO on Startup"
update-rc.d $OE_CONFIG defaults
 
echo "Done! The ODOO server can be started with: service $OE_CONFIG start"
echo "Check $OE_CONFIG and create your PostgreSQL user permissions with $OE_DB_USER:$OE_DB_PASS"