# Use the tidyverse-equipped image from rocker
FROM rocker/r-ver:3.6.1

# Install required packages
RUN apt-get dist-upgrade && apt-get update \
  && apt-get install -y libcurl4-openssl-dev libssl-dev libxml2-dev 

# Copy project files and make working directory
COPY  . /project/
WORKDIR /project/

# Install dependencies
RUN Rscript -e "options(repos = 'https://cran.rstudio.com/')" \
  && Rscript -e "install.packages(c('packrat', 'Rtools', 'Rcpp'))" \
  && Rscript -e "packrat::restore(prompt = FALSE, restart = TRUE)"

# Default entrypoint
ENTRYPOINT  ["/bin/bash"]