.PHONY: up down restart ps logs clean setup build context

# Переменные
COMPOSE = docker-compose
CONNECTOR_URL_ICEBERG = https://github.com/databricks/iceberg-kafka-connect/releases/download/v0.6.19/iceberg-kafka-connect-runtime-hive-0.6.19.zip


# Запуск всех сервисов
up:
	$(COMPOSE) up -d

# Остановка всех сервисов
down:
	$(COMPOSE) down

# Перезапуск всех сервисов
restart:
	$(COMPOSE) restart

# Статус сервисов
ps:
	$(COMPOSE) ps

# Просмотр логов
logs:
	$(COMPOSE) logs -f

# Очистка всех данных
clean:
	$(COMPOSE) down -v
	rm -rf connectors/*
	rm -rf .terraform
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate*
	rm -f crash.log

# Установка коннектора и запуск инфраструктуры
setup:
	@echo "Downloading connector..."
	@mkdir -p connectors
	@curl -L $(CONNECTOR_URL_ICEBERG) -o connector_iceberg.zip
	@unzip -o connector_iceberg.zip -d connectors/
	@rm connector_iceberg.zip

context:
	@kcctl config set-context local --cluster http://localhost:8083

# Помощь
help:
	@echo "Available commands:"
	@echo "  make up        - Start all services"
	@echo "  make down      - Stop all services"
	@echo "  make restart   - Restart all services"
	@echo "  make ps        - Show service status"
	@echo "  make logs      - View logs"
	@echo "  make clean     - Remove all data"
	@echo "  make setup     - Download connector and start services" 
