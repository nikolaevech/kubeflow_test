#!/bin/bash

# Universal SecretKeyRef Namespace Fixer
# Автоматически находит и исправляет все файлы с проблемой namespace в secretKeyRef

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[⚠]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_step() { echo -e "${CYAN}▶${NC} $1"; }

cat << "EOF"
╔════════════════════════════════════════════════════════╗
║   Universal SecretKeyRef Namespace Fixer              ║
║   Исправляет все YAML файлы автоматически             ║
╚════════════════════════════════════════════════════════╝
EOF

echo ""

# Создаем backup
BACKUP_DIR="backups/secretref-fix-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
log_info "Backup directory: $BACKUP_DIR"
echo ""

# Функция для поиска всех YAML файлов с проблемой
find_problematic_files() {
    log_step "Сканирование файлов..."
    
    FILES=($(find . -type f \( -name "*.yaml" -o -name "*.yml" \) \
        ! -path "./backups/*" \
        ! -path "./.git/*" \
        -exec grep -l "namespace: ml-infrastructure" {} \;))
    
    PROBLEMATIC=()
    
    for file in "${FILES[@]}"; do
        # Проверяем, есть ли проблема с secretKeyRef
        if grep -B3 "namespace: ml-infrastructure" "$file" | grep -q "secretKeyRef:"; then
            PROBLEMATIC+=("$file")
        fi
    done
    
    echo "${PROBLEMATIC[@]}"
}

# Функция для исправления файла
fix_file() {
    local file=$1
    local basename=$(basename "$file")
    
    log_info "Обработка: $file"
    
    # Backup
    cp "$file" "$BACKUP_DIR/$basename.backup"
    
    # Подсчитываем проблемы ДО исправления
    local count_before=$(grep -c "namespace: ml-infrastructure" "$file" 2>/dev/null || echo "0")
    
    # Используем AWK для точного удаления
    awk '
    BEGIN { in_secret = 0; }
    {
        # Определяем начало secretKeyRef блока
        if (/secretKeyRef:/) {
            in_secret = 1;
            print;
            next;
        }
        
        # Если мы в secretKeyRef и видим namespace - пропускаем
        if (in_secret && /^[[:space:]]+namespace:[[:space:]]+ml-infrastructure[[:space:]]*$/) {
            in_secret = 0;
            next;
        }
        
        # Выходим из secretKeyRef при встрече key:
        if (in_secret && /^[[:space:]]+key:/) {
            in_secret = 0;
        }
        
        # Печатаем все остальные строки
        print;
    }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
    
    # Подсчитываем ДО исправления (из backup)
    local count_after=$(grep -c "namespace: ml-infrastructure" "$file" 2>/dev/null || echo "0")
    local removed=$((count_before - count_after))
    
    if [ $removed -gt 0 ]; then
        log_success "  Удалено $removed проблемных строк"
        return 0
    else
        log_info "  Проблем не обнаружено"
        return 1
    fi
}

# Валидация YAML
validate_yaml() {
    local file=$1
    
    if command -v kubectl >/dev/null 2>&1; then
        if kubectl apply --dry-run=client -f "$file" >/dev/null 2>&1; then
            log_success "  Валидация: OK"
            return 0
        else
            log_error "  Валидация: FAILED"
            kubectl apply --dry-run=client -f "$file" 2>&1 | head -3 | sed 's/^/    /'
            return 1
        fi
    else
        log_warning "  kubectl не найден, пропускаем валидацию"
        return 0
    fi
}

# Главная логика
main() {
    # Находим все проблемные файлы
    PROBLEM_FILES=($(find_problematic_files))
    
    if [ ${#PROBLEM_FILES[@]} -eq 0 ]; then
        log_success "Проблемных файлов не найдено! ✨"
        exit 0
    fi
    
    echo ""
    log_step "Найдено проблемных файлов: ${#PROBLEM_FILES[@]}"
    echo ""
    
    for file in "${PROBLEM_FILES[@]}"; do
        echo "─────────────────────────────────────────────"
        fix_file "$file"
        echo ""
    done
    
    echo "═════════════════════════════════════════════"
    echo ""
    log_step "Валидация исправленных файлов..."
    echo ""
    
    VALIDATION_FAILED=0
    for file in "${PROBLEM_FILES[@]}"; do
        if ! validate_yaml "$file"; then
            VALIDATION_FAILED=1
        fi
    done
    
    echo ""
    echo "═════════════════════════════════════════════"
    echo ""
    
    if [ $VALIDATION_FAILED -eq 0 ]; then
        cat << EOF
╔════════════════════════════════════════════════════════╗
║              ✅ ВСЕ ИСПРАВЛЕНО! ✅                     ║
╚════════════════════════════════════════════════════════╝

📁 Backup: $BACKUP_DIR

📋 Исправлено файлов: ${#PROBLEM_FILES[@]}

📝 Файлы:
EOF
        for file in "${PROBLEM_FILES[@]}"; do
            echo "   • $file"
        done
        
        echo ""
        echo "🚀 Следующие шаги:"
        echo "   1. Проверьте изменения: git diff"
        echo "   2. Разверните: make deploy"
        echo "   3. Или: ./scripts/deploy-all.sh"
        echo ""
        
    else
        log_error "Некоторые файлы не прошли валидацию!"
        echo ""
        echo "Восстановить из backup:"
        echo "  cp $BACKUP_DIR/*.backup <original-path>"
        exit 1
    fi
}

# Опция для отката
if [ "$1" = "--rollback" ]; then
    if [ -z "$2" ]; then
        log_error "Укажите директорию backup: $0 --rollback backups/xxx"
        exit 1
    fi
    
    BACKUP_TO_RESTORE=$2
    
    if [ ! -d "$BACKUP_TO_RESTORE" ]; then
        log_error "Backup не найден: $BACKUP_TO_RESTORE"
        exit 1
    fi
    
    log_info "Восстановление из: $BACKUP_TO_RESTORE"
    
    for backup in "$BACKUP_TO_RESTORE"/*.backup; do
        if [ -f "$backup" ]; then
            original=$(basename "$backup" .backup)
            # Ищем оригинальный файл
            original_path=$(find . -name "$original" ! -path "./backups/*" | head -1)
            
            if [ -n "$original_path" ]; then
                cp "$backup" "$original_path"
                log_success "Восстановлен: $original_path"
            else
                log_warning "Не найден оригинал для: $original"
            fi
        fi
    done
    
    log_success "Откат завершен!"
    exit 0
fi

# Запускаем основную логику
main