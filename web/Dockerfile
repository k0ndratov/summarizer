# Stage 1: compile gems with the full toolchain.
FROM ruby:3.3-slim AS gems

RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends build-essential git libsqlite3-dev libyaml-dev pkg-config \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install \
 && rm -rf /usr/local/bundle/cache /usr/local/bundle/gems/*/ext /usr/local/bundle/gems/*/test \
 && chmod -R a+rwX /usr/local/bundle

# Stage 2: runtime only — shared libs the gems link against, curl for the healthcheck.
FROM ruby:3.3-slim

RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends libsqlite3-0 libyaml-0-2 curl \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /data && chmod 777 /data

COPY --from=gems /usr/local/bundle /usr/local/bundle

WORKDIR /app
COPY . .

ENV RAILS_ENV=development BINDING=0.0.0.0
EXPOSE 3000
ENTRYPOINT ["bin/docker-entrypoint"]
CMD ["bin/rails", "server", "-b", "0.0.0.0"]
