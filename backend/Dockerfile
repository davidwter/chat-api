FROM ruby:3.0-slim-bullseye

# Install essential dependencies
RUN apt-get update -qq && apt-get install -y \
    build-essential \
    libpq-dev \
    nodejs \
    git \
    curl \
    libxml2-dev \
    libxslt-dev \
    zlib1g-dev \
    liblzma-dev \
    libffi-dev \
    libgmp-dev \
    libssl-dev \
    libreadline-dev \
    libyaml-dev \
    libcurl4-openssl-dev \
    pkg-config

# Set working directory
WORKDIR /app

# Copy Gemfile and Gemfile.lock first for efficient caching
COPY Gemfile Gemfile.lock ./

# Update Bundler and install Nokogiri with system libraries
RUN gem install bundler && \
    gem install nokogiri --platform=ruby -- --use-system-libraries

# Remove cached gems to avoid conflicts
RUN rm -rf /usr/local/bundle/cache

# Install project dependencies
RUN bundle install --verbose

# Copy application files
COPY . .

# Expose port
EXPOSE 3000

# Command to run the application
CMD ["rails", "server", "-b", "0.0.0.0"]
