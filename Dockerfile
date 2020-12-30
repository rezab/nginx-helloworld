# Use Alpine Linux as our base Docker image since it's only 5MB in size so
# allows us to create smaller Docker images.
FROM alpine:3.6

# Modify these variables depending on your application:
# * `TZ` Timezone for the app.
ENV TZ=Asia/Tehran

# Install the required packages. Find any additional packages from [the Alpine
# package explorer](https://pkgs.alpinelinux.org/packages).
RUN apk update && \
    apk add tzdata curl bash ca-certificates rsync supervisor nginx \
            python3 uwsgi-python3 && \
    # Ensure the default Python/PIP path uses Python 3
    ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    # Set the timezone based on the `TZ` variable above.
    cp /usr/share/zoneinfo/${TZ} /etc/localtime && \
    echo "${TZ}" > /etc/timezone && \
    # Set the nginx config. Nginx should be run as the default Docker image's
    # user so this has to be commented out in the config.
    sed -i "/user nginx;/c #user nginx;" /etc/nginx/nginx.conf && \
    # Setup permissions for directories and files that will be written to at runtime.
    # These need to be group-writeable for the default Docker image's user.
    # To do this, the folders are created, their group is set to the root
    # group, and the correct group permissions are added.
    touch /.python_history && \
    mkdir -p /run/nginx /var/lib/nginx/logs && \
    chgrp -R 0        /.python_history /var/log /var/run /var/tmp /run/nginx /var/lib/nginx && \
    chmod -R g=u,a+rx /.python_history /var/log /var/run /var/tmp /run/nginx /var/lib/nginx && \
    # Forward the nginx logs to STDOUT and STDERR so they appear
    # in the container logs.
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log && \
    # Clean up the package cache. This reduces the size of the Docker image.
    rm -rf /var/cache/apk/*

# By default all ports are closed in the container. Here the nginx port is opened.
# Other ports that need to be opened can be added here (only ports above 1024), separated by spaces.
EXPOSE 8080
# Set the current directory for the Docker image.
WORKDIR /usr/src/app

# Copy the required configuration files into the Docker image. Don't copy the
# application files yet as they prevent `pip install` from being cached by
# Docker's layer caching mechanism.
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY supervisord.conf /
COPY requirements.txt ./

# Run pip install.
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application files. Initially copy them to a temp directory so their
# permissions can be updated and then copy them to the target directory. This
# reduces the size of the Docker image.
COPY . /tmp/app
RUN chgrp -R 0 /tmp/app && \
    chmod -R g=u /tmp/app && \
    cp -a /tmp/app/. . && \
    rm -rf /tmp/app && \
    chmod +x start.sh

# Specify the command to run when the container starts.
CMD ["./start.sh"]

# Specify the default user for the Docker image to run as.
USER 1001

