# Mobile App End-to-End Testing Checklist

**Date:** December 21, 2025  
**Status:** Ready for Testing

---

## 📱 Test Environment Setup

- [ ] Flutter app running on simulator/device
- [ ] API server running on `http://localhost:3000`
- [ ] Database migrations applied
- [ ] Test user account created
- [ ] Biometric authentication enabled on device (for biometric tests)

---

## 🔐 Authentication & Security Tests

### PIN Setup Flow
- [ ] Navigate to Wallet → Settings → Security
- [ ] Tap "Set Wallet PIN"
- [ ] Enter 4-digit PIN (e.g., 1234)
- [ ] Confirm PIN entry
- [ ] Verify success message appears
- [ ] Verify PIN is saved (try to set again - should show "PIN already set")

### PIN Verification
- [ ] Navigate to Transfer screen
- [ ] Attempt to send BYC
- [ ] Verify PIN entry screen appears
- [ ] Enter correct PIN
- [ ] Verify transfer proceeds
- [ ] Test with incorrect PIN (should show error)

### Biometric Setup
- [ ] Navigate to Wallet → Settings → Security
- [ ] Enable "Biometric Authentication"
- [ ] Complete device biometric setup (if not already done)
- [ ] Verify biometric is enabled

### Biometric Authentication
- [ ] Navigate to Transfer screen
- [ ] Attempt to send BYC
- [ ] Verify biometric prompt appears (if enabled)
- [ ] Complete biometric authentication
- [ ] Verify transfer proceeds
- [ ] Test biometric failure → should fall back to PIN

---

## 💸 Transfer Tests

### Transfer with PIN
1. **Setup:**
   - [ ] Ensure PIN is set
   - [ ] Ensure sufficient BYC balance
   - [ ] Note recipient email/username

2. **Transfer:**
   - [ ] Navigate to Transfer screen
   - [ ] Enter recipient email/username
   - [ ] Enter amount (e.g., 10 BYC)
   - [ ] Add optional memo
   - [ ] Tap "Send BYC"
   - [ ] Enter PIN when prompted
   - [ ] Verify success message
   - [ ] Verify balance updated
   - [ ] Check transaction history

### Transfer with Biometric
1. **Setup:**
   - [ ] Ensure biometric is enabled
   - [ ] Ensure sufficient BYC balance

2. **Transfer:**
   - [ ] Navigate to Transfer screen
   - [ ] Enter recipient email/username
   - [ ] Enter amount
   - [ ] Tap "Send BYC"
   - [ ] Complete biometric authentication
   - [ ] Verify transfer completes
   - [ ] Check transaction history

### Transfer Limits
- [ ] Test minimum transfer amount (if configured)
- [ ] Test daily transfer limit (send multiple transfers)
- [ ] Verify limit error messages appear correctly

### Error Handling
- [ ] Test transfer with insufficient balance
- [ ] Test transfer to invalid recipient
- [ ] Test transfer with invalid amount
- [ ] Test network error handling
- [ ] Test authentication cancellation

---

## 📱 QR Code Tests

### QR Code Generation
1. **Basic QR:**
   - [ ] Navigate to Receive screen
   - [ ] Verify QR code auto-generates on load
   - [ ] Verify QR code displays correctly
   - [ ] Test "Refresh QR Code" button

2. **QR with Amount:**
   - [ ] Enable "Request Specific Amount"
   - [ ] Enter amount (e.g., 50 BYC)
   - [ ] Verify QR code updates
   - [ ] Verify amount is encoded in QR

3. **QR with Memo:**
   - [ ] Add memo/note
   - [ ] Verify QR code updates
   - [ ] Verify memo is encoded in QR

4. **Share QR:**
   - [ ] Test "Share QR Code" button
   - [ ] Test "Copy Link" button
   - [ ] Verify shared content is correct

### QR Code Scanning
1. **Scan Valid QR:**
   - [ ] Navigate to Transfer screen
   - [ ] Tap QR scanner button
   - [ ] Scan a valid QR code (from Receive screen)
   - [ ] Verify recipient is pre-filled
   - [ ] Verify amount is pre-filled (if specified)
   - [ ] Verify memo is pre-filled (if specified)
   - [ ] Complete transfer

2. **Scan Invalid QR:**
   - [ ] Scan an invalid QR code
   - [ ] Verify error message appears
   - [ ] Verify scanner resumes after error

3. **QR Scanner Features:**
   - [ ] Test flash toggle
   - [ ] Test camera switch (front/back)
   - [ ] Test scanner in different lighting conditions

---

## 🔒 Wallet Security Tests

### Wallet Lock/Unlock
- [ ] Test manual wallet lock
- [ ] Test wallet unlock with token
- [ ] Test wallet unlock with PIN
- [ ] Verify locked wallet prevents transfers

### Session Timeout
- [ ] Test session timeout (wait for timeout period)
- [ ] Verify re-authentication required after timeout
- [ ] Test activity updates session timeout

### Suspicious Activity
- [ ] Test rapid transactions (if configured)
- [ ] Test large amount transactions
- [ ] Verify suspicious activity detection
- [ ] Verify wallet auto-lock on critical activity

---

## 🧪 Integration Tests

### Complete Flow: Send with QR
1. [ ] User A: Generate QR code with amount
2. [ ] User B: Scan QR code
3. [ ] User B: Complete transfer with PIN/biometric
4. [ ] User A: Verify receipt of BYC
5. [ ] Both users: Check transaction history

### Complete Flow: Request Payment
1. [ ] User A: Generate QR with amount and memo
2. [ ] User A: Share QR code
3. [ ] User B: Scan shared QR code
4. [ ] User B: Complete payment
5. [ ] User A: Verify payment received

### Error Recovery
- [ ] Test app restart during transfer
- [ ] Test network interruption during transfer
- [ ] Test app backgrounding during authentication
- [ ] Verify proper error recovery

---

## 📊 Performance Tests

- [ ] Test PIN entry responsiveness
- [ ] Test biometric authentication speed
- [ ] Test QR code generation speed
- [ ] Test QR scanner performance
- [ ] Test transfer processing time
- [ ] Test transaction history loading

---

## 🐛 Bug Testing

### Edge Cases
- [ ] PIN with all same digits (e.g., 1111)
- [ ] PIN with sequential digits (e.g., 1234)
- [ ] Very large transfer amounts
- [ ] Very small transfer amounts
- [ ] Special characters in memo
- [ ] Long memo text
- [ ] QR code with very long data

### Boundary Conditions
- [ ] Minimum transfer amount
- [ ] Maximum transfer amount
- [ ] Daily limit boundary
- [ ] Session timeout boundary
- [ ] QR code expiration

---

## ✅ Test Results Template

```
Test Date: ___________
Tester: ___________
Device: ___________
OS Version: ___________

Authentication:
- PIN Setup: [ ] Pass [ ] Fail
- PIN Verification: [ ] Pass [ ] Fail
- Biometric Setup: [ ] Pass [ ] Fail
- Biometric Auth: [ ] Pass [ ] Fail

Transfers:
- Transfer with PIN: [ ] Pass [ ] Fail
- Transfer with Biometric: [ ] Pass [ ] Fail
- Transfer Limits: [ ] Pass [ ] Fail
- Error Handling: [ ] Pass [ ] Fail

QR Codes:
- QR Generation: [ ] Pass [ ] Fail
- QR Scanning: [ ] Pass [ ] Fail
- QR Sharing: [ ] Pass [ ] Fail

Security:
- Wallet Lock: [ ] Pass [ ] Fail
- Session Timeout: [ ] Pass [ ] Fail

Issues Found:
1. ___________
2. ___________
3. ___________
```

---

## 📝 Notes

- Test on both iOS and Android if possible
- Test on different screen sizes
- Test in different network conditions (WiFi, 4G, offline)
- Test with different user accounts
- Document any bugs or issues found

---

**Status:** Ready for Testing  
**Last Updated:** December 21, 2025

