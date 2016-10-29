#!/bin/sh

################该脚本用于项目的自动化部署(下载更新代码、打包上传、启动各容器)###################
echo "当前目录："`pwd`

#各个项目包名
APP_COMMON=./zcfront-common/target/zcfront-common-0.0.1-SNAPSHOT.jar
APP_DAO=./zcfront-dao/target/zcfront-dao-0.0.1-SNAPSHOT.jar
APP_JOIN=./zcfront-join/target/zcfront-join-0.0.1-SNAPSHOT.jar
APP_PROVIDER=./zcfront-provider/target/zcfront-provider-0.0.1-SNAPSHOT.jar
APP_PROVIDER_CONF1=./zcfront-provider/target/classes/dsf.properties
APP_PROVIDER_CONF2=./zcfront-provider/target/classes/log4j.xml
APP_WEB=./zcfront-web/target/zcfrontweb.war
APP_TASK=./zcfront-task/target/zcfront-task.war

#需要部署机器ip,username,target path
#IPS="192.168.7.230 192.168.7.231"
IPS=$1
echo "################## 正在部署的机器是 ip：$1 ######################"
USERNAME=dsfuser
CSC_PATH=/home/dsfuser/soft/zcfront-new-container
CSC_PROVIDER_PATH=$CSC_PATH/modules/zcfront-provider
TOMCAT_PATH=/home/dsfuser/soft/zcfront-tomcat
TEST=/home/dsfuser/soft

#1.更新代码
svn up
if [ $? -eq 0 ]; then
    echo "############### 代码更新成功！开始maven打包...################"
    sleep 2
else
    echo "############### 代码更新失败！#################"
    exit 0
fi
#2.打包
echo "################### 开始打包联调测试环境 $2 ######################"
mvn clean package -P $2 -U -Dmaven.test.skip=true
if [ $? -eq 0 ]; then
    echo "############### 项目打包成功！开始部署包...#################"
    sleep 2
else
    echo "############### 项目打包失败！#################"
    exit 0
fi
#3.部署包
for IP in $IPS;do
    echo "############### 开始部署机器ip：$IP ...#################"

    echo "############### 部署机器ip：$IP ,1.停服务...#################"
    ##### ps -ef |grep $TOMCAT_PATH/bin | grep -v 'grep'| awk '{print $2}'
    ##### ssh -n $USERNAME@$IP "TOMID=\$(ps -ef |grep $TOMCAT_PATH | grep -v 'grep'| awk '{print \$2}');kill -9 \$TOMID;"
    #停止tomcat
    TOMCAT_ID=$(ssh -n $USERNAME@$IP "ps -ef |grep $TOMCAT_PATH/bin | grep -v 'grep'| awk '{print \$2}'")
    if [ $TOMCAT_ID ]; then
        ssh -n $USERNAME@$IP "kill -9 $TOMCAT_ID"
        echo "############### 部署机器ip：$IP ,tomcat进程PID：$TOMCAT_ID 停止成功 #################"
        sleep 1
    else
        echo "############### 部署机器ip：$IP ,tomcat已经停止 #################"
    fi
    
    #停止csc container
    CSC_ID=$(ssh -n $USERNAME@$IP "ps -ef |grep $CSC_PATH/conf | grep -v 'grep'| awk '{print \$2}'")
    if [ $CSC_ID ]; then
        ssh -n $USERNAME@$IP "nohup sh $CSC_PATH/bin/stop_csc.sh &"
        echo "############### 部署机器ip：$IP ,csc container进程PID：$CSC_ID 停止成功 #################"
        sleep 1
    else
        echo "############### 部署机器ip：$IP ,csc container已经停止 #################"
    fi
    echo "############### 部署机器ip：$IP ,1.停服务完成 #################"

    
    echo "############### 部署机器ip：$IP ,2.清除tomcat中的包开始... #################"
    ssh -n $USERNAME@$IP "rm -r $TOMCAT_PATH/webapps/*"
    echo "############### 部署机器ip：$IP ,2.清除tomcat中的包结束 #################"

    echo "############### 部署机器ip：$IP ,3.上传包...#################"
    scp $APP_PROVIDER $USERNAME@$IP:$CSC_PROVIDER_PATH
    scp $APP_PROVIDER_CONF1 $USERNAME@$IP:$CSC_PROVIDER_PATH/conf
    scp $APP_PROVIDER_CONF2 $USERNAME@$IP:$CSC_PROVIDER_PATH/conf
    scp $APP_JOIN $USERNAME@$IP:$CSC_PROVIDER_PATH/lib
    scp $APP_COMMON $USERNAME@$IP:$CSC_PROVIDER_PATH/lib
    scp $APP_DAO $USERNAME@$IP:$CSC_PROVIDER_PATH/lib
    scp $APP_WEB $USERNAME@$IP:$TOMCAT_PATH/webapps
    scp $APP_TASK $USERNAME@$IP:$TOMCAT_PATH/webapps
    echo "############### 部署机器ip：$IP ,3.上传包完成 #################"

    
    echo "############### 部署机器ip：$IP ,4.上传依赖jar包 #################"
    #pcif1=../repository/com/lz/cif/pcif/pcif-api/1.0.24-SNAPSHOT/pcif-api-1.0.24-SNAPSHOT.jar
    #pcif2=../repository/com/lz/cif/pcif/pcif-domain/1.0.24-SNAPSHOT/pcif-domain-1.0.24-SNAPSHOT.jar
    #scp $pcif1 $USERNAME@$IP:$CSC_PROVIDER_PATH/lib
    #scp $pcif2 $USERNAME@$IP:$CSC_PROVIDER_PATH/lib
    echo "############### 部署机器ip：$IP ,4.上传依赖jar包完成 #################"

    sleep 1

    echo "############### 部署机器ip：$IP ,5.启动服务开始... #################"
    ssh -n $USERNAME@$IP "sh $TOMCAT_PATH/bin/catalina.sh start"
    sleep 2
    ssh -n $USERNAME@$IP "sh $CSC_PATH/bin/start_csc.sh > /dev/null &"
    echo "############### 部署机器ip：$IP ,服务正在启动... #################"
    sleep 5
    echo "############### 部署机器ip：$IP ,5.启动服务完成 #################"
done

echo "打印啥啦,快去[$IP]检查服务进程是否启动[ps aux | grep zcfront]...quickly!"
