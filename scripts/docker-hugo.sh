#!/bin/bash

IMAGE_NAME='yrzr/hugo'
IMAGE_TAG='latest'
CONTAINER_NAME=$(echo $(basename "$0") | cut -f 1 -d '.')
MEM_SIZE='128M'

docker pull ${IMAGE_NAME}:${IMAGE_TAG}
docker stop ${CONTAINER_NAME}
docker rm ${CONTAINER_NAME}

docker run \
  -it --rm \
  --user 1000:1000 \
  --name ${CONTAINER_NAME} \
  --memory ${MEM_SIZE} \
  --publish 1313:1313 \
  --volume /etc/localtime:/etc/localtime:ro \
  --volume /srv/${CONTAINER_NAME}/yrzr:/site \
  --volume /srv/nginx/www/html/htdocs/hugo:/site/public \
  ${IMAGE_NAME}:${IMAGE_TAG} $1
