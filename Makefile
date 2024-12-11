
default:: deploy logs

deploy::
	docker compose up -d

logs:: deploy
	docker compose logs clients -f

load-generator::
	cd ./load_generator && make docker


txns:: load-generator
	$(eval tps ?= 1)
	$(eval duration ?= 300)
	$(eval size ?= 16)
	docker run \
		--rm \
		-t \
		--network 1e6_default \
		electricsql/load-generator:latest \
		--db "postgresql://postgres:password@postgres:5432/electric" \
		-c "value:text:$(size)" \
		--tps "$(tps)" \
		--duration "$(duration)"

clients:: client-docker
	$(eval count ?= "1000")
	$(eval electric ?= "http://localhost:8888")
	count=$(count) electric=$(electric) docker run \
		--rm \
		-t \
		--network host \
    -e DATABASE_URL="postgresql://postgres:password@localhost:5555/electric?sslmode=disable" \
		-e ELECTRIC_URL="${electric}" \
		-e CLIENT_COUNT="${count}" \
    -e CLIENT_WAIT="5" \
		electricsql/client-load:latest

client-docker::
	cd ./client_load && make docker

stop::
	docker compose down --volumes
