# docker-jekyll-gallery

creates a nginx docker image with a jekyll based image library. Image source is a zip file available via http(s) 

## usage

  docker build \
    --build-arg "ZIP_URL=https://link/to/zip/file" \
    --build-arg "TITLE=Title of Image-Gallery" \
    --build-arg "THUMBNAIL_SIZE=x300" \
    --build-arg "DISPLAY_SIZE=2048x2048" \
    -t myImageGallery