#!/bin/bash

set -e

# server
APP_SERVER_SSH="isucon14-1"
NGINX_SERVER_SSH="isucon14-1"
MYSQL_SERVER_SSH="isucon14-2"

# variables
APP_BIN_NAME="isuride"
APP_SERVICE="isuride-go.service"
NGINX_CONF_NAME="isuride.conf"

# server info
APP_SERVER_USER=$(ssh $APP_SERVER_SSH "whoami")
APP_SERVER_IP=$(ssh $APP_SERVER_SSH "hostname -I")
NGINX_SERVER_USER=$(ssh $NGINX_SERVER_SSH "whoami")
NGINX_SERVER_IP=$(ssh $NGINX_SERVER_SSH "hostname -I")
MYSQL_SERVER_USER=$(ssh $MYSQL_SERVER_SSH "whoami")
MYSQL_SERVER_IP=$(ssh $MYSQL_SERVER_SSH "hostname -I")

# build go app
cd ./go
go mod tidy && GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o $APP_BIN_NAME
cd ../

# update go app
scp -r ./go/$APP_BIN_NAME $APP_SERVER_USER@$APP_SERVER_SSH:~/$APP_BIN_NAME
ssh $APP_SERVER_SSH "
  sudo systemctl stop $APP_SERVICE
  sudo chown isucon:isucon ~/$APP_BIN_NAME
  sudo cp ~/$APP_BIN_NAME /home/isucon/webapp/go/$APP_BIN_NAME
  sudo systemctl start $APP_SERVICE
  rm ~/$APP_BIN_NAME
"

# update nginx config
scp ./etc/nginx/nginx.conf $NGINX_SERVER_USER@$NGINX_SERVER_SSH:~/nginx.conf
ssh $NGINX_SERVER_SSH "
  sudo cp ~/nginx.conf /etc/nginx/nginx.conf
  sudo systemctl restart nginx
  rm ~/nginx.conf
"
scp ./etc/nginx/app.conf $NGINX_SERVER_USER@$NGINX_SERVER_SSH:~/$NGINX_CONF_NAME
ssh $NGINX_SERVER_SSH "
  sudo cp ~/$NGINX_CONF_NAME /etc/nginx/sites-enabled/$NGINX_CONF_NAME
  sudo systemctl restart nginx
  rm ~/$NGINX_CONF_NAME
"

# update mysql config
scp ./etc/mysql/my.cnf $MYSQL_SERVER_USER@$MYSQL_SERVER_SSH:~/my.cnf
ssh $MYSQL_SERVER_SSH "
  sudo cp ~/my.cnf /etc/mysql/my.cnf
  sudo systemctl restart mysql
  rm ~/my.cnf
"

# update db initialize
scp ./sql/init.sh $APP_SERVER_USER@$APP_SERVER_SSH:~/init.sh
ssh $APP_SERVER_SSH "
  sudo cp -r ~/init.sh /home/isucon/webapp/sql/init.sh
  sudo chown isucon:isucon /home/isucon/webapp/sql/init.sh
  rm -r ~/init.sh
"
scp ./sql/1-schema.sql $APP_SERVER_USER@$APP_SERVER_SSH:~/1-schema.sql
ssh $APP_SERVER_SSH "
  sudo cp -r ~/1-schema.sql /home/isucon/webapp/sql/1-schema.sql
  sudo chown isucon:isucon /home/isucon/webapp/sql/1-schema.sql
  rm -r ~/1-schema.sql
"
scp ./sql/4-alter.sql $APP_SERVER_USER@$APP_SERVER_SSH:~/4-alter.sql
ssh $APP_SERVER_SSH "
  sudo cp -r ~/4-alter.sql /home/isucon/webapp/sql/4-alter.sql
  sudo chown isucon:isucon /home/isucon/webapp/sql/4-alter.sql
  rm -r ~/4-alter.sql
"
