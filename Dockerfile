# Dockerfile for rAthena Development Environment

# Use a recent Ubuntu image as the base
FROM ubuntu:22.04

# Prevent apt-get from asking for user input during the build process
ENV DEBIAN_FRONTEND=noninteractive

# Update the package list and install all dependencies required by rAthena
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    libmariadb-dev \
    zlib1g-dev \
    libcurl4-openssl-dev \
    mariadb-client \
    && rm -rf /var/lib/apt/lists/*

# Ubuntu's libmariadb-dev omits the mysql_config/libmysqlclient.so compat
# symlinks that rAthena's ./configure script expects (it hardcodes a check
# for -lmysqlclient and the mysql_config binary), so provide them manually.
RUN ln -sf "$(command -v mariadb_config)" /usr/bin/mysql_config \
    && ln -sf libmariadb.so.3 /usr/lib/x86_64-linux-gnu/libmysqlclient.so

# Set the working directory where we will mount our source code
WORKDIR /usr/src/rathena

# Expose the network ports
EXPOSE 6900 6121 5121

# Default command to keep the container running
CMD ["tail", "-f", "/dev/null"]