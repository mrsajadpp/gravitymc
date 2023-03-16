#!/bin/bash

# Minecraft version
VERSION=1.19.3
BUILD=448


set -e
root=$PWD
mkdir -p Server
cd Server
export JAVA_HOME=/usr/lib/jvm/java-1.17.2-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH


download() {
    set -e
    echo By executing this script you agree to the JRE License, the PaperMC license,
    echo the Mojang Minecraft EULA,
    echo the NPM license, the MIT license,
    echo and the licenses of all packages used \in this project.
    echo Press Ctrl+C \if you \do not agree to any of these licenses.
    echo Press Enter to agree.
    read -s agree_text
    echo Thank you \for agreeing, the download will now begin.
    wget -O server.jar "https://papermc.io/api/v2/projects/paper/versions/$VERSION/builds/$BUILD/downloads/paper-$VERSION-$BUILD.jar"
    echo Paper downloaded
    wget -O server.properties "https://Minecraft-Server.shaysarkar.repl.co/IMPORTANT/Minecraft Server/server.properties"
    echo Server properties downloaded
    echo "eula=true" > eula.txt
    echo Agreed to Mojang EULA
    wget -O ngrok.zip https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip
    unzip ngrok.zip
    rm -rf ngrok.zip
    echo "Download complete" 
}

require() {
    if [ ! $1 $2 ]; then
        echo $3
        echo "Running download..."
        download
    fi
}
require_file() { require -f $1 "File $1 required but not found"; }
require_dir()  { require -d $1 "Directory $1 required but not found"; }
require_env()  {
    var=`python3 -c "import os;print(os.getenv('$1',''))"`
    if [ -z "${var}" ]; then
        echo "Environment variable $1 not set. "
        echo "In your .env file, add a line with:"
        echo "$1="
        echo "and then right after the = add $2"
        exit
    fi
    eval "$1=$var"
}
require_executable() {
    require_file "$1"
    chmod +x "$1"
}

# server files
require_file "eula.txt"
require_file "server.properties"
require_file "server.jar"
# java
#require_dir "jre"
#require_executable "jre/bin/java"
# ngrok binary
require_executable "ngrok"

# environment variables
require_env "ngrok_token" "your ngrok authtoken from https://dashboard.ngrok.com"
require_env "ngrok_region" "your region, one of:
us - United States (Ohio)
eu - Europe (Frankfurt)
ap - Asia/Pacific (Singapore)
au - Australia (Sydney)
sa - South America (Sao Paulo)
jp - Japan (Tokyo)
in - India (Mumbai)"
require_env "webhook_url" "your Discord webhook URL"

# start ngrok tunnel for Java edition server
echo "Starting ngrok tunnel in region $ngrok_region for Java edition server..."
./ngrok authtoken $ngrok_token
./ngrok tcp -region $ngrok_region --log=stdout 25565 > $root/status.log 2>&1 &
sleep 3 # wait for ngrok to start

# get ngrok tunnel URL and send to Discord webhook
ngrok_url=$(grep -oP "tcp://\K[^:]*:[0-9]+" $root/status.log)
if [ ! -z "$ngrok_url" ]; then
  message="@everyone :rocket: Minecraft Java edition server IP and port: || $ngrok_url ||"
  payload="{\"content\": \"$message\"}"
  curl -X POST -H "Content-Type: application/json" -d "$payload" $webhook_url
  if [ $? -eq 0 ]; then
    echo "Discord webhook sent successfully for Java edition server!"
  else
    echo "Failed to send Discord webhook for Java edition server."
  fi
fi


# start Minecraft server
echo "Starting Minecraft server..."
java -Xmx1G -Xms1G -jar server.jar nogui
