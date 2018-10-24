###############################################################################
# Download
###############################################################################
FROM mwendler/wget:latest as download
RUN mkdir -p /tmp/download && chmod 777 /tmp/download
WORKDIR /tmp/download
RUN wget --no-check-certificate -O download.zip "https://doc-10-4g-docs.googleusercontent.com/docs/securesc/ha0ro937gcuc7l7deffksulhg5h7mbp1/115peq78egqgnnl0uvna31uocf89cmrt/1540360800000/10332296204753757044/*/1VvuUkxWRNN5Kl-25VRYKwfJE2K_fffIz?e=download"

###############################################################################
# Unzip
###############################################################################
FROM garthk/unzip:latest as unzip
RUN mkdir -p /tmp/download
RUN mkdir -p /tmp/unzipped
COPY --from=download /tmp/download/download.zip /tmp/download/download.zip
WORKDIR /tmp/download
RUN unzip -d /tmp/unzipped/ download.zip

###############################################################################
# Convert to JPEG
###############################################################################
FROM v4tech/imagemagick:latest as jpeg
RUN mkdir -p /tmp/images/orig
COPY --from=unzip /tmp/unzipped /tmp/images
WORKDIR /tmp/images
RUN for i in *.* ; do convert "$i" orig/${i%.*}.jpg ; done

###############################################################################
# Generate Donwload package
###############################################################################
FROM kramos/alpine-zip as package
RUN mkdir -p /tmp/images/orig
RUN mkdir -p /tmp/package
COPY --from=jpeg /tmp/images/orig /tmp/images/orig
WORKDIR /tmp/
RUN zip download.zip /tmp/images/orig/*

###############################################################################
# Generate Thumbnails
###############################################################################
FROM v4tech/imagemagick:latest as thumbnail
ENV THUMBNAIL_SIZE x300
ENV DISPLAY_SIZE 2048x2048
COPY --from=jpeg /tmp/images/orig /tmp/orig
WORKDIR /tmp/orig
RUN mkdir /tmp/images
RUN mkdir /tmp/images/thumbnails
RUN for i in *.* ; do convert "$i" -resize $DISPLAY_SIZE /tmp/images/${i%.*}.jpg ; done
RUN for i in *.* ; do convert "$i" -resize $THUMBNAIL_SIZE /tmp/images/thumbnails/${i%.*}.jpg ; done

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
RUN mkdir -p /tmp/html && chown jekyll:jekyll /tmp/html
WORKDIR /tmp/html
RUN ls -la .
RUN jekyll new .
RUN ls -la /tmp/html
COPY --from=thumbnail /tmp/images /tmp/html/img
COPY --from=package /tmp/download.zip /tmp/html/download.zip
RUN mkdir -p /tmp/html/_includes
ADD _includes /tmp/html/_includes
ADD index.md /tmp/html/index.md
ADD css /tmp/html/css
ADD js /tmp/html/js
COPY --from=config _config.yml /tmp/html/_config.yml
RUN ls -la /tmp/html
RUN jekyll build 
RUN ls -la _site
RUN cat _config.yml

###############################################################################
# Build nginx
###############################################################################
FROM nginx:latest as nginx
COPY --from=jekyll /tmp/html/_site /usr/share/nginx/html
RUN ls -la /usr/share/nginx/html
EXPOSE 80