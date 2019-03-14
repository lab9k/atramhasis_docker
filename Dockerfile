FROM "ubuntu"

RUN apt-get update && apt-get install -y \
  sudo \
  npm \
  git \
  curl \
  wget \
  libpq-dev \
  python-pip \
  sqlite3

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get -y install default-jre-headless && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /usr/local/src

RUN cd /usr/local/src && \
  git clone https://github.com/rdfhdt/hdt-cpp.git && \
  apt-get update && apt-get install -y \
  autoconf \
  build-essential \
  libraptor2-dev \
  libtool \
  liblzma-dev \
  liblzo2-dev \
  zlib1g-dev

RUN wget https://github.com/drobilla/serd/archive/v0.28.0.tar.gz && \
  tar -xvzf *.tar.gz && \
  rm *.tar.gz && \
  cd serd-* && \
  ./waf configure && \
  ./waf && \
  ./waf install

RUN cd hdt-cpp && \
  ./autogen.sh && \
  ./configure && \
  make -j2

ENV PATH /usr/local/src/hdt-cpp/hdt-lib/tools:$PATH

WORKDIR /

RUN sudo npm install -g bower

RUN pip install --upgrade pip==9.0.3 && pip install 'atramhasis==0.6.5'

RUN pcreate -s atramhasis_scaffold /opt/atramhasis_gent && \
  cd /opt/atramhasis_gent && \
  pip install -r requirements-dev.txt && \
  python setup.py develop

COPY admin /opt/atramhasis_gent/atramhasis_gent/static/admin

RUN cd /opt/atramhasis_gent/atramhasis_gent/static && \
  npm install -g grunt-cli && \
  bower --allow-root install && \
  cd admin && \
  bower --allow-root install && \
  npm install && \
  grunt -v build && \
  cd ../../.. && \
  alembic upgrade head && \
  # initialize_atramhasis_db development.ini && \
  python setup.py compile_catalog && \
  dump_rdf development.ini

RUN cd /opt/atramhasis_gent && \
  sed -i '/app:main/a atramhasis.rdf2hdt = /usr/local/src/hdt-cpp/hdt-lib/tools/rdf2hdt' development.ini && \
  generate_ldf_config development.ini
  
RUN npm install -g ldf-server

COPY setupdb /opt/setupdb
RUN /bin/bash /opt/setupdb

RUN apt-get update && apt-get install -y supervisor
RUN mkdir -p /var/log/supervisor
COPY atramhasis.conf /opt/atramhasis.conf
EXPOSE 6543 3000
CMD supervisord -c /opt/atramhasis.conf
