#!/bin/bash

DD_API_KEY=$1
ENV_TAG=$2
HOST_IP=$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/')

## Set up apt so that it can download through https ##
sudo echo "MESOS_ATTRIBUTES=AGENT_TYPE:SPARK;" | sudo tee /var/lib/dcos/mesos-slave-common

until sudo apt-get -y update && sudo apt-get -y install apt-transport-https
do
 echo "Try again"
 sleep 2
done

## Set up the Datadog deb repo on your system and import Datadog's apt key ##
sudo sh -c "echo 'deb https://apt.datadoghq.com/ stable 6' > /etc/apt/sources.list.d/datadog.list"
sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 382E94DE

## Update your local apt repo and install the Agent ##

until sudo apt-get -y update && sudo apt-get -y install datadog-agent
do
 echo "Try again"
 sleep 2
done

## Copy the example config into place and plug in your API key () ##
sudo sh -c "sed 's/api_key:.*/api_key: $DD_API_KEY/' /etc/datadog-agent/datadog.yaml.example > /etc/datadog-agent/datadog.yaml"

##add dd-agent user to docker ##
sudo usermod -a -G docker dd-agent

## Create yaml files from examples
sudo cp /etc/datadog-agent/conf.d/docker.d/conf.yaml.example /etc/datadog-agent/conf.d/docker.d/conf.yaml
# sudo cp /etc/datadog-agent/conf.d/haproxy.d/conf.yaml.example /etc/datadog-agent/conf.d/haproxy.d/conf.yaml
sudo cp /etc/datadog-agent/conf.d/mesos_slave.d/conf.yaml.example /etc/datadog-agent/conf.d/mesos_slave.d/conf.yaml

## Edit Yaml files ##
# sudo  sed -i "s/# hostname: mymachine.mydomain/hostname:$(hostname)/g" /etc/dd-agent/datadog.conf
# sudo sed -i "s/# docker_root:/docker_root:/g" /etc/datadog-agent/conf.d/docker.d/conf.yaml
sudo sed -i 's/# collect_labels_as_tags:/collect_labels_as_tags:/g' /etc/datadog-agent/conf.d/docker.d/conf.yaml
sudo sed -i 's/"com.docker.compose.service", "com.docker.compose.project"/"customer_name"/g' /etc/datadog-agent/conf.d/docker.d/conf.yaml
sudo sed -i "s/localhost/$HOST_IP/g" /etc/datadog-agent/conf.d/mesos_slave.d/conf.yaml
sudo sed -i "s/# tags:/tags:/g" /etc/datadog-agent/datadog.yaml
sudo sed -i "s/#   - env:prod/   - env:$ENV_TAG/g" /etc/datadog-agent/datadog.yaml
sudo sed -i "s/#   - role:database/   - role:mesos-slave/g" /etc/datadog-agent/datadog.yaml

## Enable local traffic to agent ##
sudo sed -i.back 's,# dogstatsd_non_local_traffic: no,dogstatsd_non_local_traffic: true,' /etc/datadog-agent/datadog.yaml

## Start the Agent ##
sudo systemctl restart datadog-agent.service

## Add attributes to slaves

until sudo systemctl status dcos-mesos-slave
do
 echo "Try again"
 sleep 10
done
sudo echo "MESOS_ATTRIBUTES=AGENT_TYPE:SPARK;" | sudo tee /var/lib/dcos/mesos-slave-common

sudo systemctl stop dcos-mesos-slave
sudo rm -f /var/lib/mesos/slave/meta/slaves/latest
sudo systemctl start dcos-mesos-slave
