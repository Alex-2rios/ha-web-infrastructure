.DEFAULT_GOAL := help
.PHONY: help up down restart logs test load validate clean

help:
	@echo "up        bring the stack up, generating a certificate if needed"
	@echo "down      stop everything"
	@echo "restart   recreate the containers"
	@echo "logs      follow the logs of every service"
	@echo "test      run the failover drill"
	@echo "load      run the load test and show the status code split"
	@echo "validate  check the nginx and haproxy configuration"
	@echo "clean     stop everything and remove the volumes and certificates"

up:
	./scripts/bootstrap.sh

down:
	docker compose down

restart:
	docker compose up -d --force-recreate

logs:
	docker compose logs -f

test:
	./scripts/failover-test.sh

load:
	./scripts/load-test.sh

validate:
	docker compose config -q
	docker compose exec -T edge nginx -t
	docker compose exec -T balancer haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg

clean:
	docker compose down -v
	rm -f certs/server.crt certs/server.key docs/last-run.log
