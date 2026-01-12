# Архитектура Namespaces

## 📋 Структура Namespaces

### ✅ argocd namespace
**Назначение:** Централизованное управление через ArgoCD

**Содержимое:**
- ArgoCD (основной контроллер)
- `root-app` Application
- `crossplane` Application (управление развертыванием Crossplane)
- `external-secrets` Application (управление развертыванием External Secrets)

**Почему:** Все Applications в одном месте для удобного управления через ArgoCD UI

---

### ✅ crossplane-system namespace
**Назначение:** Системный namespace для Crossplane и его провайдеров

**Содержимое:**
- Crossplane контроллеры
- Провайдеры Crossplane (AWS, GCP, Azure и т.д.)
- ProviderConfig ресурсы
- **ExternalSecret ресурсы для секретов провайдеров** ⚠️ ВАЖНО!

**Почему:** 
- Crossplane и провайдеры - системные компоненты
- ExternalSecret для провайдеров должен быть в `crossplane-system`, чтобы секреты были доступны провайдерам

**Пример ExternalSecret в crossplane-system:**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: aws-provider-credentials
  namespace: crossplane-system  # ⚠️ ВАЖНО: здесь!
spec:
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: aws-creds
    creationPolicy: Owner
```

---

### ✅ external-secrets-system namespace
**Назначение:** Системный namespace для External Secrets Operator

**Содержимое:**
- External Secrets Operator (контроллеры, webhook)
- SecretStore ресурсы (опционально, если глобальные)

**Почему:** External Secrets - системный компонент, должен быть изолирован

---

### ✅ default или другие namespaces
**Назначение:** Пользовательские инфраструктурные ресурсы

**Содержимое:**
- Composite Resources (XR) - инфраструктурные ресурсы Crossplane
- Claims - запросы на создание инфраструктуры
- ExternalSecret для секретов приложений (если нужны)

**Пример:**
```yaml
# В default или project namespace
apiVersion: aws.crossplane.io/v1alpha1
kind: S3Bucket
metadata:
  name: my-bucket
  namespace: default  # или project namespace
```

---

## 🎯 Правила размещения ресурсов

### ExternalSecret ресурсы:

1. **Для провайдеров Crossplane** → `crossplane-system`
   - AWS credentials
   - GCP service account keys
   - Azure credentials
   - Другие секреты провайдеров

2. **Для приложений** → namespace приложения
   - Database credentials
   - API keys
   - Другие секреты приложений

### Инфраструктурные ресурсы Crossplane:

- **XR (Composite Resources)** → `default` или отдельные namespaces по проектам
- **Claims** → namespace где нужно использовать инфраструктуру

---

## 📊 Схема взаимодействия

```
argocd namespace
├── ArgoCD
└── Applications (crossplane, external-secrets)

crossplane-system namespace
├── Crossplane
├── Providers (AWS, GCP, etc.)
├── ProviderConfig
└── ExternalSecret (для провайдеров) ⚠️

external-secrets-system namespace
└── External Secrets Operator

default namespace
├── XR (Composite Resources)
├── Claims
└── ExternalSecret (для приложений, опционально)
```

---

## ✅ Best Practices

1. **Applications всегда в argocd** - для централизованного управления
2. **ExternalSecret для провайдеров в crossplane-system** - чтобы секреты были доступны провайдерам
3. **Инфраструктурные ресурсы в отдельных namespaces** - для изоляции по проектам
4. **Системные компоненты в системных namespaces** - для четкого разделения
