FROM ruby:3.2

# Install dependencies
RUN apt-get update -qq && apt-get install -y \
  build-essential libpq-dev nodejs yarn

# Set app directory
WORKDIR /app

# Set up bundler
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy app files
COPY . .

# Precompile assets & prepare db
CMD ["bash", "-c", "rm -f tmp/pids/server.pid && bundle exec rails db:prepare && bundle exec rails s -b 0.0.0.0"]
