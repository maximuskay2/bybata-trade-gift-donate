#!/bin/bash

# BYBATA Railway Deployment Script
# This script helps deploy all services to Railway using CLI

set -e  # Exit on error

echo "=========================================="
echo "BYBATA Railway Deployment"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if Railway CLI is installed
if ! command -v railway &> /dev/null; then
    echo -e "${YELLOW}Railway CLI is not installed. Installing...${NC}"
    npm install -g @railway/cli
    echo -e "${GREEN}✓ Railway CLI installed${NC}"
else
    echo -e "${GREEN}✓ Railway CLI is installed ($(railway --version))${NC}"
fi

echo ""
echo -e "${BLUE}Step 1: Railway Authentication${NC}"
echo ""

# Check if already logged in
if railway whoami &> /dev/null; then
    echo -e "${GREEN}✓ Already logged in to Railway${NC}"
    railway whoami
else
    echo -e "${YELLOW}Please log in to Railway...${NC}"
    railway login
fi

echo ""
echo -e "${BLUE}Step 2: Project Setup${NC}"
echo ""

# Check if project is linked
if [ -f ".railway/project.json" ]; then
    echo -e "${GREEN}✓ Project is already linked${NC}"
    PROJECT_ID=$(cat .railway/project.json | grep -o '"projectId":"[^"]*' | cut -d'"' -f4)
    echo "Project ID: $PROJECT_ID"
else
    echo -e "${YELLOW}Linking to Railway project...${NC}"
    echo "Select an existing project or create a new one:"
    railway link
fi

echo ""
echo -e "${BLUE}Step 3: Service Selection${NC}"
echo ""
echo "Which services do you want to deploy?"
echo "1. Database (PostgreSQL)"
echo "2. API Service (NestJS)"
echo "3. Admin Service (Next.js)"
echo "4. Storage (Railway Buckets)"
echo "5. All Services"
echo ""
read -p "Enter your choice (1-5): " service_choice

deploy_database=false
deploy_api=false
deploy_admin=false
deploy_storage=false

case $service_choice in
    1)
        deploy_database=true
        ;;
    2)
        deploy_api=true
        ;;
    3)
        deploy_admin=true
        ;;
    4)
        deploy_storage=true
        ;;
    5)
        deploy_database=true
        deploy_api=true
        deploy_admin=true
        deploy_storage=true
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}Step 4: Environment Variables Setup${NC}"
echo ""

# Function to prompt for environment variable
prompt_env_var() {
    local var_name=$1
    local description=$2
    local is_secret=${3:-false}
    local default_value=$4
    
    if [ "$is_secret" = true ]; then
        read -sp "$description ($var_name): " value
        echo ""
    else
        if [ -n "$default_value" ]; then
            read -p "$description ($var_name) [default: $default_value]: " value
            value=${value:-$default_value}
        else
            read -p "$description ($var_name): " value
        fi
    fi
    
    if [ -n "$value" ]; then
        echo "$var_name=$value"
    fi
}

# Collect environment variables
ENV_VARS=""

if [ "$deploy_database" = true ] || [ "$deploy_api" = true ]; then
    echo -e "${YELLOW}Database Configuration:${NC}"
    
    # Get DATABASE_URL from Railway if database service exists
    if railway variables get DATABASE_URL &> /dev/null; then
        echo -e "${GREEN}DATABASE_URL already exists in Railway${NC}"
        read -p "Do you want to update it? (y/n): " update_db
        if [ "$update_db" = "y" ]; then
            DB_URL=$(prompt_env_var "DATABASE_URL" "PostgreSQL connection string" false)
            ENV_VARS="$ENV_VARS\n$DB_URL"
        fi
    else
        echo "You need to create a PostgreSQL service first, or provide DATABASE_URL"
        read -p "Enter DATABASE_URL (or press Enter to skip): " db_url
        if [ -n "$db_url" ]; then
            ENV_VARS="$ENV_VARS\nDATABASE_URL=$db_url"
        fi
    fi
fi

if [ "$deploy_api" = true ]; then
    echo ""
    echo -e "${YELLOW}API Service Environment Variables:${NC}"
    
    # JWT Secrets
    JWT_ACCESS=$(prompt_env_var "JWT_ACCESS_SECRET" "JWT Access Secret (min 32 chars)" true)
    JWT_REFRESH=$(prompt_env_var "JWT_REFRESH_SECRET" "JWT Refresh Secret (min 32 chars)" true)
    ENV_VARS="$ENV_VARS\n$JWT_ACCESS\n$JWT_REFRESH"
    
    # CORS
    CORS_ORIGINS=$(prompt_env_var "CORS_ORIGINS" "CORS Origins (comma-separated)" false "https://admin.up.railway.app")
    ENV_VARS="$ENV_VARS\n$CORS_ORIGINS"
    
    # Port
    ENV_VARS="$ENV_VARS\nPORT=3000"
    
    # Node Environment
    ENV_VARS="$ENV_VARS\nNODE_ENV=production"
    
    # Email Configuration
    echo ""
    read -p "Configure email? (y/n): " config_email
    if [ "$config_email" = "y" ]; then
        EMAIL_PROVIDER=$(prompt_env_var "EMAIL_PROVIDER" "Email Provider (smtp/resend/console)" false "console")
        ENV_VARS="$ENV_VARS\n$EMAIL_PROVIDER"
        
        if [ "$EMAIL_PROVIDER" != "EMAIL_PROVIDER=console" ]; then
            EMAIL_FROM=$(prompt_env_var "EMAIL_FROM" "Email From Address" false "noreply@bybata.com")
            ENV_VARS="$ENV_VARS\n$EMAIL_FROM"
            
            if [ "$EMAIL_PROVIDER" = "EMAIL_PROVIDER=smtp" ]; then
                SMTP_HOST=$(prompt_env_var "SMTP_HOST" "SMTP Host" false "smtp.gmail.com")
                SMTP_PORT=$(prompt_env_var "SMTP_PORT" "SMTP Port" false "587")
                SMTP_USER=$(prompt_env_var "SMTP_USER" "SMTP Username")
                SMTP_PASS=$(prompt_env_var "SMTP_PASS" "SMTP Password" true)
                ENV_VARS="$ENV_VARS\n$SMTP_HOST\n$SMTP_PORT\n$SMTP_USER\n$SMTP_PASS"
            elif [ "$EMAIL_PROVIDER" = "EMAIL_PROVIDER=resend" ]; then
                RESEND_KEY=$(prompt_env_var "RESEND_API_KEY" "Resend API Key" true)
                ENV_VARS="$ENV_VARS\n$RESEND_KEY"
            fi
        fi
    else
        ENV_VARS="$ENV_VARS\nEMAIL_PROVIDER=console"
    fi
    
    # Storage Configuration
    echo ""
    read -p "Configure storage? (y/n): " config_storage
    if [ "$config_storage" = "y" ]; then
        STORAGE_ENDPOINT=$(prompt_env_var "STORAGE_ENDPOINT" "Storage Endpoint (Railway Buckets or S3)")
        STORAGE_BUCKET=$(prompt_env_var "STORAGE_BUCKET" "Storage Bucket Name")
        STORAGE_ACCESS_KEY=$(prompt_env_var "STORAGE_ACCESS_KEY_ID" "Storage Access Key" true)
        STORAGE_SECRET=$(prompt_env_var "STORAGE_SECRET_ACCESS_KEY" "Storage Secret Key" true)
        STORAGE_REGION=$(prompt_env_var "STORAGE_REGION" "Storage Region" false "us-east-1")
        ENV_VARS="$ENV_VARS\n$STORAGE_ENDPOINT\n$STORAGE_BUCKET\n$STORAGE_ACCESS_KEY\n$STORAGE_SECRET\n$STORAGE_REGION"
    fi
    
    # Payment Gateways (optional)
    echo ""
    read -p "Configure payment gateways? (y/n): " config_payments
    if [ "$config_payments" = "y" ]; then
        read -p "Paystack Secret Key (or press Enter to skip): " paystack_secret
        if [ -n "$paystack_secret" ]; then
            ENV_VARS="$ENV_VARS\nPAYSTACK_SECRET=$paystack_secret"
        fi
        
        read -p "Stripe Secret Key (or press Enter to skip): " stripe_secret
        if [ -n "$stripe_secret" ]; then
            ENV_VARS="$ENV_VARS\nSTRIPE_SECRET=$stripe_secret"
        fi
    fi
fi

if [ "$deploy_admin" = true ]; then
    echo ""
    echo -e "${YELLOW}Admin Service Environment Variables:${NC}"
    
    # Get API URL
    API_URL=$(prompt_env_var "NEXT_PUBLIC_API_URL" "API URL" false "https://api.up.railway.app")
    ENV_VARS="$ENV_VARS\n$API_URL"
    
    # Admin URL
    ADMIN_URL=$(prompt_env_var "NEXT_PUBLIC_APP_URL" "Admin App URL" false "https://admin.up.railway.app")
    ENV_VARS="$ENV_VARS\n$ADMIN_URL"
fi

echo ""
echo -e "${BLUE}Step 5: Deploying Services${NC}"
echo ""

# Deploy Database (PostgreSQL)
if [ "$deploy_database" = true ]; then
    echo -e "${YELLOW}Setting up PostgreSQL database...${NC}"
    echo "Note: If database doesn't exist, create it in Railway dashboard first"
    echo "Then run: railway variables set DATABASE_URL=<your-database-url>"
fi

# Deploy API
if [ "$deploy_api" = true ]; then
    echo -e "${YELLOW}Deploying API service...${NC}"
    
    # Set environment variables
    echo -e "$ENV_VARS" | while IFS= read -r line; do
        if [ -n "$line" ] && [[ "$line" == *"="* ]]; then
            var_name=$(echo "$line" | cut -d'=' -f1)
            var_value=$(echo "$line" | cut -d'=' -f2-)
            
            # Check if variable is for API service
            if [[ "$var_name" == "JWT"* ]] || [[ "$var_name" == "CORS"* ]] || \
               [[ "$var_name" == "PORT" ]] || [[ "$var_name" == "NODE_ENV" ]] || \
               [[ "$var_name" == "EMAIL"* ]] || [[ "$var_name" == "SMTP"* ]] || \
               [[ "$var_name" == "RESEND"* ]] || [[ "$var_name" == "STORAGE"* ]] || \
               [[ "$var_name" == "PAYSTACK"* ]] || [[ "$var_name" == "STRIPE"* ]] || \
               [[ "$var_name" == "DATABASE_URL" ]]; then
                echo "Setting $var_name for API service..."
                railway variables set "$var_name=$var_value" --service api 2>/dev/null || \
                railway variables set "$var_name=$var_value"
            fi
        fi
    done
    
    # Deploy API
    echo "Deploying API from apps/api directory..."
    cd apps/api
    railway up --service api || railway up
    cd ../..
    echo -e "${GREEN}✓ API service deployed${NC}"
fi

# Deploy Admin
if [ "$deploy_admin" = true ]; then
    echo -e "${YELLOW}Deploying Admin service...${NC}"
    
    # Set environment variables
    echo -e "$ENV_VARS" | while IFS= read -r line; do
        if [ -n "$line" ] && [[ "$line" == *"="* ]]; then
            var_name=$(echo "$line" | cut -d'=' -f1)
            var_value=$(echo "$line" | cut -d'=' -f2-)
            
            # Check if variable is for Admin service
            if [[ "$var_name" == "NEXT_PUBLIC"* ]]; then
                echo "Setting $var_name for Admin service..."
                railway variables set "$var_name=$var_value" --service admin 2>/dev/null || \
                railway variables set "$var_name=$var_value"
            fi
        fi
    done
    
    # Deploy Admin
    echo "Deploying Admin from apps/admin directory..."
    cd apps/admin
    railway up --service admin || railway up
    cd ../..
    echo -e "${GREEN}✓ Admin service deployed${NC}"
fi

# Deploy Storage (Railway Buckets)
if [ "$deploy_storage" = true ]; then
    echo -e "${YELLOW}Setting up Railway Buckets...${NC}"
    echo "Note: Railway Buckets must be created in Railway dashboard"
    echo "After creating, configure CORS and update storage environment variables"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "Deployment Summary"
echo "=========================================="
echo ""

# Show deployed services
echo "Deployed Services:"
railway status

echo ""
echo -e "${GREEN}Next Steps:${NC}"
echo "1. Run database migrations: railway run --service api npx prisma migrate deploy"
echo "2. Check service logs: railway logs --service api"
echo "3. View service URLs: railway domain"
echo "4. Set up custom domains in Railway dashboard if needed"
echo ""

