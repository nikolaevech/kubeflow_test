.PHONY: help check install start deploy stop clean uninstall logs port-forward dashboard

# Цвета для вывода
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m

help: ## Показать справку
	@echo "$(BLUE)Kubeflow Platform - Доступные команды:$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""

check: ## Проверить установленные зависимости
	@echo "$(BLUE)Проверка зависимостей...$(NC)"
	@chmod +x check-prerequisites.sh
	@./check-prerequisites.sh

install: ## Установить все зависимости (Docker, kubectl, Minikube)
	@echo "$(BLUE)Установка зависимостей...$(NC)"
	@chmod +x install-prerequisites.sh
	@./install-prerequisites.sh

quick-start: ## 🚀 Быстрый старт (установка + развертывание)
	@echo "$(BLUE)Быстрый старт Kubeflow Platform...$(NC)"
	@chmod +x quickstart.sh
	@./quickstart.sh

start: ## Запустить Minikube кластер
	@echo "$(BLUE)Запуск Minikube...$(NC)"
	@chmod +x 00-prerequisites/minikube-setup.sh
	@./00-prerequisites/minikube-setup.sh || { \
		echo "$(YELLOW)⚠️  Minikube setup completed with warnings$(NC)"; \
		echo "Checking if cluster is accessible..."; \
		if kubectl get nodes >/dev/null 2>&1; then \
			echo "$(GREEN)✓ Kubernetes cluster is running$(NC)"; \
			echo "$(GREEN)✓ You can proceed with deployment$(NC)"; \
			exit 0; \
		else \
			echo "$(RED)✗ Cannot access Kubernetes cluster$(NC)"; \
			exit 1; \
		fi \
	}

deploy: ## Развернуть все компоненты Kubeflow
	@echo "$(BLUE)Развертывание Kubeflow...$(NC)"
	@chmod +x scripts/deploy-all.sh
	@./scripts/deploy-all.sh

stop: ## Остановить Minikube (данные сохраняются)
	@echo "$(YELLOW)Остановка Minikube...$(NC)"
	@minikube stop

clean: ## Удалить все компоненты Kubeflow (Minikube остается)
	@echo "$(YELLOW)Удаление компонентов Kubeflow...$(NC)"
	@chmod +x scripts/uninstall.sh
	@./scripts/uninstall.sh

uninstall: ## Полное удаление (включая Minikube кластер)
	@echo "$(YELLOW)Полное удаление Kubeflow и Minikube...$(NC)"
	@chmod +x scripts/uninstall.sh
	@./scripts/uninstall.sh
	@minikube delete

port-forward: ## Настроить port forwarding для localhost
	@echo "$(BLUE)Настройка port forwarding...$(NC)"
	@chmod +x scripts/port-forward.sh
	@./scripts/port-forward.sh

dashboard: ## Открыть Kubernetes Dashboard
	@echo "$(BLUE)Открытие Kubernetes Dashboard...$(NC)"
	@minikube dashboard

logs: ## Показать логи всех компонентов
	@echo "$(BLUE)Логи Kubeflow компонентов:$(NC)"
	@echo ""
	@echo "$(GREEN)=== ML Pipeline ===$(NC)"
	@kubectl logs -l app=ml-pipeline -n kubeflow --tail=20
	@echo ""
	@echo "$(GREEN)=== Katib Controller ===$(NC)"
	@kubectl logs -l app=katib-controller -n kubeflow --tail=20
	@echo ""
	@echo "$(GREEN)=== JupyterLab ===$(NC)"
	@kubectl logs -l app=jupyterlab -n kubeflow-user --tail=20

status: ## Показать статус всех подов
	@echo "$(BLUE)Статус компонентов:$(NC)"
	@echo ""
	@kubectl get pods -A

events: ## Показать последние события кластера
	@echo "$(BLUE)События кластера:$(NC)"
	@kubectl get events -A --sort-by='.lastTimestamp' | tail -20

urls: ## Показать все URL для доступа
	@echo "$(BLUE)URL для доступа:$(NC)"
	@echo ""
	@MINIKUBE_IP=$$(minikube ip); \
	echo "$(GREEN)Dashboard:$(NC)     http://$$MINIKUBE_IP:30080"; \
	echo "$(GREEN)Pipelines:$(NC)     http://$$MINIKUBE_IP:30888"; \
	echo "$(GREEN)Katib:$(NC)         http://$$MINIKUBE_IP:30777"; \
	echo "$(GREEN)JupyterLab:$(NC)    http://$$MINIKUBE_IP:30666"; \
	echo "$(GREEN)MinIO Console:$(NC) http://$$MINIKUBE_IP:30900"

shell-minio: ## Shell в MinIO pod
	@kubectl exec -it deployment/minio -n ml-infrastructure -- sh

shell-mysql: ## Shell в MySQL pod
	@kubectl exec -it deployment/mysql -n ml-infrastructure -- mysql -uroot -prootpass123

shell-jupyter: ## Shell в JupyterLab pod
	@kubectl exec -it deployment/jupyterlab -n kubeflow-user -- bash

restart-all: ## Перезапустить все deployments
	@echo "$(YELLOW)Перезапуск всех deployments...$(NC)"
	@kubectl rollout restart deployment -n kubeflow
	@kubectl rollout restart deployment -n kubeflow-user
	@kubectl rollout restart deployment -n ml-infrastructure

watch: ## Наблюдать за статусом подов в реальном времени
	@watch -n 2 kubectl get pods -A

test-pipeline: ## Создать тестовый pipeline
	@echo "$(BLUE)Создание тестового pipeline...$(NC)"
	@kubectl apply -f - <<EOF
	apiVersion: argoproj.io/v1alpha1
	kind: Workflow
	metadata:
	  generateName: test-pipeline-
	  namespace: kubeflow
	spec:
	  entrypoint: main
	  templates:
	  - name: main
	    container:
	      image: alpine:latest
	      command: [sh, -c]
	      args: ["echo 'Hello from Kubeflow Pipeline!'"]
	EOF
	@echo "$(GREEN)Тестовый pipeline создан!$(NC)"

backup: ## Создать backup текущего состояния
	@echo "$(BLUE)Создание backup...$(NC)"
	@mkdir -p backups
	@kubectl get all -A -o yaml > backups/kubeflow-backup-$$(date +%Y%m%d-%H%M%S).yaml
	@echo "$(GREEN)Backup создан в директории backups/$(NC)"

info: ## Показать информацию о кластере
	@echo "$(BLUE)Информация о кластере:$(NC)"
	@echo ""
	@echo "$(GREEN)Minikube:$(NC)"
	@minikube status
	@echo ""
	@echo "$(GREEN)Kubernetes:$(NC)"
	@kubectl version --short
	@echo ""
	@echo "$(GREEN)Nodes:$(NC)"
	@kubectl get nodes
	@echo ""
	@echo "$(GREEN)Namespaces:$(NC)"
	@kubectl get namespaces

# Алиасы для частых команд
up: quick-start ## Алиас для quick-start
down: stop ## Алиас для stop
reset: uninstall start deploy ## Полный сброс и переустановка