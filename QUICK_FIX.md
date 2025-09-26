# ⚡ Быстрое исправление - 3 команды

## Проблема

Kubeflow не деплоится из-за ошибок в манифестах.

## Решение за 3 шага

### 1️⃣ Исправить все проблемы

```bash
chmod +x fix-all-issues.sh
./fix-all-issues.sh
```

### 2️⃣ Проверить исправления

```bash
chmod +x verify-fixes.sh
./verify-fixes.sh
```

### 3️⃣ Развернуть Kubeflow

```bash
make reset
```

---

## Что было исправлено?

✅ **Убрано `namespace` из secretKeyRef** (Kubernetes не поддерживает)

✅ **Исправлены MySQL probes** (правильная подстановка переменных)

✅ **Улучшен скрипт ожидания MySQL** (больше попыток, лучшая логика)

✅ **Обновлен deploy скрипт** (интеграция с wait-mysql.sh)

✅ **Проверены все YAML файлы** (валидация синтаксиса)

---

## Если что-то пошло не так

### MySQL не стартует

```bash
kubectl delete -f 01-infrastructure/mysql/
kubectl apply -f 01-infrastructure/mysql/
kubectl logs -f deployment/mysql -n ml-infrastructure
```

### Kubeflow Pipelines падает

```bash
kubectl get secrets -n kubeflow
# Если нет секретов:
kubectl get secret minio-secret -n ml-infrastructure -o yaml | \
  sed 's/namespace: ml-infrastructure/namespace: kubeflow/' | \
  kubectl apply -f -
```

### Проверить все поды

```bash
kubectl get pods -A
```

---

## Резервные копии

Все оригиналы сохранены в:

```
backups/comprehensive-fix-TIMESTAMP/
```

### Откатиться назад

```bash
# Посмотреть доступные бэкапы
ls -la backups/

# Восстановить
cp backups/comprehensive-fix-*/FILE.backup ORIGINAL_PATH
```

---

## Полная документация

📖 **Подробная информация:** [FIXES_README.md](https://claude.ai/chat/FIXES_README.md)

📖 **Основной README:** [README.md](https://claude.ai/chat/README.md)

---

**Время исправления:** ~2 минуты

**Время развертывания:** ~10-15 минут
