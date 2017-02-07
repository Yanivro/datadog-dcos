DCOS_CRT=$1
DCOS_KEY=$2

sudo echo "$DCOS_KEY" > /opt/mesosphere/packages/adminrouter--cee9a2abb16c28d1ca6c74af1aff6bc4aac3f134/nginx/conf/common/snakeoil.key
sudo echo "$DCOS_CRT" > /opt/mesosphere/packages/adminrouter--cee9a2abb16c28d1ca6c74af1aff6bc4aac3f134/nginx/conf/common/snakeoil.crt

sudo systemctl restart dcos-adminrouter.service