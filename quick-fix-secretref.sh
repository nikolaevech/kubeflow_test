#!/bin/bash

# Быстрое исправление secretKeyRef namespace проблемы
# Простая и надежная версия без сложной логики

set -e

echo "╔════════════════════════════════════════════════════════╗"
echo "║   Quick SecretKeyRef Namespace Fixer                  ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Создаем backup
BACKUP_DIR="backups/quick-fix-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
echo "✓ Backup: $BACKUP_DIR"
echo ""

# Список файлов для проверки
FILES_TO_CHECK=(
    "02-kubeflow-pipelines/kubeflow-all.yaml"
    "04-katib/katib-all.yaml"
    "05-jupyterlab/jupyter-all.yaml"
)

FIXED_COUNT=0

for file in "${FILES_TO_CHECK[@]}"; do
    if [ ! -f "$file" ]; then
        echo "⊘ $file - не найден, пропускаем"
        continue
    fi
    
    # Проверяем, есть ли проблема
    if ! grep -q "namespace: ml-infrastructure" "$file"; then
        echo "✓ $file - проблем нет"
        continue
    fi
    
    # Проверяем, связана ли проблема с secretKeyRef
    if ! grep -B3 "namespace: ml-infrastructure" "$file" | grep -q "secretKeyRef:"; then
        echo "✓ $file - namespace используется корректно"
        continue
    fi
    
    echo "→ $file - исправляем..."
    
    # Создаем backup
    cp "$file" "$BACKUP_DIR/$(basename $file).backup"
    
    # Исправляем файл с помощью awk
    awk '
    BEGIN { in_secret = 0; }
    {
        if (/secretKeyRef:/) {
            in_secret = 1;
            print;
            next;
        }
        
        if (in_secret && /^[[:space:]]+namespace:[[:space:]]+ml-infrastructure[[:space:]]*$/) {
            in_secret = 0;
            next;
        }
        
        if (in_secret && /^[[:space:]]+key:/) {
            in_secret = 0;
        }
        
        print;
    }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
    
    echo "  ✓ Исправлено"
    ((FIXED_COUNT++))
done

echo ""
echo "═══════════════════════════════════════════════════════"
echo ""

if [ $FIXED_COUNT -gt 0 ]; then
    echo "✅ Исправлено файлов: $FIXED_COUNT"
    echo ""
    echo "📁 Backup сохранен в: $BACKUP_DIR"
    echo ""
    echo "🔍 Проверка с kubectl:"
    
    if command -v kubectl >/dev/null 2>&1; then
        echo ""
        VALIDATION_OK=true
        
        for file in "${FILES_TO_CHECK[@]}"; do
            if [ -f "$file" ]; then
                echo -n "  Проверка $file ... "
                if kubectl apply --dry-run=client -f "$file" >/dev/null 2>&1; then
                    echo "✓"
                else
                    echo "✗"
                    VALIDATION_OK=false
                fi
            fi
        done
        
        echo ""
        
        if [ "$VALIDATION_OK" = true ]; then
            echo "✅ Все файлы валидны!"
        else
            echo "⚠️  Некоторые файлы имеют ошибки"
            echo ""
            echo "Откатить изменения:"
            echo "  for f in $BACKUP_DIR/*.backup; do"
            echo "    cp \"\$f\" \"\${f%.backup}\""
            echo "  done"
            exit 1
        fi
    else
        echo "  kubectl не найден, пропускаем валидацию"
    fi
    
    echo ""
    echo "🚀 Следующие шаги:"
    echo "   make deploy"
    echo ""
else
    echo "✨ Все файлы уже исправлены!"
fi

echo "═══════════════════════════════════════════════════════"