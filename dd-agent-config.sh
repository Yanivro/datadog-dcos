#!/bin/bash

DD_API_KEY=$1
ENV_TAG=$2

## Set up apt so that it can download through https ##
until sudo apt-get -y update && sudo apt-get -y install apt-transport-https
do
 echo "Try again"
 sleep 2
done

## Set up the Datadog deb repo on your system and import Datadog's apt key ##
sudo sh -c "echo 'deb https://apt.datadoghq.com/ stable main' > /etc/apt/sources.list.d/datadog.list"
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys C7A7DA52

## Update your local apt repo and install the Agent ##
sudo apt-get -y update
sudo apt-get -y install datadog-agent

## Copy the example config into place and plug in your API key () ##
sudo sh -c "sed 's/api_key:.*/api_key: $DD_API_KEY/' /etc/dd-agent/datadog.conf.example > /etc/dd-agent/datadog.conf"

## Create yaml files from examples
sudo cp /etc/dd-agent/conf.d/docker_daemon.yaml.example /etc/dd-agent/conf.d/docker_daemon.yaml
sudo cp /etc/dd-agent/conf.d/haproxy.yaml.example /etc/dd-agent/conf.d/haproxy.yaml

sudo cp /etc/dd-agent/conf.d/mesos_slave.yaml.example /etc/dd-agent/conf.d/mesos_slave.yaml

## Edit Yaml files ##
# sudo  sed -i "s/# hostname: mymachine.mydomain/hostname:$(hostname)/g" /etc/dd-agent/datadog.conf
sudo sed -i "s/# docker_root:/docker_root/g" /etc/dd-agent/conf.d/docker_daemon.yaml
sudo sed -i 's/# collect_labels_as_tags:/collect_labels_as_tags:/g' /etc/dd-agent/conf.d/docker_daemon.yaml
sudo sed -i 's/"com.docker.compose.service", "com.docker.compose.project"/"customer_name"/g' /etc/dd-agent/conf.d/docker_daemon.yaml
sudo sed -i "s/localhost/$HOST/g" /etc/dd-agent/conf.d/mesos_slave.yaml
sudo sed -i "s/# tags: mytag, env:prod, role:database/ tags: env:$ENV_TAG, role:mesos-slave/g" /etc/dd-agent/datadog.conf

## Start the Agent ##
 sudo /etc/init.d/datadog-agent start