mkfile_path := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

.PHONY: docker

docker:
	docker build -t electricsql/client-load:latest .

.PHONY: push

push:
	docker push electricsql/client-load:latest

.PHONY: reset

reset:
	./script/reset.sh

.PHONY: txns

txns:
	# size=.. tps=.. duration=..
	${mkfile_path}/script/generate-metrics

metrics:
	# clients=.. size=.. tps=.. duration=..
	${mkfile_path}/script/generate-metrics

.PHONY: statistics
statistics: metrics
	${mkfile_path}/snapshot-metrics

.PHONY: stats
stats: statistics

load:
