# Crossplane Infrastructure with Argo CD

Проект для развертывания инфраструктуры на базе Crossplane с управлением через Argo CD и секретами через External Secrets Operator.

## 🏗️ Архитектура

Проект использует **GitOps подход** с Argo CD и паттерном **"Apps of Apps"** для управления инфраструктурой:

### 🎯 Паттерн "Apps of Apps"
- Root Application (`bootstrap/root-app.yaml`) управляет **всеми приложениями**
- Включая **сам ArgoCD** - ArgoCD управляет собой через Git
- Позволяет обновлять ArgoCD через Git: меняем версию в `charts/argocd/values.yaml`
- **Циклическая зависимость** ⚠️: ArgoCD следит за своими изменениями

```
├── bootstrap/               # Корневой Argo CD Application (запускается вручную)
│   └── root-app.yaml        # Мониторит apps/ и infra/apps/
├── apps/                    # ArgoCD Applications
│   ├── argocd.yaml          # Argo CD (управляется root-app через Apps of Apps)
│   ├── crossplane.yaml      # Crossplane v2.1.3
│   ├── external-secrets.yaml # External Secrets v1.2.1
│   └── kubernetes-provider.yaml # Kubernetes провайдер для Crossplane
└── charts/                  # Кастомные Helm чарты
    ├── argocd/
    ├── crossplane/
    ├── external-secrets/
    └── kubernetes-provider/  # Wrapper чарт для Kubernetes провайдера
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

### 2. Создание namespace для Argo CD

```bash
kubectl create namespace argocd
```

### 3. Установка Root Application

Root Application использует паттерн **"Apps of Apps"** - запускается **вручную один раз** и затем автоматически управляет всеми приложениями, включая **сам ArgoCD**:

```bash
kubectl apply -f bootstrap/root-app.yaml
```

> **⚠️ Паттерн "Apps of Apps":** ArgoCD управляет сам собой через root-app. Это позволяет:
> - Обновлять ArgoCD через Git (меняем версию в `charts/argocd/values.yaml`)
> - Менять конфигурацию ArgoCD через Git
> - Автоматическое восстановление при сбоях
>
> **Важно:** При первом запуске ArgoCD еще не существует, поэтому root-app создаст его вместе со всеми остальными приложениями.

### 4. Доступ к Argo CD UI

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

Ожидаемые приложения в Argo CD (все управляются root-app):
- `root-app` - Корневое приложение (самоуправление)
- `argocd` - **Argo CD управляет сам собой** ⚠️
- `crossplane` - Crossplane
- `external-secrets` - External Secrets Operator
- `kubernetes-provider` - Kubernetes провайдер для Crossplane

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
- **Провайдеры:** Kubernetes провайдер (v1.2.0) установлен и настроен

### External Secrets

External Secrets настроен с:
- **CRDs:** Автоматическая установка
- **Webhook:** Включен валидационный webhook
- **ServiceAccount:** Создан для доступа к секретам

## 🔧 Провайдеры Crossplane

**Kubernetes провайдер** уже установлен и настроен автоматически:
- **Версия:** crossplane/provider-kubernetes:v1.2.0
- **Конфигурация:** InjectedIdentity (использует ServiceAccount Crossplane)

Для добавления дополнительных провайдеров:

```bash
# Пример добавления провайдера AWS (замените на нужный провайдер)
kubectl apply -f - <<EOF
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws
spec:
  package: xpkg.crossplane.io/crossplane-contrib/provider-aws:v0.45.0
EOF
```

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
