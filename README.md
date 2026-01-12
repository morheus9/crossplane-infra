# Crossplane Infrastructure with Argo CD

Проект для развертывания инфраструктуры на базе Crossplane с управлением через Argo CD и секретами через External Secrets Operator.

## 🏗️ Архитектура

Проект использует **GitOps подход** с ручной установкой ArgoCD и автоматизированным управлением инфраструктурой:

### 🎯 Принцип работы
- **ArgoCD устанавливается вручную** через Helm для полного контроля
- **Root Application** (`bootstrap/root-app.yaml`) управляет инфраструктурой
- **Инфраструктура:** Crossplane + External Secrets Operator
- **GitOps:** Все изменения инфраструктуры через Git

```
├── bootstrap/               # Корневой Argo CD Application
│   └── root-app.yaml        # Управляет всеми приложениями включая "дочерний" ArgoCD
├── apps/                    # ArgoCD Applications
│   ├── argocd.yaml          # "Дочерний" ArgoCD (namespace: argocd-child)
│   ├── crossplane.yaml      # Crossplane v2.1.3 + Kubernetes провайдер
│   └── external-secrets.yaml # External Secrets v1.2.1
└── charts/                  # Кастомные Helm чарты
    ├── argocd/              # Конфигурация ArgoCD (для ручной установки)
    ├── crossplane/          # Crossplane + провайдеры
    └── external-secrets/    # External Secrets Operator
```

## 📋 Предварительные требования

- Kubernetes кластер (EKS, GKE, AKS или локальный)
- kubectl настроенный для доступа к кластеру
- Git репозиторий (уже настроен: `https://github.com/morheus9/crossplane-infra`)


## 🚀 Установка

### 1. Клонирование репозитория

```bash
git clone https://github.com/morheus9/crossplane-infra.git
cd crossplane-infra
```

### 2. Ручная установка основного Argo CD

Устанавливаем Argo CD вручную через Helm с нашей кастомной конфигурацией:

```bash
# Создать namespace для основного ArgoCD
kubectl create namespace argocd

# Добавить Helm репозиторий ArgoCD
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Установить ArgoCD с нашей конфигурацией
helm install argocd argo/argo-cd \
  --namespace argocd \
  --version 9.3.0 \
  --values charts/argocd/values.yaml \
  --wait
```

### 3. Установка Root Application

Root Application управляет всей инфраструктурой включая "дочерний" ArgoCD:

```bash
kubectl apply -f bootstrap/root-app.yaml
```

> **🎯 Результат:** Основной ArgoCD берет под управление всю инфраструктуру, включая "дочерний" ArgoCD в отдельном namespace

### 4. Доступ к основному Argo CD UI

Получите пароль для входа в Argo CD:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

Порт-форвардинг для доступа к веб-интерфейсу:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Откройте в браузере: `https://localhost:8080`

**Логин:** `admin`
**Пароль:** [полученный выше]

### 5. Проверка установки

Проверьте статус приложений в Argo CD UI или через CLI:

```bash
kubectl get applications -n argocd
```

После установки в основном Argo CD появятся приложения:
- `root-app` - Корневое приложение, управляющее всей инфраструктурой
- `argocd` - "Дочерний" ArgoCD (развертывается в namespace argocd-child)
- `crossplane` - Crossplane с Kubernetes провайдером
- `external-secrets` - External Secrets Operator

## ⚙️ Настройка

### Argo CD

Argo CD настроен с:
- **Репозитории:** Добавлены репозитории Crossplane и External Secrets
- **RBAC:** Базовая политика доступа
- **Сервис:** LoadBalancer для внешнего доступа
- **Плагины:** Kustomize плагин

### Crossplane

Crossplane установлен с:
- **CRDs:** Автоматическая установка CRDs
- **Безопасность:** Non-root пользователь
- **Провайдеры:** Управление через `charts/crossplane/values.yaml`

**Добавление провайдеров (GitOps подход):** Раскомментируйте или добавьте нужные провайдеры в `charts/crossplane/values.yaml`:
```yaml
provider:
  packages:
    - crossplane/provider-kubernetes:v1.2.0  # Включен по умолчанию
    - xpkg.crossplane.io/crossplane-contrib/provider-aws:v0.45.0  # Пример
```

> **✅ Рекомендуемый способ:** Через `values.yaml` - изменения применяются автоматически через ArgoCD

### External Secrets

External Secrets настроен с:
- **CRDs:** Автоматическая установка
- **Webhook:** Включен валидационный webhook
- **ServiceAccount:** Создан для доступа к секретам

## 🔧 Провайдеры Crossplane

**Kubernetes провайдер** включен по умолчанию и устанавливается автоматически:
- **Версия:** crossplane/provider-kubernetes:v1.2.0
- **Конфигурация:** InjectedIdentity (использует ServiceAccount Crossplane)

**Добавление дополнительных провайдеров:**
1. Раскомментируйте или добавьте нужные провайдеры в `charts/crossplane/values.yaml`
2. Зафиксируйте изменения в Git
3. Argo CD автоматически применит обновления

После установки провайдера настройте его credentials через Secret или External Secrets.

## 🔐 Настройка секретов (External Secrets)

После установки External Secrets настройте SecretStore для доступа к вашим секретам:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: my-secret-store
  namespace: default
spec:
  provider:
    # Настройте провайдера согласно вашей системе секретов
    # (HashiCorp Vault, Azure Key Vault, GCP Secret Manager и т.д.)
    vault:
      server: "http://vault.example.com:8200"
      path: "secret"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "external-secrets"
```

## 📊 Мониторинг

### Проверка статуса компонентов:

```bash
# Argo CD
kubectl get pods -n argocd

# Crossplane
kubectl get pods -n crossplane-system

# External Secrets
kubectl get pods -n external-secrets-system
```

### Логи компонентов:

```bash
# Argo CD Server
kubectl logs -n argocd deployment/argocd-server

# Crossplane
kubectl logs -n crossplane-system deployment/crossplane

# External Secrets
kubectl logs -n external-secrets-system deployment/external-secrets-webhook
```

## 🛠️ Разработка и обновление

### Добавление нового приложения:

1. Создайте YAML файл в папке `apps/`
2. Следуйте паттерну существующих приложений
3. Argo CD автоматически обнаружит и развернет приложение

### Обновление версий:

1. Проверьте актуальные версии чартов
2. Обновите `targetRevision` в соответствующих YAML файлах
3. Зафиксируйте изменения в Git
4. Argo CD автоматически применит обновления

## 🐛 Устранение неполадок

### Argo CD не синхронизируется:

```bash
# Проверьте статус приложения
kubectl get applications -n argocd

# Детальный статус
kubectl describe application <app-name> -n argocd
```

### Crossplane не работает:

```bash
# Проверьте CRDs
kubectl get crds | grep crossplane

# Проверьте логи
kubectl logs -n crossplane-system deployment/crossplane
```

### Проблемы с секретами:

```bash
# Проверьте SecretStore
kubectl get secretstore

# Проверьте ExternalSecret
kubectl describe externalsecret <name>
```

## 📚 Дополнительные ресурсы

- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [Crossplane Documentation](https://docs.crossplane.io/)
- [External Secrets Documentation](https://external-secrets.io/)
- [GitOps Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
