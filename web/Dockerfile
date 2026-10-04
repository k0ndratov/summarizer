FROM ruby:3.3-slim

RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends build-essential git libsqlite3-dev libyaml-dev pkg-config curl \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /data && chmod 777 /data

WORKDIR /app
COPY Gemfile Gemfile.lock* ./
RUN bundle install && chmod -R a+rwX /usr/local/bundle

COPY . .

ENV RAILS_ENV=development BINDING=0.0.0.0
EXPOSE 3000
ENTRYPOINT ["bin/docker-entrypoint"]
CMD ["bin/rails", "server", "-b", "0.0.0.0"]
