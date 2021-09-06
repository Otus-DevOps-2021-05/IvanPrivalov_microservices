FROM alpine:3.14

WORKDIR /tmp/mongodb
RUN   apk update \
  &&   apk --no-cache add ca-certificates wget \
  &&   update-ca-certificates

RUN wget https://github.com/percona/mongodb_exporter/releases/download/v0.20.7/mongodb_exporter-0.20.7.linux-amd64.tar.gz && \
    tar xvzf mongodb_exporter-0.20.7.linux-amd64.tar.gz && \
    cp mongodb_exporter-0.20.7.linux-amd64/mongodb_exporter /usr/local/bin/. && \
    rm -rf /tmp/mongodb

WORKDIR /

EXPOSE 9216

CMD ["mongodb_exporter"]
