# Use the tidyverse-equipped image from rocker
FROM rocker/r-ver:3.6.1

# Install required packages
RUN apt-get dist-upgrade && apt-get update \
  && apt-get install -y libcurl4-openssl-dev libssl-dev libxml2-dev 

# Copy project files and make working directory
COPY  . /project/
WORKDIR /project/

# Install dependencies
RUN Rscript install.R

# Default entrypoint
ENTRYPOINT  ["/bin/bash"]