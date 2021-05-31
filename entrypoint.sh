#!/bin/bash
/usr/local/bin/nginx-fpm-entrypoint.sh
# Set environment

GITHUB_TOKEN=${GITHUB_TOKEN:-}

# Winter CMS
CMS_BRANCH=${CMS_BRANCH:-develop}
CMS_COMMIT_HASH=${CMS_COMMIT_HASH:-}
CMS_PULL_ID=${CMS_PULL_ID:-}

CMS_ADMIN_PASSWORD=${CMS_ADMIN_PASSWORD:-password}
CMS_PLUGINS=${CMS_PLUGINS:-}
CMS_THEMES=${CMS_THEMES:-}

# Winter Storm
STORM_BRANCH=${STORM_BRANCH:-}
STORM_COMMIT_HASH=${STORM_COMMIT_HASH:-}
STORM_PULL_ID=${STORM_PULL_ID:-}
export COMPOSER_AUTH="{\"github-oauth\": {\"github.com\": "\"${GITHUB_TOKEN}\""}}"
### Useful Functions ###

install_plugins()
{
    # If $CMS_PLUGINS is set
    if [ ! -z $CMS_PLUGINS ] ; then
        echo "Install plugins..."
        IFS=', ' read -r -a PLUGIN_ARRAY <<< "$CMS_PLUGINS"
        for plugin in "${PLUGIN_ARRAY[@]}"
            do
              echo "going to install $plugin"
              composer require $plugin
            done
    fi
}

install_themes()
{
    # If $CMS_THEMES is set
    if [ ! -z $CMS_THEMES ] ; then
        echo "Install themes..."
        IFS=', ' read -r -a THEME_ARRAY <<< "$CMS_THEMES"
        for theme in ${THEME_ARRAY[@]}
            do
              echo "going to install $theme"
              composer require $theme
            done
    fi
}

### End Functions ###

### A completely stateless Winter CMS container ###
chown -R $USER_UID:$USER_GID /var/www/
su $USER_NAME

echo "Setting up app directory..."
cd /var/www/
rm -rf /var/www/app
## First, clone the specified winter CMS git branch
git clone https://github.com/wintercms/winter --branch "$CMS_BRANCH" app
cd /var/www/app

## Get a specific commit hash if required
if [ -n "$CMS_COMMIT_HASH" ] ; then
  git checkout $CMS_COMMIT_HASH
fi

## Get the specified pull request and check it out
if [ -n "$CMS_PULL_ID" ] ; then
  echo "Fetching wintercms/winter pull request $CMS_PULL_ID"
  git fetch origin pull/"$CMS_PULL_ID"/head:pr"$CMS_PULL_ID"
  git checkout pr"$CMS_PULL_ID"
else
  echo "No pull request ID specified"
fi

## Set the config to match our setup
echo "applying configuration..."
sed -i 's/127.0.0.1/database/g' /var/www/app/config/database.php

## Composer stuff
echo "Let composer install the dependencies"

## If set, get the correct branch of Storm
if [ -n "$STORM_BRANCH" ] ; then
  if [ -z "$STORM_COMMIT_HASH" ] ; then
    echo "Requiring winter/storm $STORM_BRANCH"
    composer --no-cache require winter/storm:dev-"$STORM_BRANCH" --prefer-source --no-install --no-scripts
  else
    echo "Requiring winter/storm $STORM_BRANCH ($STORM_COMMIT_HASH)"
    composer --no-cache require winter/storm:dev-"$STORM_BRANCH#$STORM_COMMIT_HASH" --prefer-source --no-install --no-scripts
  fi
else
  echo "No changes to winter/storm"
fi

## Composer install to set up the vendor directories
composer --no-cache --no-scripts install

## Get the specified storm pull request and check it out
if [ -n "$STORM_PULL_ID" ] ; then
  cd /var/www/app/vendor/winter/storm
  echo "Fetching wintercms/storm pull request $STORM_PULL_ID"
  git fetch origin pull/"$STORM_PULL_ID"/head:pr"$STORM_PULL_ID"
  git checkout pr"$STORM_PULL_ID"
  cd /var/www/app
  # Move storm out of the vendor dir to require as local
  mv vendor/winter/ /var/www/
  composer config repositories.storm path /var/www/winter/storm
  composer --no-cache --no-scripts require winter/storm:dev-pr"$STORM_PULL_ID"
fi

cd /var/www/app

## Begin up Winter CMS

php artisan key:generate

DB_MAX_TRIES=5
DB_SLEEP=10
DB_UP=0
DB_ATTEMPT=0
echo "Attempting to connect to database..."

while [ $DB_ATTEMPT -le $DB_MAX_TRIES ] ; do
  php artisan winter:up
  if [ $? -eq 0 ] ; then
    DB_UP=1
    echo "Database is up"
    break
  else
    DB_ATTEMPT=$((DB_ATTEMPT+1))
    echo "Database is not ready. Sleeping for $DB_SLEEP seconds"
    sleep $DB_SLEEP
  fi
done

if [ $DB_UP -eq 1 ] ; then
  echo "Successfully connected to the database"
  php artisan winter:version
  php artisan package:discover
  php artisan winter:passwd admin "$CMS_ADMIN_PASSWORD"
  install_plugins
  install_themes
else
  echo "Could not connect to the database. Check your configuration"
fi

echo "Setting permissions ($USER_UID:$USER_GID) ..."
chown -R $USER_UID:$USER_GID /var/www/app

exec "$@"
