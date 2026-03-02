echo "https://docs.rw/docs/install/remnawave-node"

apt install sudo

sudo curl -fsSL https://get.docker.com | sh

mkdir /opt/remnanode && cd /opt/remnanode

cd /opt/remnanode && nano docker-compose.yml

echo "panel -> manage nodes -> copy docker-compose.yaml"

docker compose up -d && docker compose logs -f -t
