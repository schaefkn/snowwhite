#!/usr/bin/env bash

# Versions
ERLANG_VERSION=23.2.3-1
ELIXIR_VERSION=1.11.3
POSTGRES_VERSION=13
NODE_VERSION=15

# Postgres Credentials
DB_ADMIN_PASS=postgres
DB_USER=snowwhite
DB_PASSWORD=snowwhite

##########
# HELPER
##########
print_db_usage () {
  echo "Your PostgreSQL database has been setup and can be accessed on your local machine on the forwarded port (default: 5432)"
  echo "  Host: localhost"
  echo "  Port: 5432"
  echo "  Database: <DATABASE_NAME>"
  echo "  Username: $DB_USER"
  echo "  Password: $DB_PASSWORD"
  echo ""
  echo "Admin access to postgres user via VM:"
  echo "  vagrant ssh"
  echo "  sudo su - postgres"
  echo ""
  echo "psql access to app database user via VM:"
  echo "  vagrant ssh"
  echo "  sudo su - postgres"
  echo "  PGUSER=$DB_USER PGPASSWORD=$DB_PASSWORD psql -h localhost <DATABASE_NAME>"
  echo ""
  echo "Env variable for application development:"
  echo "  DATABASE_URL=postgresql://$DB_USER:$DB_PASSWORD@localhost:5432/<DATABASE_NAME>"
  echo ""
  echo "Local command to access the database via psql:"
  echo "  PGUSER=$DB_USER PGPASSWORD=$DB_PASSWORD psql -h localhost -p 5432 <DATABASE_NAME>"
}

# Install basic packages
# inotify is installed because it's a Phoenix dependency
apt-get -qq update
apt-get install -y \
wget \
git \
unzip \
build-essential \
ntp \
inotify-tools

# Install Erlang
echo "deb https://packages.erlang-solutions.com/ubuntu focal contrib" >> /etc/apt/sources.list.d/rabbitmq.list && \
apt-key adv --fetch-keys http://packages.erlang-solutions.com/ubuntu/erlang_solutions.asc && \
apt-get -qq update && \
apt-get install -y -f esl-erlang="1:${ERLANG_VERSION}"

# Install Elixir
cd / && mkdir -p elixir && cd elixir && \
wget -q https://github.com/elixir-lang/elixir/releases/download/v$ELIXIR_VERSION/Precompiled.zip && \
unzip Precompiled.zip && \
rm -f Precompiled.zip && \
ln -s /elixir/bin/elixirc /usr/bin/elixirc && \
ln -s /elixir/bin/elixir /usr/bin/elixir && \
ln -s /elixir/bin/mix /usr/bin/mix && \
ln -s /elixir/bin/iex /usr/bin/iex

# Install hex and rebar for the vagrant and ubuntu user
su - vagrant -c '/usr/bin/mix local.hex --force && /usr/bin/mix local.rebar --force'
su - ubuntu -c '/usr/bin/mix local.hex --force && /usr/bin/mix local.rebar --force'

# Install Postgres
echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" >> /etc/apt/sources.list.d/pgdg.list && \
wget -q https://www.postgresql.org/media/keys/ACCC4CF8.asc -O - | apt-key add - && \
apt-get -qq update && \
apt-get -y install postgresql-$POSTGRES_VERSION postgresql-contrib-$POSTGRES_VERSION

# Set Postgres client encoding to UTF8
PG_CONF="/etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf"
PG_HBA="/etc/postgresql/$POSTGRES_VERSION/main/pg_hba.conf"
PG_DIR="/var/lib/postgresql/$POSTGRES_VERSION/main"

# Explicitly set default client_encoding
echo "client_encoding = utf8" >> "$PG_CONF"

# Edit postgresql.conf to change listen address to '*':
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONF"

# Append to pg_hba.conf to add password auth:
echo "host    all             all             all                     md5" >> "$PG_HBA"

# Restart postgresql
service postgresql restart

# Set pqsl password and create new db user
cat << EOF | su - postgres -c psql
ALTER USER postgres WITH ENCRYPTED PASSWORD '$DB_ADMIN_PASS';
CREATE USER $DB_USER PASSWORD '$DB_PASSWORD' CREATEDB;
EOF

# Show db informations
print_db_usage

# Install Node.js and NPM
curl -sL https://deb.nodesource.com/setup_$NODE_VERSION.x | sudo -E bash - && \
apt-get install -y -f nodejs

# If seeds.exs exists we assume it is a Phoenix project
if [ -f /vagrant/priv/repo/seeds.exs ]
  then
    # Set up and migrate database
    su - ubuntu -c 'cd /vagrant && mix deps.get && mix ecto.create && mix ecto.migrate'
    # Run Phoenix seed data script
    su - ubuntu -c 'cd /vagrant && mix run priv/repo/seeds.exs'
fi
