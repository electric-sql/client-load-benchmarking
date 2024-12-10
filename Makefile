
.PHONY: default
default: deploy logs

.PHONY: deploy
deploy:
	docker compose up -d

.PHONY: logs
logs: deploy
	docker compose logs clients -f

.PHONY: load-generator
load-generator:
	cd ./load_generator && make docker

tps ?= 1
duration ?= 300
size ?= 16

.PHONY: txns
txns: load-generator
	docker run \
		--rm \
		-t \
		--network 1e6_default \
		electricsql/load-generator:latest \
		--db "postgresql://postgres:password@postgres:5432/electric" \
		-c "value:text:$(size)" \
		--tps "$(tps)" \
		--duration "$(duration)"

.PHONY: stop
stop:
	docker compose down --volumes
