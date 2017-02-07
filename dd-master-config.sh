#!/bin/bash

DD_API_KEY=$1
ENV_TAG=$2

while ( ! (find /var/log/azure/Microsoft.OSTCExtensions.LinuxDiagnostic/*/extension.log | xargs grep "Start mdsd"));
do
  sleep 5
done


## Set up apt so that it can download through https ##
sudo apt-get -y update
sudo apt-get -y install apt-transport-https

## Set up the Datadog deb repo on your system and import Datadog's apt key ##
sudo sh -c "echo 'deb https://apt.datadoghq.com/ stable main' > /etc/apt/sources.list.d/datadog.list"
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys C7A7DA52

## Update your local apt repo and install the Agent ##
sudo apt-get -y update
sudo apt-get -y install datadog-agent

## Copy the example config into place and plug in your API key  ##
sudo sh -c "sed 's/api_key:.*/api_key: $DD_API_KEY/' /etc/dd-agent/datadog.conf.example > /etc/dd-agent/datadog.conf"

## Create yaml files from examples
sudo cp /etc/dd-agent/conf.d/mesos_master.yaml.example /etc/dd-agent/conf.d/mesos_master.yaml
sudo cp /etc/dd-agent/conf.d/zk.yaml.example /etc/dd-agent/conf.d/zk.yaml
sudo cp /etc/dd-agent/conf.d/marathon.yaml.example /etc/dd-agent/conf.d/marathon.yaml
sudo cp /etc/dd-agent/conf.d/haproxy.yaml.example /etc/dd-agent/conf.d/haproxy.yaml

## Edit Yaml files ##
# sudo  sed -i "s/# hostname: mymachine.mydomain/hostname:$(hostname)/g" /etc/dd-agent/datadog.conf
sudo sed -i "s/- host: localhost/- host: leader.mesos/g" /etc/dd-agent/conf.d/zk.yaml
sudo sed -i "s/localhost/leader.mesos/g" /etc/dd-agent/conf.d/mesos_master.yaml
sudo sed -i "s/# tags: mytag, env:prod, role:database/ tags: env:$ENV_TAG, role:mesos-master/g" /etc/dd-agent/datadog.conf
sudo sed -i 's/# - url: "https:/- url: "http:/g' /etc/dd-agent/conf.d/marathon.yaml
sudo sed -i "s/server:port/leader.mesos:8080/g" /etc/dd-agent/conf.d/marathon.yaml
sudo sed -i "s#- url: http://localhost/admin?stats#- url: http://marathon-lb-default.marathon.mesos:9090/haproxy?stats#g" /etc/dd-agent/conf.d/haproxy.yaml.example




## Start the Agent ##
 sudo /etc/init.d/datadog-agent start