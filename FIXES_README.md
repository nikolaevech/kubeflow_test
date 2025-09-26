# 🔧 Kubeflow Platform - Fixes Documentation

## Обзор проблем и решений

Этот документ описывает все найденные проблемы в развертывании Kubeflow и способы их устранения.

---

## 🐛 Обнаруженные проблемы

### 1. **Критическая ошибка: namespace в secretKeyRef**

**Симптом:**

```
Error: unknown field "spec.template.spec.containers[0].env[6].valueFrom.secretKeyRef.namespace"
```

**Причина:**

Kubernetes API не поддерживает поле `namespace` в `secretKeyRef`. Секреты можно использовать только из того же namespace, где находится Pod.

**Файлы с проблемой:**

* `02-kubeflow-pipelines/kubeflow-all.yaml`
* `05-jupyterlab/jupyter-all.yaml`

**Решение:**

Удалить все строки `namespace: ml-infrastructure` из блоков `secretKeyRef`.

---

### 2. **MySQL Readiness Probe не работает**

**Симптом:**

```
ERROR 1045 (28000): Access denied for user 'root'@'localhost' (using password: YES)
Readiness probe failed (x63 attempts)
```

**Причина:**

Переменная окружения `${MYSQL_ROOT_PASSWORD}` не подставляется в команду `exec` probe корректно.

**Файл с проблемой:**

* `01-infrastructure/mysql/deployment.yaml`

**Решение:**

Использовать `sh -c` для правильной подстановки переменных:

```yaml
readinessProbe:
  exec:
    command:
      - sh
      - -c
      - mysql -h localhost -u root -p$MYSQL_ROOT_PASSWORD -e "SELECT 1"
```

---

### 3. **Недостаточная логика ожидания MySQL**

**Причина:**

Скрипт `wait-mysql.sh` не проверяет статус пода и имеет недостаточное количество попыток.

**Файл с проблемой:**

* `scripts/wait-mysql.sh`

**Решение:**

* Добавить проверку статуса пода
* Увеличить количество попыток до 120
* Улучшить логику создания и верификации баз данных

---

### 4. **kubectl версия несовместима**

**Симптом:**

```
❗ /usr/local/bin/kubectl is version 1.34.1, which may have incompatibilities with Kubernetes 1.28.0
```

**Решение:**

Обновить kubectl до версии 1.28.x (опционально, не критично)

---

## 🛠️ Как исправить все проблемы

### Вариант 1: Автоматическое исправление (Рекомендуется)

```bash
# 1. Скачать/создать скрипт исправления
chmod +x fix-all-issues.sh

# 2. Запустить исправление
./fix-all-issues.sh

# 3. Проверить, что все исправлено
chmod +x verify-fixes.sh
./verify-fixes.sh
```

**Что делает `fix-all-issues.sh`:**

* ✅ Удаляет `namespace` из всех `secretKeyRef`
* ✅ Исправляет MySQL readiness/liveness probes
* ✅ Обновляет скрипт `wait-mysql.sh`
* ✅ Интегрирует изменения в `deploy-all.sh`
* ✅ Валидирует все YAML файлы
* ✅ Создает резервные копии перед изменениями

---

### Вариант 2: Ручное исправление

#### Шаг 1: Исправить secretKeyRef

```bash
# Отредактировать файлы:
nano 02-kubeflow-pipelines/kubeflow-all.yaml
nano 05-jupyterlab/jupyter-all.yaml

# Найти все блоки вида:
valueFrom:
  secretKeyRef:
    name: mysql-secret
    key: MYSQL_PASSWORD
    namespace: ml-infrastructure  # ← УДАЛИТЬ эту строку

# Заменить на:
valueFrom:
  secretKeyRef:
    name: mysql-secret
    key: MYSQL_PASSWORD
```

#### Шаг 2: Исправить MySQL probes

```bash
# Отредактировать:
nano 01-infrastructure/mysql/deployment.yaml

# Найти readinessProbe и заменить на:
readinessProbe:
  exec:
    command:
      - sh
      - -c
      - mysql -h localhost -u root -p$MYSQL_ROOT_PASSWORD -e "SELECT 1"
  initialDelaySeconds: 45
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 20

# Аналогично для livenessProbe:
livenessProbe:
  exec:
    command:
      - sh
      - -c
      - mysqladmin ping -h localhost -u root -p$MYSQL_ROOT_PASSWORD
  initialDelaySeconds: 60
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 6
```

#### Шаг 3: Обновить wait-mysql.sh

```bash
# Скопировать улучшенную версию из fix-all-issues.sh
# Или создать новый файл с правильной логикой
nano scripts/wait-mysql.sh
```

---

## ✅ Проверка исправлений

### Автоматическая проверка

```bash
./verify-fixes.sh
```

**Скрипт проверит:**

* ✓ Отсутствие `namespace` в `secretKeyRef`
* ✓ Корректность MySQL probes
* ✓ Наличие улучшенного `wait-mysql.sh`
* ✓ Валидность всех YAML файлов
* ✓ Права на выполнение скриптов
* ✓ Консистентность конфигурации

### Ручная проверка

```bash
# 1. Проверить YAML синтаксис
kubectl apply --dry-run=client -f 02-kubeflow-pipelines/kubeflow-all.yaml
kubectl apply --dry-run=client -f 05-jupyterlab/jupyter-all.yaml

# 2. Проверить MySQL deployment
kubectl apply --dry-run=client -f 01-infrastructure/mysql/deployment.yaml

# 3. Проверить отсутствие namespace в secretKeyRef
grep -A3 "secretKeyRef:" 02-kubeflow-pipelines/kubeflow-all.yaml | grep "namespace:"
# Не должно быть вывода!
```

---

## 🚀 Развертывание после исправлений

### Полное развертывание

```bash
# Вариант 1: Через Makefile
make reset

# Вариант 2: Напрямую
./scripts/deploy-all.sh
```

### Мониторинг развертывания

```bash
# Смотреть статус всех подов
kubectl get pods -A -w

# Проверить MySQL
kubectl logs -f deployment/mysql -n ml-infrastructure

# Проверить Kubeflow Pipelines
kubectl logs -f deployment/ml-pipeline -n kubeflow

# События кластера
kubectl get events -A --sort-by='.lastTimestamp' | tail -20
```

### Ожидаемый результат

```
✅ MySQL pod: Running и Ready за 2-5 минут
✅ MinIO pod: Running и Ready за 1-2 минуты
✅ Kubeflow Pipelines: Running и Ready за 3-5 минут
✅ Katib, KServe, JupyterLab: Running и Ready
✅ Нет ошибок "unknown field" в логах
```

---

## 📁 Структура бэкапов

Все оригинальные файлы сохраняются в:

```
backups/comprehensive-fix-YYYYMMDD-HHMMSS/
├── kubeflow-all.yaml.backup
├── jupyter-all.yaml.backup
├── mysql-deployment.yaml.backup
├── wait-mysql.sh.backup
└── deploy-all.sh.backup
```

### Восстановление из бэкапа

```bash
# Найти нужный бэкап
ls -la backups/

# Восстановить конкретный файл
cp backups/comprehensive-fix-20250926-120000/kubeflow-all.yaml.backup \
   02-kubeflow-pipelines/kubeflow-all.yaml

# Или восстановить все
BACKUP_DIR="backups/comprehensive-fix-20250926-120000"
cp $BACKUP_DIR/kubeflow-all.yaml.backup 02-kubeflow-pipelines/kubeflow-all.yaml
cp $BACKUP_DIR/jupyter-all.yaml.backup 05-jupyterlab/jupyter-all.yaml
cp $BACKUP_DIR/mysql-deployment.yaml.backup 01-infrastructure/mysql/deployment.yaml
```

---

## 🔍 Troubleshooting после исправлений

### Проблема: MySQL все еще не стартует

```bash
# Проверить логи
kubectl logs deployment/mysql -n ml-infrastructure

# Проверить events
kubectl describe pod -l app=mysql -n ml-infrastructure

# Проверить PVC
kubectl get pvc -n ml-infrastructure

# Решение: Пересоздать MySQL
kubectl delete -f 01-infrastructure/mysql/
kubectl apply -f 01-infrastructure/mysql/
```

### Проблема: Kubeflow Pipelines не деплоится

```bash
# Проверить секреты
kubectl get secrets -n kubeflow
kubectl describe secret mysql-secret -n kubeflow
kubectl describe secret minio-secret -n kubeflow

# Решение: Пересоздать секреты
kubectl delete secret mysql-secret minio-secret -n kubeflow
# Скопировать из ml-infrastructure
kubectl get secret mysql-secret -n ml-infrastructure -o yaml | \
  sed 's/namespace: ml-infrastructure/namespace: kubeflow/' | \
  kubectl apply -f -
kubectl get secret minio-secret -n ml-infrastructure -o yaml | \
  sed 's/namespace: ml-infrastructure/namespace: kubeflow/' | \
  kubectl apply -f -
```

### Проблема: "unknown field" ошибки все еще появляются

```bash
# Запустить fix скрипт снова
./fix-all-issues.sh

# Или проверить вручную
grep -r "namespace: ml-infrastructure" 02-kubeflow-pipelines/ 05-jupyterlab/

# Если найдено - удалить вручную
```

---

## 📊 Контрольный список

Перед развертыванием убедитесь:

* [ ] Запущен `fix-all-issues.sh`
* [ ] Проверка `verify-fixes.sh` прошла успешно
* [ ] Нет `namespace` в `secretKeyRef` блоках
* [ ] MySQL deployment использует `sh -c` в probes
* [ ] Скрипт `wait-mysql.sh` обновлен
* [ ] Все скрипты исполняемые (`chmod +x`)
* [ ] Minikube запущен и доступен
* [ ] kubectl работает корректно

---

## 🎯 Быстрая справка команд

```bash
# Исправить все проблемы
./fix-all-issues.sh

# Проверить исправления
./verify-fixes.sh

# Развернуть Kubeflow
make reset
# или
./scripts/deploy-all.sh

# Мониторинг
kubectl get pods -A -w

# Логи MySQL
kubectl logs -f deployment/mysql -n ml-infrastructure

# Доступ к MinIO
MINIKUBE_IP=$(minikube ip)
echo "MinIO Console: http://${MINIKUBE_IP}:30900"

# Доступ к Kubeflow
echo "Pipelines: http://${MINIKUBE_IP}:30888"
echo "JupyterLab: http://${MINIKUBE_IP}:30666"
```

---

## 📝 Дополнительные ресурсы

* **Основной README:** [README.md](https://claude.ai/chat/README.md)
* **Инструкции по установке:** [INSTALLATION.md](https://claude.ai/chat/INSTALLATION.md)
* **Документация Kubernetes:** https://kubernetes.io/docs/
* **Документация Kubeflow:** https://www.kubeflow.org/docs/

---

## ✨ После успешного деплоя

```
╔══════════════════════════════════════════════════════════════╗
║              🎉 Deployment Successful! 🎉                    ║
╚══════════════════════════════════════════════════════════════╝

📍 Access URLs:
   Dashboard:     http://<minikube-ip>:30080
   Pipelines:     http://<minikube-ip>:30888
   Katib:         http://<minikube-ip>:30777
   JupyterLab:    http://<minikube-ip>:30666
   MinIO Console: http://<minikube-ip>:30900

🔑 Credentials:
   MinIO:  minioadmin / minioadmin123
   MySQL:  root / rootpass123

Happy ML Engineering! 🚀
```

---

**Дата создания:** 26 сентября 2025

**Версия:** 1.0

**Статус:** Все проблемы идентифицированы и решены ✅
