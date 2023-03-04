PATH_ROOT="/opt"
PATH_TROJAN="${PATH_ROOT}/trojan"
PATH_CERT="${PATH_TROJAN}/certificates"
INSTALL_CMD="apt"

init() {
    read -p "Input domain name: " domain_name
    read -p "Set trojan password: " password
    ${INSTALL_CMD} update
    ${INSTALL_CMD} install -y vim curl wget unzip git socat nginx
}

get_cert() {
    mkdir -p ${PATH_CERT}
    curl https://get.acme.sh | sh -s email=acme.sh@example.com
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    ~/.acme.sh/acme.sh --issue --standalone -d ${domain_name} --pre-hook "systemctl stop nginx" --post-hook "systemctl restart nginx"
    ~/.acme.sh/acme.sh --install-cert -d ${domain_name} --key-file ${PATH_CERT}/${domain_name}.key --fullchain-file ${PATH_CERT}/${domain_name}.pem
}

install_trojan_go() {
    wget -P ${PATH_TROJAN} https://github.com/p4gefau1t/trojan-go/releases/download/v0.10.6/trojan-go-linux-amd64.zip
    unzip -d ${PATH_TROJAN} ${PATH_TROJAN}/trojan-go-linux-amd64.zip
    rm ${PATH_TROJAN}/trojan-go-linux-amd64.zip
    cat > ${PATH_TROJAN}/config.json << EOF
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": 443,
    "remote_addr": "127.0.0.1",
    "remote_port": 9123,
    "password": [
        "${password}"
    ],
    "ssl": {
        "cert": "${PATH_CERT}/${domain_name}.pem",
        "key": "${PATH_CERT}/${domain_name}.key"
    }
}
EOF
}

get_fake_page() {
    git clone https://github.com/vhbo/fake-nextcloud.git ${PATH_TROJAN}/fake-nextcloud
}

configure_nginx() {
    cat > /etc/nginx/conf.d/trojan-go.conf << EOF
server {
    listen 9123;
    server_name _;
    root ${PATH_TROJAN}/fake-nextcloud;
    index index.html;
}
EOF
    nginx -s reload
}

launch() {
    nohup ${PATH_TROJAN}/trojan-go -config ${PATH_TROJAN}/config.json >/dev/null 2>&1 &
}

main() {
    init
    get_cert
    install_trojan_go
    get_fake_page
    configure_nginx
    launch
}

main
