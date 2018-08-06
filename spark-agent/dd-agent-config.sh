#!/bin/bash

DD_API_KEY=$1
ENV_TAG=$2
HOST_IP=$(ip a sh | awk '/eth/ {print $2}' | awk '/[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/ {print $1}' | cut -d"/" -f1)
echo "Running on: "$HOST_IP
echo "Updating datadog.conf on $(hostname -f)"
#Upgrade datadog agent
until DD_UPGRADE=true bash -c "$(curl -L https://raw.githubusercontent.com/DataDog/datadog-agent/master/cmd/agent/install_script.sh)"
do
 echo "Try again"
 sleep 2
done

## For All DD Agents ##
## Copy the example config into place and plug in your API key () ##
sudo sh -c "sed 's/api_key:.*/api_key: $DD_API_KEY/' /etc/datadog-agent/datadog.yaml.example > /etc/datadog-agent/datadog.yaml"

##add dd-agent user to docker ##
sudo usermod -a -G docker dd-agent

## Create yaml files from examples
sudo cp /etc/datadog-agent/conf.d/docker.d/conf.yaml.example /etc/datadog-agent/conf.d/docker.d/conf.yaml -p
sudo sed -i 's/# collect_labels_as_tags:/collect_labels_as_tags:/g' /etc/datadog-agent/conf.d/docker.d/conf.yaml
sudo sed -i 's/"com.docker.compose.service", "com.docker.compose.project"/"customer_name"/g' /etc/datadog-agent/conf.d/docker.d/conf.yaml
sudo sed -i "s/# tags:/tags:/g" /etc/datadog-agent/datadog.yaml
sudo sed -i "s/#   - env:prod/   - env:$ENV_TAG/g" /etc/datadog-agent/datadog.yaml
## Enable local traffic to agent ##
sudo sed -i.back 's,# dogstatsd_non_local_traffic: no,dogstatsd_non_local_traffic: true,' /etc/datadog-agent/datadog.yaml


#Check if general slave host (not master)
ip a sh | awk '/eth/ {print $2}' | awk '/[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/ {print $1}' | cut -d"/" -f1 | grep "^10\.*\.*"    
if [ $? -eq 0 ]; then
    echo "General slave host agent detected"
    sudo cp /etc/datadog-agent/conf.d/mesos_slave.d/conf.yaml.example /etc/datadog-agent/conf.d/mesos_slave.d/conf.yaml -p
    sudo sed -i "s/localhost/$HOST_IP/g" /etc/datadog-agent/conf.d/mesos_slave.d/conf.yaml
    sudo sed -i "s/#   - role:database/   - role:mesos-slave/g" /etc/datadog-agent/datadog.yaml
fi


#Check if master agent
ip a sh | awk '/eth/ {print $2}' | awk '/[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/ {print $1}' | cut -d"/" -f1 | grep "^172\.16\.*"
if [ $? -eq 0 ]; then
    echo "General master host agent detected"
    sudo cp /etc/datadog-agent/conf.d/mesos_master.d/conf.yaml.example /etc/datadog-agent/conf.d/mesos_master.d/conf.yaml -p
    sudo sed -i "s/localhost/$HOST_IP/g" /etc/datadog-agent/conf.d/mesos_master.d/conf.yaml
    sudo sed -i "s/#   - role:database/   - role:mesos-master/g" /etc/datadog-agent/datadog.yaml
    sudo cp /etc/datadog-agent/conf.d/marathon.d/conf.yaml.example /etc/datadog-agent/conf.d/marathon.d/conf.yaml -p
    sudo sed -i 's,# - url: "https://server:port",- url: "http://marathon.mesos:8080",g' /etc/datadog-agent/conf.d/marathon.d/conf.yaml
    sudo cp /etc/datadog-agent/conf.d/zk.d/conf.yaml.example /etc/datadog-agent/conf.d/zk.d/conf.yaml
fi

#Check if public agent
ip a sh | awk '/eth/ {print $2}' | awk '/[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/ {print $1}' | cut -d"/" -f1 | grep "^10\.0\.*"
if [ $? -eq 0 ]; then
    echo "Public host agent detected"
    sudo cp /etc/datadog-agent/conf.d/haproxy.d/conf.yaml.example /etc/datadog-agent/conf.d/haproxy.d/conf.yaml -p
    sudo sed -i "s,http://localhost/admin?stats,http://localhost:9090/haproxy?stats,g" /etc/datadog-agent/conf.d/haproxy.d/conf.yaml
    sudo cp /etc/datadog-agent/conf.d/kong.d/conf.yaml.example /etc/datadog-agent/conf.d/kong.d/conf.yaml -p
    sudo sed -i "s,http://localhost:8001/status,http://localhost:31002/status,g" /etc/datadog-agent/conf.d/kong.d/conf.yaml
    sudo cp /etc/datadog-agent/conf.d/nginx.d/conf.yaml.example /etc/datadog-agent/conf.d/nginx.d/conf.yaml -p
    sudo sed -i "s,http://localhost/nginx_status/,http://localhost:8085/nginx_status/,g" /etc/datadog-agent/conf.d/nginx.d/conf.yaml
fi

## Start the Agent ##
sudo systemctl restart datadog-agent.service

until sudo systemctl status dcos-mesos-slave
do
 echo "Try again"
 sleep 10
done
sudo echo "MESOS_ATTRIBUTES=AGENT_TYPE:SPARK;" | sudo tee /var/lib/dcos/mesos-slave-common

sudo systemctl stop dcos-mesos-slave
sudo rm -f /var/lib/mesos/slave/meta/slaves/latest
sudo systemctl start dcos-mesos-slave
