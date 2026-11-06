#!/bin/bash

# ============================================================
# BYBATA RELEASE APK BUILD SCRIPT
# ============================================================
# This script builds a release APK signed with the production keystore
# Usage: ./scripts/build-release-apk.sh
# ============================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Header
echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════╗"
echo "║          BYBATA RELEASE APK BUILD SCRIPT               ║"
echo "║                                                        ║"
echo "║  This will build a signed release APK for testers     ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check Flutter installed
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter not found in PATH${NC}"
    echo "Install Flutter: https://flutter.dev/docs/get-started/install"
    exit 1
fi

# Check keystore exists
if [ ! -f "bybata-release.keystore" ]; then
    echo -e "${RED}❌ Keystore not found: bybata-release.keystore${NC}"
    echo "Expected location: $(pwd)/bybata-release.keystore"
    exit 1
fi

echo -e "${GREEN}✅ Keystore found${NC}"

# Get credentials
echo ""
echo -e "${YELLOW}Enter signing credentials:${NC}"

read -sp "🔐 Keystore password: " STORE_PASSWORD
echo
read -sp "🔑 Key password: " KEY_PASSWORD
echo

# Check if credentials are empty
if [ -z "$STORE_PASSWORD" ] || [ -z "$KEY_PASSWORD" ]; then
    echo -e "${RED}❌ Passwords cannot be empty${NC}"
    exit 1
fi

# Set environment variables
export STORE_PASSWORD
export KEY_PASSWORD
export KEY_ALIAS="bybata-release"
export STORE_FILE="../bybata-release.keystore"

# Display build info
echo ""
echo -e "${BLUE}Build Configuration:${NC}"
echo "  Platform: Android"
echo "  Build Type: Release"
echo "  Keystore: bybata-release.keystore"
echo "  Key Alias: $KEY_ALIAS"
echo "  Minification: Enabled"
echo "  Shrinking: Enabled"
echo ""

# Clean previous builds
echo -e "${YELLOW}🧹 Cleaning previous builds...${NC}"
flutter clean
echo -e "${GREEN}✅ Clean complete${NC}"

# Get dependencies
echo ""
echo -e "${YELLOW}📦 Getting dependencies...${NC}"
flutter pub get
echo -e "${GREEN}✅ Dependencies updated${NC}"

# Build APK
echo ""
echo -e "${YELLOW}🔨 Building release APK...${NC}"
echo "(This may take 2-5 minutes)"
echo ""

if flutter build apk --release --verbose; then
    echo ""
    echo -e "${GREEN}✅ Build successful!${NC}"
else
    echo ""
    echo -e "${RED}❌ Build failed!${NC}"
    echo "Check error messages above"
    exit 1
fi

# Verify APK exists
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ ! -f "$APK_PATH" ]; then
    echo -e "${RED}❌ APK file not found at $APK_PATH${NC}"
    exit 1
fi

# Get file info
APK_SIZE=$(ls -lh "$APK_PATH" | awk '{print $5}')
APK_DATE=$(ls -l "$APK_PATH" | awk '{print $6, $7, $8}')

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ APK BUILD COMPLETE${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""
echo "📊 Build Details:"
echo "  Location: $APK_PATH"
echo "  Size: $APK_SIZE"
echo "  Built: $APK_DATE"
echo ""

# Offer to verify signature
echo -e "${YELLOW}Verify APK signature? (y/n)${NC}"
read -r VERIFY_CHOICE

if [[ "$VERIFY_CHOICE" =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${YELLOW}🔍 Verifying signature...${NC}"
    if jarsigner -verify "$APK_PATH" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Signature verified${NC}"
        echo ""
        jarsigner -verify -verbose -certs "$APK_PATH" 2>/dev/null | head -20
    else
        echo -e "${RED}⚠️  Signature verification failed${NC}"
    fi
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📱 NEXT STEPS:${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""
echo "1. Copy to shared location:"
echo "   cp $APK_PATH ~/Desktop/bybata-release.apk"
echo ""
echo "2. Distribute to testers:"
echo "   • Firebase App Distribution (recommended)"
echo "   • Email"
echo "   • Google Drive / Dropbox"
echo "   • GitHub Releases"
echo ""
echo "3. Share installation guide:"
echo "   See: APK_BUILD_AND_DISTRIBUTION_GUIDE.md"
echo ""
echo "4. Collect feedback:"
echo "   • Bug reports"
echo "   • Feature requests"
echo "   • Performance issues"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}✨ Ready to distribute!${NC}"
echo ""

# Optional: Open APK location
if command -v open &> /dev/null; then
    echo -e "${YELLOW}Open APK folder? (y/n)${NC}"
    read -r OPEN_CHOICE
    
    if [[ "$OPEN_CHOICE" =~ ^[Yy]$ ]]; then
        open "$(dirname "$APK_PATH")"
    fi
fi

exit 0
