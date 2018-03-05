#!/bin/bash

DD_API_KEY=$1
ENV_TAG=$2
DCOS_CRT=$3
DCOS_KEY=$4

sleep 120
sh -c 'until ping -c1 leader.mesos;do echo waiting for leader.mesos;sleep 15;done;echo leader.mesos up'

## Set up apt so that it can download through https ##
until sudo apt-get -y update && sudo apt-get -y install apt-transport-https
do
 echo "Try again"
 sleep 2
done

## Set up the Datadog deb repo on your system and import Datadog's apt key ##
sudo sh -c "echo 'deb https://apt.datadoghq.com/ stable 6' > /etc/apt/sources.list.d/datadog.list"
sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 382E94DE

## Update your local apt repo and install the Agent ##
sudo apt-get -y update
sudo apt-get -y install datadog-agent

## Copy the example config into place and plug in your API key  ##
sudo sh -c "sed 's/api_key:.*/api_key: $DD_API_KEY/' /etc/datadog-agent/datadog.yaml.example > /etc/datadog-agent/datadog.yaml"

## Create yaml files from examples
sudo cp /etc/dd-agent/conf.d/mesos_master.yaml.example /etc/dd-agent/conf.d/mesos_master.yaml
sudo cp /etc/dd-agent/conf.d/zk.yaml.example /etc/dd-agent/conf.d/zk.yaml
sudo cp /etc/dd-agent/conf.d/marathon.yaml.example /etc/dd-agent/conf.d/marathon.yaml
#sudo cp /etc/dd-agent/conf.d/haproxy.yaml.example /etc/dd-agent/conf.d/haproxy.yaml

## Edit Yaml files ##
# sudo  sed -i "s/# hostname: mymachine.mydomain/hostname:$(hostname)/g" /etc/dd-agent/datadog.conf
sudo sed -i "s/- host: localhost/- host: leader.mesos/g" /etc/dd-agent/conf.d/zk.yaml
sudo sed -i "s/localhost/leader.mesos/g" /etc/dd-agent/conf.d/mesos_master.yaml
sudo sed -i "s/# tags:/ tags: env:$ENV_TAG, role:mesos-master/g" /etc/datadog-agent/datadog.yaml
sudo sed -i 's/# - url: "https:/- url: "http:/g' /etc/dd-agent/conf.d/marathon.yaml
sudo sed -i "s/server:port/leader.mesos:8080/g" /etc/dd-agent/conf.d/marathon.yaml

## Enable local traffic to agent ##
sudo sed -i.back 's,# dogstatsd_non_local_traffic: no,dogstatsd_non_local_traffic: true,' /etc/datadog-agent/datadog.yaml


## Start the Agent ##
sudo systemctl restart datadog-agent.service

## Add our SSL certificates ##
cd /opt/mesosphere/packages/adminrouter-*/nginx/conf/common/
sudo echo $DCOS_CRT > snakeoil1.crt
sudo echo $DCOS_KEY > snakeoil1.key
sudo awk '{gsub(/\\n/,"\n")}1' snakeoil1.crt > snakeoil.crt
sudo awk '{gsub(/\\n/,"\n")}1' snakeoil1.key > snakeoil.key

sudo systemctl restart dcos-adminrouter.service
