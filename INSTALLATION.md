# 🚀 Installation Guide - Kubeflow Platform

Полное руководство по установке всех необходимых компонентов для запуска Kubeflow на Minikube.

---

## 📋 Содержание

* [Быстрая установка](https://claude.ai/chat/41d62664-e013-4c95-b54c-a6a38b4c21f2#%D0%B1%D1%8B%D1%81%D1%82%D1%80%D0%B0%D1%8F-%D1%83%D1%81%D1%82%D0%B0%D0%BD%D0%BE%D0%B2%D0%BA%D0%B0)
* [Ручная установка](https://claude.ai/chat/41d62664-e013-4c95-b54c-a6a38b4c21f2#%D1%80%D1%83%D1%87%D0%BD%D0%B0%D1%8F-%D1%83%D1%81%D1%82%D0%B0%D0%BD%D0%BE%D0%B2%D0%BA%D0%B0)
* [Системные требования](https://claude.ai/chat/41d62664-e013-4c95-b54c-a6a38b4c21f2#%D1%81%D0%B8%D1%81%D1%82%D0%B5%D0%BC%D0%BD%D1%8B%D0%B5-%D1%82%D1%80%D0%B5%D0%B1%D0%BE%D0%B2%D0%B0%D0%BD%D0%B8%D1%8F)
* [Проверка установки](https://claude.ai/chat/41d62664-e013-4c95-b54c-a6a38b4c21f2#%D0%BF%D1%80%D0%BE%D0%B2%D0%B5%D1%80%D0%BA%D0%B0-%D1%83%D1%81%D1%82%D0%B0%D0%BD%D0%BE%D0%B2%D0%BA%D0%B8)
* [Troubleshooting](https://claude.ai/chat/41d62664-e013-4c95-b54c-a6a38b4c21f2#troubleshooting)

---

## ⚡ Быстрая установка

### Вариант 1: Автоматическая установка (рекомендуется)

```bash
# 1. Проверить текущее состояние
chmod +x check-prerequisites.sh
./check-prerequisites.sh

# 2. Установить недостающие компоненты
chmod +x install-prerequisites.sh
./install-prerequisites.sh

# 3. Запустить Kubeflow
./quickstart.sh
```

### Вариант 2: Все в одной команде

```bash
chmod +x *.sh && ./install-prerequisites.sh && ./quickstart.sh
```

---

## 🛠️ Ручная установка

### macOS

#### 1. Установить Homebrew (если еще не установлен)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

#### 2. Установить Docker Desktop

```bash
# Скачать и установить Docker Desktop
open https://www.docker.com/products/docker-desktop

# Или через Homebrew (если есть)
brew install --cask docker
```

 **После установки** : Запустить Docker Desktop из Applications

#### 3. Установить kubectl

```bash
brew install kubectl

# Проверить версию
kubectl version --client
```

#### 4. Установить Minikube

```bash
brew install minikube

# Проверить версию
minikube version
```

---

### Ubuntu / Debian

#### 1. Установить Docker

```bash
# Удалить старые версии
sudo apt-get remove docker docker-engine docker.io containerd runc

# Установить зависимости
sudo apt-get update
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Добавить Docker GPG ключ
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Добавить репозиторий
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Установить Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Добавить пользователя в группу docker
sudo usermod -aG docker $USER

# Перелогиниться или выполнить
newgrp docker
```

#### 2. Установить kubectl

```bash
# Добавить Kubernetes репозиторий
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | \
    sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
    https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | \
    sudo tee /etc/apt/sources.list.d/kubernetes.list

# Установить kubectl
sudo apt-get update
sudo apt-get install -y kubectl
```

#### 3. Установить Minikube

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64
```

---

### CentOS / RHEL / Fedora

#### 1. Установить Docker

```bash
# Добавить репозиторий
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo

# Установить Docker
sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Запустить и добавить в автозагрузку
sudo systemctl start docker
sudo systemctl enable docker

# Добавить пользователя в группу docker
sudo usermod -aG docker $USER
```

#### 2. Установить kubectl

```bash
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/repodata/repomd.xml.key
EOF

sudo yum install -y kubectl
```

#### 3. Установить Minikube

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64
```

---

### Arch Linux

```bash
# Установить все компоненты
sudo pacman -S docker kubectl minikube

# Запустить Docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
```

---

## 💻 Системные требования

### Минимальные требования

| Компонент | Минимум                        | Рекомендуется |
| ------------------ | ------------------------------------- | -------------------------- |
| **CPU**      | 4 cores                               | 6+ cores                   |
| **RAM**      | 12 GB                                 | 16 GB                      |
| **Disk**     | 50 GB свободного места | 100 GB                     |
| **OS**       | macOS 11+, Ubuntu 20.04+, CentOS 8+   | Latest versions            |

### Поддерживаемые ОС

✅  **macOS** :

* macOS 11 (Big Sur) и выше
* Intel или Apple Silicon (M1/M2)

✅  **Linux** :

* Ubuntu 20.04+, 22.04, 24.04
* Debian 11+
* CentOS 8+, Rocky Linux 8+
* Fedora 36+
* Arch Linux

❌  **Windows** : Используйте WSL2 с Ubuntu

---

## ✅ Проверка установки

### Автоматическая проверка

```bash
./check-prerequisites.sh
```

### Ручная проверка

#### 1. Проверить Docker

```bash
# Версия
docker --version

# Запущен ли Docker
docker ps

# Тестовый контейнер
docker run hello-world
```

#### 2. Проверить kubectl

```bash
kubectl version --client
```

#### 3. Проверить Minikube

```bash
minikube version
```

#### 4. Проверить системные ресурсы

```bash
# CPU cores (Linux)
nproc

# CPU cores (macOS)
sysctl -n hw.ncpu

# RAM (Linux)
free -h

# RAM (macOS)
sysctl hw.memsize

# Disk space
df -h
```

### Ожидаемый результат

```
✓ Docker: Docker version 24.0.7
✓ kubectl: v1.28.4
✓ Minikube: v1.32.0

System Resources:
  CPU Cores: ✓ 8 cores
  RAM: ✓ 16GB
  Free Disk: ✓ 120GB available
```

---

## 🔧 Troubleshooting

### Docker не запускается

**Linux:**

```bash
# Проверить статус
sudo systemctl status docker

# Запустить Docker
sudo systemctl start docker

# Добавить в автозагрузку
sudo systemctl enable docker

# Проверить права
sudo usermod -aG docker $USER
newgrp docker
```

**macOS:**

* Открыть Docker Desktop из Applications
* Проверить, что Docker Desktop запущен в системном трее

### Permission denied при запуске docker

```bash
# Linux: Добавить в группу docker
sudo usermod -aG docker $USER

# Перелогиниться или выполнить
newgrp docker

# Проверить группы
groups
```

### kubectl: command not found

```bash
# Проверить PATH
echo $PATH

# Добавить в PATH (Linux/macOS)
echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bashrc
source ~/.bashrc

# Или переустановить
./install-prerequisites.sh
```

### Minikube не стартует

```bash
# Удалить старый кластер
minikube delete

# Очистить кеш
rm -rf ~/.minikube

# Запустить заново
minikube start --driver=docker --cpus=6 --memory=12g
```

### Недостаточно ресурсов

**Увеличить ресурсы Docker Desktop (macOS):**

1. Docker Desktop → Settings → Resources
2. Увеличить CPUs до 6+
3. Увеличить Memory до 12GB+
4. Apply & Restart

**Linux:** Освободить системную память

```bash
# Очистить кеш
sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'

# Удалить неиспользуемые Docker образы
docker system prune -a
```

### WSL2 (Windows)

```bash
# Установить WSL2 с Ubuntu
wsl --install -d Ubuntu

# В WSL2 терминале выполнить
./install-prerequisites.sh
```

---

## 🚀 После установки

### 1. Запустить Kubeflow

```bash
./quickstart.sh
```

### 2. Или поэтапно

```bash
# Шаг 1: Запустить Minikube
./00-prerequisites/minikube-setup.sh

# Шаг 2: Развернуть все компоненты
./scripts/deploy-all.sh

# Шаг 3: Настроить port forwarding
./scripts/port-forward.sh
```

### 3. Проверить статус

```bash
# Проверить все поды
kubectl get pods -A

# Проверить Minikube
minikube status

# Открыть Kubernetes Dashboard
minikube dashboard
```

---

## 📚 Дополнительные ресурсы

### Официальная документация

* [Docker Documentation](https://docs.docker.com/)
* [kubectl Documentation](https://kubernetes.io/docs/reference/kubectl/)
* [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)
* [Kubeflow Documentation](https://www.kubeflow.org/docs/)

### Полезные команды

```bash
# Проверить версии всех компонентов
docker --version
kubectl version --client
minikube version

# Проверить статус Docker
docker info
docker ps

# Проверить кластер Kubernetes
kubectl cluster-info
kubectl get nodes
kubectl get namespaces

# Логи Minikube
minikube logs

# SSH в Minikube
minikube ssh
```

---

## 🆘 Получение помощи

### Если что-то пошло не так:

1. **Запустите диагностику:**
   ```bash
   ./check-prerequisites.sh
   ```
2. **Проверьте логи:**
   ```bash
   # Docker logs
   journalctl -u docker.service

   # Minikube logs
   minikube logs

   # Kubernetes events
   kubectl get events -A --sort-by='.lastTimestamp'
   ```
3. **Переустановите компоненты:**
   ```bash
   # Удалить Minikube кластер
   minikube delete

   # Переустановить все
   ./install-prerequisites.sh
   ```
4. **Полная очистка и переустановка:**
   ```bash
   # Очистить все
   ./scripts/uninstall.sh

   # Удалить Minikube
   minikube delete
   rm -rf ~/.minikube

   # Установить заново
   ./install-prerequisites.sh
   ./quickstart.sh
   ```

---

## ✨ Успешная установка!

После успешной установки вы увидите:

```
╔══════════════════════════════════════════════════╗
║          🎉 Deployment Successful! 🎉           ║
╚══════════════════════════════════════════════════╝

📍 Access URLs:
   Dashboard:     http://192.168.49.2:30080
   Pipelines:     http://192.168.49.2:30888
   Katib:         http://192.168.49.2:30777
   JupyterLab:    http://192.168.49.2:30666
   MinIO Console: http://192.168.49.2:30900

🔑 Credentials:
   MinIO:  minioadmin / minioadmin123
   MySQL:  root / rootpass123
```

**Поздравляем! Kubeflow готов к использованию!** 🚀

---

## 📝 Следующие шаги

1. Откройте Dashboard: `http://<minikube-ip>:30080`
2. Попробуйте JupyterLab: `http://<minikube-ip>:30666`
3. Создайте свой первый Pipeline
4. Изучите [README.md](https://claude.ai/chat/README.md) для подробной документации

---

**Happy ML Engineering!** 🤖✨
