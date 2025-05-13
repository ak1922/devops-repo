#! /bin/bash

yum update -y
yum install python3 -y
pip3 install flask
pip3 install flask_mysql
yum install git -y
cd /home/ec2-user/ && git clone git@github.com:ak1922/key_bridge.git
cd key_bridge/ && python3 app.py
