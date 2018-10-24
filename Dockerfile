###############################################################################
# Download
###############################################################################
FROM mwendler/wget:latest as download
WORKDIR /tmp/download
ARG ZIP_URL
RUN mkdir -p /tmp/download && \
    chmod 777 /tmp/download && \
    wget --no-check-certificate -O download.zip $ZIP_URL

###############################################################################
# Unzip
###############################################################################
FROM garthk/unzip:latest as unzip
WORKDIR /tmp/download
RUN mkdir -p /tmp/download && \
    mkdir -p /tmp/unzipped
COPY --from=download /tmp/download/download.zip /tmp/download/download.zip
RUN unzip -d /tmp/unzipped/ -j download.zip

###############################################################################
# Convert to JPEG
###############################################################################
FROM v4tech/imagemagick:latest as jpeg
WORKDIR /tmp/images
RUN mkdir -p /tmp/images/orig
COPY --from=unzip /tmp/unzipped /tmp/images
RUN for i in *.{jpg,jpeg,JPG,JPEG} ; do convert "$i" orig/${i%.*}.jpg ; done

###############################################################################
# Generate Donwload package
###############################################################################
FROM kramos/alpine-zip as package
WORKDIR /tmp/
RUN mkdir -p /tmp/images/orig && \
    mkdir -p /tmp/package
COPY --from=jpeg /tmp/images/orig /tmp/images/orig
RUN zip download.zip /tmp/images/orig/*

###############################################################################
# Generate Thumbnails
###############################################################################
FROM v4tech/imagemagick:latest as thumbnail
WORKDIR /tmp/orig
ARG THUMBNAIL_SIZE
ARG DISPLAY_SIZE
COPY --from=jpeg /tmp/images/orig /tmp/orig
RUN mkdir /tmp/images && \
    mkdir /tmp/images/thumbnails && \
    for i in *.{jpg,jpeg,JPG,JPEG} ; do convert "$i" -resize $DISPLAY_SIZE /tmp/images/${i%.*}.jpg ; done && \
    for i in *.{jpg,jpeg,JPG,JPEG} ; do convert "$i" -resize $THUMBNAIL_SIZE /tmp/images/thumbnails/${i%.*}.jpg ; done

###############################################################################
# Replace Variables in Config
###############################################################################
FROM cirocosta/alpine-envsubst as config
ARG TITLE
ADD _config.yml _config.yml
COPY --from=package /tmp/download.zip download.zip
RUN envsubst < _config.yml > _config.yml

###############################################################################
# Build Jekyll
###############################################################################
FROM jekyll/jekyll:3.8 as jekyll
WORKDIR /tmp/html
RUN mkdir -p /tmp/html && chown jekyll:jekyll /tmp/html
RUN jekyll new .
COPY --from=thumbnail /tmp/images /tmp/html/img
COPY --from=package /tmp/download.zip /tmp/html/download.zip
RUN mkdir -p /tmp/html/_includes
ADD _includes /tmp/html/_includes
ADD index.md /tmp/html/index.md
ADD css /tmp/html/css
ADD js /tmp/html/js
COPY --from=config _config.yml /tmp/html/_config.yml
RUN jekyll build 

###############################################################################
# Build nginx
###############################################################################
FROM nginx:latest as nginx
COPY --from=jekyll /tmp/html/_site /usr/share/nginx/html
RUN ls -la /usr/share/nginx/html
EXPOSE 80