#!/bin/bash

# BYBATA Donation Flow Test Runner
# This script helps you run the end-to-end donation test

echo "🧪 BYBATA DONATION FLOW - TEST RUNNER"
echo "======================================"
echo ""

# Color definitions for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}📋 QUICK TEST OVERVIEW${NC}"
echo -e "This test verifies the complete donation flow between two users:"
echo -e "👤 Creator: ${GREEN}akingbadekayode@gmail.com${NC}"
echo -e "💝 Donor: ${GREEN}test@example.com${NC}"
echo ""

echo -e "${YELLOW}⚠️  PREREQUISITES CHECK${NC}"
echo "Before starting, ensure:"
echo "✅ Backend API is running and accessible"
echo "✅ Both test users exist in the database"
echo "✅ App is built and running on device/simulator"
echo "✅ You have the test guide open (DONATION_TEST_GUIDE.md)"
echo ""

# Check if test guide exists
if [ -f "DONATION_TEST_GUIDE.md" ]; then
    echo -e "${GREEN}✅ Test guide found!${NC}"
else
    echo -e "${RED}❌ Test guide not found!${NC}"
    echo "Please ensure DONATION_TEST_GUIDE.md is in the current directory"
    exit 1
fi

echo ""
echo -e "${BLUE}📱 READY TO START?${NC}"
echo ""

# Function to wait for user input
wait_for_continue() {
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read -r
}

# Phase 1: Creator
echo -e "${BLUE}📱 PHASE 1: CREATOR - CAMPAIGN CREATION${NC}"
echo "========================================"
echo ""
echo "🔐 Step 1: Login as Creator"
echo "   Email: akingbadekayode@gmail.com"
echo "   Password: password123"
echo ""
echo "➕ Step 2: Create Campaign"
echo "   Title: Emergency Medical Fund - E2E Test"
echo "   Category: Healthcare"
echo "   Goal: ₦5,000"
echo "   Mark as Urgent: ✅"
echo ""
echo "✅ Step 3: Verify Campaign Created"
echo "🚪 Step 4: Logout Creator"
echo ""

wait_for_continue

# Phase 2: Donor
echo -e "${BLUE}💝 PHASE 2: DONOR - DONATION PROCESS${NC}"
echo "===================================="
echo ""
echo "🔐 Step 1: Login as Donor"
echo "   Email: test@example.com"
echo "   Password: password123"
echo ""
echo "🔍 Step 2: Find Campaign"
echo "   Look for: Emergency Medical Fund - E2E Test"
echo ""
echo "💰 Step 3: Make Donation"
echo "   Amount: ₦100"
echo "   Message: This is a test donation - E2E flow"
echo ""
echo "✅ Step 4: Verify Success"
echo "📊 Step 5: Check History & Stats"
echo ""

wait_for_continue

# Phase 3: Verification
echo -e "${BLUE}🔍 PHASE 3: VERIFICATION${NC}"
echo "========================"
echo ""
echo "👤 Step 1: Switch to Creator"
echo "   Logout donor, login creator"
echo ""
echo "📈 Step 2: Verify Progress"
echo "   Raised: ₦100 (2%)"
echo "   Supporters: 1"
echo ""
echo "👥 Step 3: Check Donation Details"
echo "   Donor info visible"
echo "   Message visible"
echo ""

wait_for_continue

# Checklist
echo -e "${BLUE}✅ VERIFICATION CHECKLIST${NC}"
echo "========================="
echo ""
echo "Mark each item as you verify it:"
echo ""
echo "Campaign Creation:"
echo "□ Campaign created successfully"
echo "□ Campaign visible to other users"
echo "□ Urgent badge appears"
echo "□ Category filtering works"
echo ""
echo "Donation Process:"
echo "□ Campaign found by donor"
echo "□ Donation amount selection works"
echo "□ Message added successfully"
echo "□ Confirmation processes"
echo "□ Success message appears"
echo ""
echo "Data Updates:"
echo "□ Progress updates immediately"
echo "□ Supporter count increments"
echo "□ Donation appears in history"
echo "□ KARMA points awarded"
echo "□ Stats update in real-time"
echo ""
echo "Creator Visibility:"
echo "□ Updated campaign stats visible"
echo "□ Donation details visible"
echo "□ Supporter information shown"
echo "□ Messages from donors visible"
echo ""

wait_for_continue

# Results
echo -e "${BLUE}📄 TEST RESULTS${NC}"
echo "==============="
echo ""
echo "Please fill out your test results:"
echo ""
echo "Campaign Creation: ✅ PASS / ❌ FAIL"
echo "Donation Process: ✅ PASS / ❌ FAIL"
echo "Progress Updates: ✅ PASS / ❌ FAIL"
echo "KARMA System: ✅ PASS / ❌ FAIL"
echo "Data Persistence: ✅ PASS / ❌ FAIL"
echo ""
echo "Bugs Found:"
echo "[List any issues discovered]"
echo ""
echo "Performance Notes:"
echo "API Response Time: [X]ms"
echo "UI Responsiveness: [Excellent/Good/Poor]"
echo ""

# Additional tests
echo -e "${YELLOW}🧪 ADDITIONAL TESTS (Optional)${NC}"
echo "==============================="
echo ""
echo "1. Multiple Donations Test"
echo "   - Make additional donations with different amounts"
echo "   - Verify cumulative progress"
echo ""
echo "2. Anonymous Donation Test"
echo "   - Make donation with anonymous option"
echo "   - Verify donor name is hidden"
echo ""
echo "3. Currency Test (if supported)"
echo "   - Test different currencies"
echo "   - Verify conversion rates"
echo ""

wait_for_continue

# Completion
echo -e "${GREEN}🎉 TEST COMPLETED!${NC}"
echo "=================="
echo ""
echo "Next Steps:"
echo "1. Review your test results"
echo "2. Document any bugs found"
echo "3. Report findings to development team"
echo "4. If all tests pass, donation flow is ready! 🚀"
echo ""
echo -e "${BLUE}For detailed instructions, refer to: DONATION_TEST_GUIDE.md${NC}"
echo ""

# Offer to open the detailed guide
echo "Would you like to open the detailed test guide? (y/n)"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    if command -v code &> /dev/null; then
        code DONATION_TEST_GUIDE.md
    elif command -v open &> /dev/null; then
        open DONATION_TEST_GUIDE.md
    elif command -v cat &> /dev/null; then
        echo ""
        echo "=== DETAILED TEST GUIDE ==="
        cat DONATION_TEST_GUIDE.md
    else
        echo "Please open DONATION_TEST_GUIDE.md manually"
    fi
fi

echo ""
echo "Thank you for testing BYBATA! 🙏"