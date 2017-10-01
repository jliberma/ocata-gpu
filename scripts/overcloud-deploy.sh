#!/usr/bin/env bash

openstack overcloud deploy --timeout=90 \
	  --templates \
          --ntp-server 128.138.140.44 \
	  -e /home/stack/templates/node-info.yaml \
	  -r /home/stack/templates/roles_data.yaml \
	  --environment-directory /home/stack/templates/environments/
	  

