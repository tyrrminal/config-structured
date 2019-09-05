#THIS DOCKERFILE IS FOR RUNNING TESTS ONLY

## docker build -t concert/{name}:test . &&
## docker run --rm -e DB_PASS=dbpass concert/{name}:test

FROM perl:5.22 as cartoninstall
RUN cpanm Carton
ENV PERL5LIB=/usr/share/perl5
WORKDIR /app
COPY cpanfile* ./
RUN carton install --deployment

#------------------------------------------------------------------------------------------

FROM perl:5.22

WORKDIR /test

COPY --from=cartoninstall /app/local             /carton/local
COPY . .

ENV PERL5LIB="/carton/local/lib/perl5:/carton/local/lib/perl5/x86_64-linux-gnu:${PERLLIB}"
ENV    PATH="/carton/local/bin:${PATH}"

ENTRYPOINT ["carton","exec","prove","-l","-I","t/tests"]
