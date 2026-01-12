#!/bin/bash
set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Bootstrap Crossplane Infrastructure with Argo CD${NC}"
echo "=================================================="

# Проверка наличия kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl не найден. Установите kubectl и повторите попытку.${NC}"
    exit 1
fi

# Проверка наличия helm
if ! command -v helm &> /dev/null; then
    echo -e "${RED}❌ helm не найден. Установите helm и повторите попытку.${NC}"
    exit 1
fi

# Проверка подключения к кластеру
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Не удалось подключиться к кластеру. Проверьте kubeconfig.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Подключение к кластеру установлено${NC}"

# Шаг 1: Создание namespace для основного ArgoCD
echo -e "\n${YELLOW}📦 Шаг 1: Создание namespace для основного ArgoCD${NC}"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✅ Namespace argocd создан${NC}"

# Шаг 2: Добавление Helm репозитория
echo -e "\n${YELLOW}📦 Шаг 2: Добавление Helm репозитория ArgoCD${NC}"
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update
echo -e "${GREEN}✅ Helm репозиторий добавлен${NC}"

# Шаг 3: Установка основного ArgoCD
echo -e "\n${YELLOW}📦 Шаг 3: Установка основного ArgoCD${NC}"
if helm list -n argocd | grep -q argocd; then
    echo -e "${YELLOW}⚠️  ArgoCD уже установлен. Обновляю...${NC}"
    helm upgrade argocd argo/argo-cd \
        --namespace argocd \
        --version 9.2.3 \
        --wait --timeout 10m
else
    helm install argocd argo/argo-cd \
        --namespace argocd \
        --version 9.2.3 \
        --set server.service.type=LoadBalancer \
        --set server.extraArgs[0]=--insecure \
        --set server.extraArgs[1]=--disable-auth \
        --wait --timeout 10m
fi
echo -e "${GREEN}✅ ArgoCD установлен${NC}"

# Шаг 4: Ожидание готовности ArgoCD
echo -e "\n${YELLOW}⏳ Ожидание готовности ArgoCD...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd 2>/dev/null || true
kubectl wait --for=condition=ready --timeout=300s pod -l app.kubernetes.io/name=argocd-server -n argocd 2>/dev/null || true
echo -e "${GREEN}✅ ArgoCD готов${NC}"

# Шаг 5: Получение пароля администратора
echo -e "\n${BLUE}🔐 Шаг 4: Получение пароля администратора${NC}"
sleep 5
MAX_RETRIES=10
RETRY_COUNT=0
ADMIN_PASSWORD=""

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "")
    if [ -n "$ADMIN_PASSWORD" ]; then
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo -e "${YELLOW}   Попытка $RETRY_COUNT/$MAX_RETRIES...${NC}"
    sleep 2
done

if [ -z "$ADMIN_PASSWORD" ]; then
    echo -e "${YELLOW}⚠️  Пароль еще не создан. Выполните позже:${NC}"
    echo "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
else
    echo -e "${GREEN}✅ Пароль администратора получен${NC}"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}   ArgoCD Admin Password:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}$ADMIN_PASSWORD${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
fi

# Шаг 6: Установка Root Application
echo -e "\n${YELLOW}📦 Шаг 5: Установка Root Application${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_APP_PATH="$SCRIPT_DIR/bootstrap/root-app.yaml"

if [ ! -f "$ROOT_APP_PATH" ]; then
    echo -e "${RED}❌ Файл $ROOT_APP_PATH не найден${NC}"
    exit 1
fi

kubectl apply -f "$ROOT_APP_PATH"
echo -e "${GREEN}✅ Root Application установлен${NC}"

# Шаг 7: Информация о namespaces
echo -e "\n${BLUE}📋 Информация о развертывании:${NC}"
echo ""
echo -e "${GREEN}Namespaces, которые будут созданы:${NC}"
echo -e "  ${YELLOW}argocd${NC}                    - ArgoCD + все Applications (управление)"
echo -e "  ${YELLOW}crossplane-system${NC}         - Crossplane + провайдеры + ExternalSecret для провайдеров"
echo -e "  ${YELLOW}external-secrets-system${NC}   - External Secrets Operator"
echo ""
echo -e "${BLUE}💡 Важно:${NC}"
echo -e "  - Applications находятся в ${YELLOW}argocd${NC} namespace"
echo -e "  - ExternalSecret для провайдеров Crossplane должен быть в ${YELLOW}crossplane-system${NC}"
echo -e "  - Инфраструктурные ресурсы (XR) создавайте в ${YELLOW}default${NC} или отдельных namespaces"
echo ""

# Итоговая информация
echo -e "${GREEN}=================================================="
echo "✅ Bootstrap завершен успешно!"
echo "==================================================${NC}"
echo ""
echo -e "${BLUE}📋 Следующие шаги:${NC}"
echo ""
echo "1. Проверьте статус приложений:"
echo -e "   ${YELLOW}kubectl get applications -n argocd${NC}"
echo ""
echo "2. Доступ к ArgoCD UI:"
echo -e "   ${YELLOW}kubectl port-forward svc/argocd-server -n argocd 8080:443${NC}"
echo "   Откройте: https://localhost:8080"
echo "   Логин: admin"
if [ -n "$ADMIN_PASSWORD" ]; then
    echo -e "   Пароль: ${YELLOW}$ADMIN_PASSWORD${NC}"
else
    echo "   Пароль: [получите командой выше]"
fi
echo ""
echo "3. Мониторинг развертывания:"
echo -e "   ${YELLOW}watch kubectl get applications -n argocd${NC}"
echo ""
echo "4. Проверка развернутых компонентов:"
echo -e "   ${YELLOW}kubectl get pods -n crossplane-system${NC}"
echo -e "   ${YELLOW}kubectl get pods -n external-secrets-system${NC}"
echo ""
