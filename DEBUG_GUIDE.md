# Debug Guide: Capturing OCR Logs

## How to Capture Debug Logs

### Option 1: Using Flutter Logs Command (Easiest)

1. **Open terminal** in the project directory
2. **Start the app** on your device/emulator
3. **In a new terminal tab**, run:
   ```bash
   flutter logs
   ```
4. **Scan a card** that's failing in the app
5. **Copy the entire console output** including:
   - `=== OCR Text Recognition Service Started ===`
   - All extracted lines
   - `=== Card Number Parser Started ===`
   - All parsing details
   - `=== Card Number Parser Completed ===`

### Option 2: Using IDE Console (VS Code / Android Studio)

1. **Open Debug Console** in your IDE
2. **Run the app** with debugging enabled
3. **Scan a card**
4. **Look for logs starting with** `=== OCR Text Recognition Service Started ===`
5. **Copy everything** from start to `=== Card Number Parser Completed ===`

### Option 3: Copy from App UI

After scanning a card that fails:
1. Tap **"View Raw OCR Text"** - this shows the extracted text
2. Tap **"Debug Logs (check console)"** - this reminds you where logs are

---

## What to Look For in the Logs

### Section 1: OCR Text Recognition
```
=== OCR Text Recognition Service Started ===
Image file: /path/to/image
Extracted lines from initial OCR: 5
  Line 0: "ICICI Bank"
  Line 1: "Platinum"
  Line 2: "4035 6229 9125 2000"
  ...
```

**Key info**: How many lines were extracted and what they contain

### Section 2: Number Band Enhancement
```
_recognizeEnhancedNumberBand: Finding best digit line...
Best line found with 16 digits: "4035 6229 9125 2000"
Crop region: 100.5, 200.3, 450.2, 280.5
Crop size: 349.7x80.2
Processing enhanced crop (color)...
Enhanced OCR (color) result:
  "4035 6229 9125 2000"
Processing enhanced crop (contrast)...
Enhanced OCR (contrast) result:
  "4035 6229 9125 2000"
```

**Key info**: 
- How many digits found in best line
- Crop region coordinates
- Whether enhancement improved the text

### Section 3: Card Number Parser
```
=== Card Number Parser Started ===
Raw text to parse:
ICICI Bank
Platinum
4035 6229 9125 2000
VALID THRU 08/29
KALLA DALAYYA
VISA

Found 6 lines to parse
Line 0: "ICICI Bank"
Line 1: "Platinum"
Line 2: "4035 6229 9125 2000"
  Found candidate: "4035622991252000" (16 digits)
    ✓ Network: Visa, Luhn: PASS
  Found candidate: "0825" (4 digits)
    ✗ Invalid length (need 12-19 digits)

Found 1 total candidates
Checking candidate: 4035622991252000 (Visa)
  Length valid: true
  ✓ SELECTED

✓ Card number extracted: 4035622991252000
=== Card Number Parser Completed ===
```

**Key info**:
- All candidate numbers found
- Why candidates were rejected
- Final selected number

---

## Common Issues & What Logs Show

### Issue: "Card number not found"

**Log patterns to check**:

1. **OCR produced no digits**:
   ```
   Best line found with 0 digits: ""
   Insufficient digits (0 < 7), skipping enhanced crop
   ```
   → Card number band wasn't detected at all

2. **OCR found digits but fewer than 12**:
   ```
   Found candidate: "5223580075" (10 digits)
     ✗ Invalid length (need 12-19 digits)
   ```
   → Number was incomplete or corrupted

3. **OCR found text but parser didn't match**:
   ```
   Line 2: "4035 b229 9l25 2000"
   Found candidate: "4035622991252000" (15 digits)
     ✗ Invalid length for Visa
   ```
   → After letter removal, digit count changed

4. **Luhn checksum failed**:
   ```
   Found candidate: "4035822991252000" (16 digits)
     ✓ Network: Visa, Luhn: FAIL
   ```
   → Number contains OCR errors

---

## When Sharing Logs

Please include:

1. **The card image** (physical photo you're scanning)
2. **The full console output** from `flutter logs`
3. **What you expected** vs **what happened**

Example:
```
Card: ICICI Bank Platinum
Expected: 4035 6229 9125 2000
Got: Card number not found

=== OCR Text Recognition Service Started ===
...
[paste full logs here]
...
=== Card Number Parser Completed ===
```

---

## Running Tests with Debug Output

To run tests and see debug output:

```bash
flutter test test/payment_card_parser_test.dart -v
```

The `-v` flag shows all debug output from the tests.
