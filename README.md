# pulse
docker pull postgres:15.18-bookworm

docker run --name pulse -p 5432:5432 -e POSTGRES_PASSWORD=secret -d postgres:15.18-bookworm
or 
docker run --name pulse -p 5432:5432 --env-file .env -d postgres:15.18-bookworm

docker exec -ti pulse createdb -U postgres pulse_db