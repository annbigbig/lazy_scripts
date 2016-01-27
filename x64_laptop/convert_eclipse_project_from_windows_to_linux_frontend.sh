#!/bin/bash
# cd into your directory of JavaEE project, then
#cd /home/labasky/workspace/TicketGateway/
cd /home/labasky/workspace/TicketGatewayFrontEnd/
dos2unix .classpath
dos2unix .project
find ./.settings -type f -exec dos2unix {} \;
find ./src -type f -exec dos2unix {} \;
find ./WebContent/ui -type f -exec dos2unix {} \;
dos2unix ./WebContent/WEB-INF/web.xml
