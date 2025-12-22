image.pngimage.png# App Store Submission Guide for DueTrack

This guide will walk you through the process of submitting DueTrack to the Apple App Store.

## Prerequisites

### 1. Apple Developer Account
- **Cost**: $99/year (USD)
- **Sign up**: https://developer.apple.com/programs/
- You'll need:
  - Apple ID
  - Payment method
  - Legal entity information (individual or organization)

### 2. Required Information
- App name: "DueTrack" (or your preferred name)
- App description
- Privacy policy URL (required for App Store)
- Support URL
- Marketing URL (optional)
- App icon (1024x1024 pixels)
- Screenshots for different device sizes
- App preview videos (optional but recommended)

## Step-by-Step Submission Process

### Phase 1: Prepare Your App

#### 1. Configure App Identity
1. In Xcode, select your project
2. Go to **General** tab
3. Set:
   - **Display Name**: "DueTrack" (what users see on home screen)
   - **Bundle Identifier**: `com.frankg.DueTrack` (must be unique)
   - **Version**: Start with `1.0.0`
   - **Build**: Start with `1`

#### 2. Configure Signing & Capabilities
1. Go to **Signing & Capabilities** tab
2. Select your **Team** (your Apple Developer account)
3. Xcode will automatically create:
   - App ID
   - Provisioning profiles
   - Certificates

#### 3. Set Deployment Target
1. Go to **Build Settings**
2. Set **iOS Deployment Target** to `16.0` or higher
3. This determines the minimum iOS version your app supports

#### 4. Configure App Icon
1. Go to **Assets.xcassets**
2. Select **AppIcon**
3. Add your app icon in all required sizes:
   - 1024x1024 (App Store)
   - 60x60, 120x120, 180x180 (iPhone)
   - 76x76, 152x152, 167x167 (iPad)

**Icon Requirements:**
- PNG format
- No transparency
- No rounded corners (iOS adds them automatically)
- No text or UI elements
- Simple, recognizable design

#### 5. Create Privacy Policy
You **must** have a privacy policy URL. Options:
- Host on your website
- Use a free service like:
  - GitHub Pages
  - Netlify
  - PrivacyPolicyGenerator.com

**Privacy Policy Must Include:**
- What data you collect (if any)
- How you use the data
- Data storage (local vs. cloud)
- Third-party services (if any)
- User rights
- Contact information

**Sample Privacy Policy for DueTrack:**
```
DueTrack Privacy Policy

Data Collection:
- DueTrack stores all data locally on your device
- We do not collect, transmit, or share any personal information
- All bill and payment data remains on your device

CloudKit (Optional):
- If you enable iCloud sync, data is stored in your personal iCloud account
- Apple handles all CloudKit data according to their privacy policy
- We do not have access to your iCloud data

Analytics:
- DueTrack does not use analytics or tracking services

Contact:
- For privacy questions, contact: [your email]
```

### Phase 2: App Store Connect Setup

#### 1. Create App Store Connect Account
1. Go to https://appstoreconnect.apple.com
2. Sign in with your Apple Developer account
3. Accept the agreements

#### 2. Create Your App
1. Click **"My Apps"** → **"+"** → **"New App"**
2. Fill in:
   - **Platform**: iOS
   - **Name**: "DueTrack" (must be unique, max 30 characters)
   - **Primary Language**: English (or your language)
   - **Bundle ID**: Select the one you created (`com.frankg.DueTrack`)
   - **SKU**: Unique identifier (e.g., `duetrack-001`)
   - **User Access**: Full Access (unless you have a team)

#### 3. App Information
Fill in:
- **Category**: 
  - Primary: Finance
  - Secondary: Productivity (optional)
- **Subtitle**: Short description (max 30 characters)
  - Example: "Track bills and payments"
- **Privacy Policy URL**: Your privacy policy URL
- **Support URL**: Your support/contact page
- **Marketing URL**: Optional website

### Phase 3: Prepare App Store Assets

#### 1. Screenshots (Required)
You need screenshots for each device size:

**iPhone 6.7" Display (iPhone 14 Pro Max, 15 Pro Max):**
- 1290 x 2796 pixels
- Need: 3-10 screenshots

**iPhone 6.5" Display (iPhone 11 Pro Max, XS Max):**
- 1242 x 2688 pixels

**iPhone 5.5" Display (iPhone 8 Plus, etc.):**
- 1242 x 2208 pixels

**iPad Pro 12.9":**
- 2048 x 2732 pixels

**How to Take Screenshots:**
1. Run your app in the simulator
2. Navigate to each important screen
3. Press `Cmd + S` to save screenshot
4. Or use `Device > Screenshot` in Xcode
5. Edit screenshots to remove status bar if needed

**Screenshot Tips:**
- Show key features (Dashboard, Bill Creation, Calendar)
- Use real data (not placeholder text)
- Show the app in action
- First screenshot is most important (appears in search)

#### 2. App Description
Write compelling descriptions:

**Name** (30 characters max):
```
DueTrack
```

**Subtitle** (30 characters max):
```
Track bills and payments
```

**Description** (up to 4000 characters):
```
DueTrack helps you stay on top of your bills and never miss a payment.

KEY FEATURES:
• Track recurring bills with custom frequencies
• Smart calendar view with color-coded status
• Payment history and reminders
• Financial insights and spending analysis
• Beautiful, intuitive interface

MANAGE YOUR BILLS:
Create and organize all your recurring bills in one place. Set up bills with monthly, weekly, quarterly, or custom frequencies. Track everything from utilities to subscriptions.

SMART REMINDERS:
Never miss a payment again. DueTrack sends you reminders 1, 3, and 7 days before bills are due, plus overdue alerts.

PAYMENT TRACKING:
Mark bills as paid with a single tap. Keep a complete payment history and see your spending patterns over time.

FINANCIAL INSIGHTS:
View your monthly spending breakdown by category. Understand where your money goes and plan better.

PRIVACY FIRST:
All your data is stored locally on your device. Your financial information never leaves your device unless you enable optional iCloud sync.

Perfect for managing:
• Utilities
• Subscriptions
• Loans
• Insurance
• Rent
• Credit cards
• And more!

Download DueTrack today and take control of your bills.
```

**Keywords** (100 characters max, comma-separated):
```
bill tracker,payment reminder,expense tracker,bills,finance,budget,subscriptions,utilities,reminder
```

**Promotional Text** (170 characters, can be updated without review):
```
New in this version: Enhanced calendar view, improved notifications, and better financial insights. Track your bills effortlessly!
```

**What's New** (for updates, 4000 characters max):
```
Version 1.0.0 - Initial Release

Welcome to DueTrack! The easiest way to track your bills and payments.

Features:
• Create and manage recurring bills
• Smart calendar view with color-coded status
• Payment tracking and history
• Financial insights and spending analysis
• Beautiful, intuitive interface
• Smart notification reminders
```

#### 3. App Preview Video (Optional but Recommended)
- 15-30 seconds
- Show app in action
- Record from simulator or device
- Formats: MOV or MP4
- Max file size: 500MB

### Phase 4: Build and Archive

#### 1. Configure Build Settings
1. In Xcode, select your project
2. Go to **Build Settings**
3. Set **Build Configuration** to **Release**
4. Set **Code Signing** to **Automatic**

#### 2. Archive Your App
1. Select **Any iOS Device** (not a simulator) as the destination
2. Go to **Product > Archive**
3. Wait for the archive to complete
4. The Organizer window will open automatically

#### 3. Validate Archive
1. In the Organizer, select your archive
2. Click **Validate App**
3. Fix any issues that appear
4. Common issues:
   - Missing app icon
   - Missing required capabilities
   - Code signing issues

#### 4. Distribute to App Store
1. In the Organizer, select your validated archive
2. Click **Distribute App**
3. Select **App Store Connect**
4. Choose **Upload**
5. Follow the wizard:
   - Select your team
   - Choose distribution options
   - Review and upload

### Phase 5: Submit for Review

#### 1. Complete App Store Listing
1. Go to App Store Connect
2. Select your app
3. Go to **App Store** tab
4. Complete all required fields:
   - Screenshots
   - Description
   - Keywords
   - Support URL
   - Privacy Policy URL

#### 2. Set Pricing and Availability
1. Go to **Pricing and Availability**
2. Choose:
   - **Price**: Free or Paid
   - **Availability**: All countries or specific regions
   - **Pre-order**: If applicable

#### 3. Submit for Review
1. Go to the **App Store** tab
2. Scroll to **App Review Information**
3. Fill in:
   - **Contact Information**: Your email/phone
   - **Demo Account**: If your app requires login (DueTrack doesn't)
   - **Notes**: Any special instructions for reviewers
4. Click **Add for Review**
5. Select your build
6. Answer export compliance questions
7. Click **Submit for Review**

### Phase 6: Review Process

#### Timeline
- **Initial Review**: 24-48 hours typically
- **Rejection**: If issues found, you'll get feedback
- **Approval**: App goes live immediately or on scheduled date

#### Common Rejection Reasons
1. **Missing Privacy Policy**: Must have a valid URL
2. **App Crashes**: Test thoroughly before submitting
3. **Guideline Violations**: Review App Store guidelines
4. **Incomplete Information**: Missing screenshots or descriptions
5. **Misleading Content**: Ensure descriptions match functionality

#### If Rejected
- You'll receive detailed feedback
- Fix issues and resubmit
- No additional cost for resubmissions

### Phase 7: After Approval

#### 1. App Goes Live
- App appears in App Store within 24 hours
- Users can download immediately
- You'll receive email confirmation

#### 2. Monitor Your App
- Check App Store Connect for:
  - Downloads
  - Ratings and reviews
  - Crash reports
  - Analytics

#### 3. Updates
- Make changes to your app
- Increment version number (e.g., 1.0.1)
- Create new archive
- Submit update through same process

## Quick Checklist

Before submitting, ensure:

- [ ] Apple Developer account ($99/year)
- [ ] App builds without errors
- [ ] App tested on real device
- [ ] App icon (1024x1024) added
- [ ] Screenshots for required device sizes
- [ ] App description written
- [ ] Privacy policy URL created
- [ ] Support URL created
- [ ] Bundle ID configured
- [ ] Code signing set up
- [ ] Archive created and validated
- [ ] App submitted to App Store Connect
- [ ] All App Store listing fields completed
- [ ] Submitted for review

## Resources

- **App Store Connect**: https://appstoreconnect.apple.com
- **Apple Developer**: https://developer.apple.com
- **App Store Review Guidelines**: https://developer.apple.com/app-store/review/guidelines/
- **Human Interface Guidelines**: https://developer.apple.com/design/human-interface-guidelines/

## Tips for Success

1. **Test Thoroughly**: Test on multiple devices and iOS versions
2. **Great Screenshots**: First impression matters
3. **Clear Description**: Explain what your app does clearly
4. **Respond to Reviews**: Engage with users
5. **Regular Updates**: Keep your app updated
6. **Marketing**: Promote your app on social media, your website, etc.

## Cost Summary

- **Apple Developer Program**: $99/year
- **App Store Submission**: Free (included with developer account)
- **App Updates**: Free
- **Total First Year**: $99

Good luck with your App Store submission! 🚀

