#!/bin/bash

# Quick fix for secret copying issues
set -e

echo "🔧 Исправление проблемы с копированием секретов..."
echo ""

# Function to copy secret safely
copy_secret_safe() {
    local secret_name=$1
    local source_ns=$2
    local target_ns=$3
    
    echo "→ Копирование $secret_name: $source_ns → $target_ns"
    
    # Check if secret exists in source
    if ! kubectl get secret "$secret_name" -n "$source_ns" >/dev/null 2>&1; then
        echo "  ✗ Секрет $secret_name не найден в $source_ns"
        return 1
    fi
    
    # Delete existing secret in target if exists
    if kubectl get secret "$secret_name" -n "$target_ns" >/dev/null 2>&1; then
        echo "  ↺ Удаляем существующий секрет в $target_ns"
        kubectl delete secret "$secret_name" -n "$target_ns" >/dev/null 2>&1
    fi
    
    # Get secret and recreate in target namespace
    kubectl get secret "$secret_name" -n "$source_ns" -o yaml | \
      sed 's/namespace: '$source_ns'/namespace: '$target_ns'/' | \
      sed '/resourceVersion:/d' | \
      sed '/uid:/d' | \
      sed '/creationTimestamp:/d' | \
      sed '/selfLink:/d' | \
      sed '/managedFields:/,/^[^ ]/d' | \
      kubectl create -f - >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "  ✓ Успешно скопирован"
        return 0
    else
        echo "  ✗ Ошибка копирования"
        return 1
    fi
}

# Copy all necessary secrets
echo "Копирование секретов..."
echo ""

copy_secret_safe "minio-secret" "ml-infrastructure" "kubeflow"
copy_secret_safe "mysql-secret" "ml-infrastructure" "kubeflow"
copy_secret_safe "minio-secret" "ml-infrastructure" "kubeflow-user"

echo ""
echo "═══════════════════════════════════════════════════════"
echo ""

# Verify
echo "🔍 Проверка секретов:"
echo ""

check_secret() {
    local secret=$1
    local ns=$2
    
    if kubectl get secret "$secret" -n "$ns" >/dev/null 2>&1; then
        echo "  ✓ $secret в $ns"
    else
        echo "  ✗ $secret в $ns - ОТСУТСТВУЕТ"
    fi
}

check_secret "minio-secret" "ml-infrastructure"
check_secret "mysql-secret" "ml-infrastructure"
check_secret "minio-secret" "kubeflow"
check_secret "mysql-secret" "kubeflow"
check_secret "minio-secret" "kubeflow-user"

echo ""
echo "✅ Секреты исправлены!"
echo ""
echo "Теперь можно продолжить деплой:"
echo "  kubectl apply -f 02-kubeflow-pipelines/"
echo "  kubectl apply -f 04-katib/"
echo "  kubectl apply -f 05-jupyterlab/"
echo ""