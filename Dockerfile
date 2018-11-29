#THIS DOCKERFILE IS FOR RUNNING TESTS ONLY

## docker build -t concert/{name}:test . &&
## docker run --rm -e DB_PASS=dbpass concert/{name}:test

FROM ubuntu:16.04

RUN apt-get update && apt-get install -qy \
  --allow-downgrades --allow-remove-essential --allow-change-held-packages \
  build-essential \
  perl \
  carton \
  cpanminus

WORKDIR /test

ENV PERL_CARTON_MIRROR=http://pamid.concertpharma.com:3111/ PERL_CARTON_PATH=/carton/local
COPY cpanfile ./
RUN carton install

COPY . .

ENTRYPOINT ["carton","exec","prove","-l","-I","t/tests"]
