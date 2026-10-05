# BBC Operations Multi-Site Publishing Script
# This script builds and deploys all 5 platforms to their unique URLs.

Write-Host "🚀 Starting Multi-Site Build and Deploy Process..." -ForegroundColor Cyan

# 1. Clean the project
Write-Host "🧹 Cleaning project..." -ForegroundColor Gray
flutter clean

# 2. Get dependencies
Write-Host "📦 Getting dependencies..." -ForegroundColor Gray
flutter pub get

# 3. Build Platforms
Write-Host "🏗️ Building Master Dashboard (Combined)..." -ForegroundColor Green
flutter build web -t lib/main.dart --output build/web --release

Write-Host "🏗️ Building Onboarding Only..." -ForegroundColor Green
flutter build web -t lib/main_onboarding.dart --output build/web_onboarding --release

Write-Host "🏗️ Building Support Only..." -ForegroundColor Green
flutter build web -t lib/main_support.dart --output build/web_support --release

Write-Host "🏗️ Building Training Only..." -ForegroundColor Green
flutter build web -t lib/main_trainee.dart --output build/web_trainee --release

Write-Host "🏗️ Building API Tool Only (Old URL)..." -ForegroundColor Green
flutter build web -t lib/main_api_tool.dart --output build/web_api --release

# 4. Apply Targets (Ensuring targets are set before deploy)
Write-Host "🔗 Verifying Firebase Targets..." -ForegroundColor Gray
firebase target:apply hosting master bbc-operations-dashboard
firebase target:apply hosting onboarding bbc-ops-onboarding
firebase target:apply hosting support bbc-ops-support
firebase target:apply hosting training bbc-ops-training
firebase target:apply hosting apitool bbc-api-tool

# 5. Deploy to Hosting
Write-Host "☁️ Deploying all sites to Firebase Hosting..." -ForegroundColor Cyan
firebase deploy --only hosting

Write-Host "✅ PUBLISHING COMPLETE!" -ForegroundColor Cyan
Write-Host "URLs are live at:"
Write-Host "- Master Dashboard (Combined): https://bbc-operations-dashboard.web.app"
Write-Host "- Onboarding: https://bbc-ops-onboarding.web.app"
Write-Host "- Support: https://bbc-ops-support.web.app"
Write-Host "- Training: https://bbc-ops-training.web.app"
Write-Host "- API Tool (Old URL): https://bbc-api-tool.web.app"
