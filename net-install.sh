#!/bin/sh

set -e

SITE_FILE_NAME="${2:-sunpp-20.09.03}.tgz"
IMAGE_DOMAIN="registry.sunpp.cns.atom"
WEAVE_FILE_NAME="weave-2.5.1.tar.gz"
CERT_FILE_NAME="certificates.tgz"
BASE_URL="http://sdn.dc.cns.atom/install/"
INSTALL_DIR="/opt/ekatra/"
SCRIPT_VERSION="0.3.0"


usage() {
    cat >&2 <<EOF
Usage:
$0 --help | help
      --version | version
      setup
      upgrade
      download
      changelog
EOF
}

save_images() {
    docker images | grep "$IMAGE_DOMAIN" | awk '{printf "%s:%s ", $1, $2}' | xargs --no-run-if-empty docker save | gzip -c > images.gz
}

push_images() {
    docker images | grep "$IMAGE_DOMAIN" | awk '{printf "%s:%s\n", $1, $2}'| while read -r line; do docker push $line ;done;
}


gather_facts() {

    # check if essential commands
    if [ ! -x /usr/bin/curl ] ; then
        # some extra check if wget is not installed at the usual place
        command -v curl >/dev/null 2>&1 || { echo >&2 "Please install curl"; exit 1; }
    fi

    if [ ! -x /usr/bin/python ] ; then
         echo >&2 "Please install python"; exit 1;
    fi

    # recognize host os
    if [ -f /etc/os-release ]; then
        # freedesktop.org and systemd
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        # linuxbase.org
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    elif [ -f /etc/lsb-release ]; then
        # For some versions of Debian/Ubuntu without lsb_release command
        . /etc/lsb-release
        OS=$DISTRIB_ID
        VER=$DISTRIB_RELEASE
    elif [ -f /etc/debian_version ]; then
        # Older Debian/Ubuntu/etc.
        OS=Debian
        VER=$(cat /etc/debian_version)
    else
        # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    echo "Detected OS $OS $VER"
    curl -V
    python -V

}


download_docker() {
    case $OS in
    Debian*)
        DOCKER_FILE_NAME=docker-debian-stretch.tgz
        ;;
    Ubuntu)
        DOCKER_FILE_NAME=docker-ubuntu-bionic.tgz
        ;;
    CentOS*)
        DOCKER_FILE_NAME=docker-centos-7.tgz
        ;;
    *)
        echo "Unsupported host OS: $OS"
        exit 1
        ;;
    esac

    if [ ! -f "$DOCKER_FILE_NAME" ] ; then
        echo "Download docker $BASE_URL/terraform/$DOCKER_FILE_NAME"
        curl --fail -k "$BASE_URL/terraform/$DOCKER_FILE_NAME" -o "$DOCKER_FILE_NAME"
    else
        echo "File $DOCKER_FILE_NAME present"
    fi
}


download_weave() {
    if [ ! -f "$WEAVE_FILE_NAME" ] ; then
        echo "Download weave $BASE_URL/terraform/$WEAVE_FILE_NAME"
        curl --fail -k "$BASE_URL/terraform/$WEAVE_FILE_NAME" -o "$WEAVE_FILE_NAME"
    else
        echo "File $WEAVE_FILE_NAME present"
    fi
}


download_site() {
    if [ ! -f "$SITE_FILE_NAME" ] ; then
        echo "Download domain $BASE_URL/sites/$SITE_FILE_NAME"
        curl --fail -k "$BASE_URL/sites/$SITE_FILE_NAME" -o "$SITE_FILE_NAME"
    else
        echo "File $SITE_FILE_NAME present"
    fi
}


install_docker() {

    echo "Install docker"
    TEMP_DIR=/tmp/ekatra/docker
    mkdir -p "$TEMP_DIR"
    tar -x --directory="$TEMP_DIR" -zf "$DOCKER_FILE_NAME"

    ######
    if ls $TEMP_DIR/*.crt 1> /dev/null 2>&1;  then
        echo "Install certificat"
        case $OS in
        Debian*|Ubuntu)
            sudo cp $TEMP_DIR/*.crt /usr/local/share/ca-certificates/
            sudo update-ca-certificates
            ;;
        CentOS*)
            sudo update-ca-trust enable
            sudo cp $TEMP_DIR/*.crt /etc/pki/ca-trust/source/anchors/
            sudo update-ca-trust extract
            ;;
        *)
            echo "Unsupported host OS: $OS"
            exit 1
            ;;
        esac
    fi

    ###### Enable live restore
    sudo mkdir -p "/etc/docker"
    bash -c 'echo -e "{\n\"live-restore\": true\n}" | sudo tee /etc/docker/daemon.json > /dev/null'

    ######
    case $OS in
    Debian*|Ubuntu)
        sudo dpkg -i $TEMP_DIR/*.deb
        ;;
    CentOS*)
        sudo yum localinstall -y --nogpgcheck $TEMP_DIR/*.rpm
        ;;
    *)
        echo "Unsupported host OS: $OS"
        exit 1
        ;;
    esac

    ######
    if [ -f "$TEMP_DIR/docker-volume-local-persist" ] &&
       [ ! -f "/usr/bin/docker-volume-local-persist" ] ; then
        sudo cp "$TEMP_DIR/docker-volume-local-persist" "/usr/bin/"
        sudo cp "$TEMP_DIR/docker-volume-local-persist.service" "/etc/systemd/system/"
        sudo chmod +x /usr/bin/docker-volume-local-persist
        sudo systemctl daemon-reload
        sudo systemctl enable docker-volume-local-persist
        sudo systemctl start docker-volume-local-persist
    fi

    rm -r "$TEMP_DIR"
}


install_weave() {
    echo "Install weave"
    sudo docker load -i $WEAVE_FILE_NAME
    sudo tar -x --directory=/usr/local/bin -zf "$WEAVE_FILE_NAME" weave
    sudo chmod +x /usr/local/bin/weave
}


install_crt() {
    CERT_DIR="$INSTALL_DIR/.certs"
    if [ -f "$CERT_FILE_NAME" ] ; then
        echo "File $CERT_FILE_NAME present"
        echo "Install Domain certificates from $CERT_FILE_NAME"
        sudo mkdir -p "$CERT_DIR"
        sudo tar -x --directory="$CERT_DIR" -zf "$CERT_FILE_NAME"

        ######
        sudo find "$CERT_DIR" -depth -name "*.cer" -exec sh -c 'mv "$1" "${1%.cer}.crt"' _ {} \;
        if ls $CERT_DIR/*CA*.crt 1> /dev/null 2>&1;  then
            case $OS in
            Debian*|Ubuntu)
                sudo cp $CERT_DIR/*CA*.crt /usr/local/share/ca-certificates/
                sudo update-ca-certificates
                ;;
            CentOS*)
                sudo update-ca-trust enable
                sudo cp $CERT_DIR/*CA*.crt /etc/pki/ca-trust/source/anchors/
                sudo update-ca-trust extract
                ;;
            *)
                echo "Unsupported host OS: $OS"
                exit 1
                ;;
            esac
        fi
    else
        echo "Domain certificates $CERT_FILE_NAME not present."
    fi
}


install_site() {

    if [ -d "$INSTALL_DIR" ] && [ "$(ls -A $INSTALL_DIR | grep -v .certs)" ]; then
        echo "Installation aborted. $INSTALL_DIR is not Empty"
        exit 1
    fi

    if [ -f "$SITE_FILE_NAME" ] ; then
        sudo mkdir -p "$INSTALL_DIR"
        sudo tar -x --directory="$INSTALL_DIR" -zf "$SITE_FILE_NAME"
    else
        echo "File not found $SITE_FILE_NAME"
        exit 1
    fi

    if [ -f "$INSTALL_DIR/.install/setup.sh" ] ; then
        cd "$INSTALL_DIR/.install/"
        sudo "./setup.sh"
    fi
}


upgrade_site() {
    TEMP_INSTALL_DIR=/tmp/ekatra/upgrade
    if [ -f "$SITE_FILE_NAME" ] ; then
        sudo mkdir -p "$TEMP_INSTALL_DIR"
        sudo tar -x --directory="$TEMP_INSTALL_DIR" -zf "$SITE_FILE_NAME"
    else
        echo "File not found $SITE_FILE_NAME"
        exit 1
    fi

    if [ -f "$TEMP_INSTALL_DIR/.install/upgrade.sh" ] ; then
        cd "$TEMP_INSTALL_DIR/.install/"
        sudo "./upgrade.sh"
    fi
}


changelog() {
    if [ -f "$SITE_FILE_NAME" ] ; then
        tar -xOzf $SITE_FILE_NAME --to-stdout --wildcards './**/CHANGELOG*.md' | more
    fi
}


######################################################################
# main
######################################################################

# Handle special case $1 commands that run locally at the client end
case "$1" in
    help|--help)
        usage
        exit 0
        ;;
    version|--version)
        echo "$SCRIPT_VERSION"
        exit 0
        ;;
    changelog)
        download_site
        changelog
        exit 0
        ;;
    setup)
        gather_facts
        download_docker
        download_weave
        download_site
        install_docker
        install_weave
        install_crt
        install_site
        ;;
    upgrade)
        gather_facts
        download_site
        install_crt
        upgrade_site
        ;;
    download)
        gather_facts
        download_docker
        download_weave
        download_site
        ;;
    *)
        usage
        exit 1
        ;;
esac
