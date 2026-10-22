#!/usr/bin/env bash
# setup_firebase_and_fbid.sh
# This script copies Firebase configuration files into the Android and iOS directories
# and injects the Facebook App ID into the required manifest and plist files.
# It reports progress in 10% increments.

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_APP_DIR="$PROJECT_DIR/android/app"
IOS_RUNNER_DIR="$PROJECT_DIR/ios/Runner"

# Helper to print progress
function progress {
  echo "Progress: $1%"
}

progress 10
# Expect the Firebase config files to be placed in the "firebase" subdirectory of the project.
FIREBASE_DIR="$PROJECT_DIR/firebase"
GOOGLE_JSON="$FIREBASE_DIR/google-services.json"
PLIST_FILE="$FIREBASE_DIR/GoogleService-Info.plist"

if [[ ! -f "$GOOGLE_JSON" ]]; then
  echo "Error: $GOOGLE_JSON not found. Please download the Android firebase config (google-services.json) from the Firebase console and place it in $FIREBASE_DIR"
  exit 1
fi
if [[ ! -f "$PLIST_FILE" ]]; then
  echo "Error: $PLIST_FILE not found. Please download the iOS firebase config (GoogleService-Info.plist) from the Firebase console and place it in $FIREBASE_DIR"
  exit 1
fi

progress 30
# Copy Firebase config files
cp "$GOOGLE_JSON" "$ANDROID_APP_DIR/"
cp "$PLIST_FILE" "$IOS_RUNNER_DIR/"

progress 50
# Prompt for Facebook App ID if not supplied as env var
if [[ -z "$FB_APP_ID" ]]; then
  read -p "Enter your Facebook App ID: " FB_APP_ID
fi

# Validate non-empty
if [[ -z "$FB_APP_ID" ]]; then
  echo "Error: Facebook App ID cannot be empty"
  exit 1
fi

progress 70
# Replace placeholder in Android strings.xml
STRINGS_XML="$PROJECT_DIR/android/app/src/main/res/values/strings.xml"
if grep -q "YOUR_FACEBOOK_APP_ID" "$STRINGS_XML"; then
  sed -i "s/YOUR_FACEBOOK_APP_ID/${FB_APP_ID}/g" "$STRINGS_XML"
fi

# Replace placeholder in iOS Info.plist (both the plain ID and the fb<id> URL scheme)
INFO_PLIST="$PROJECT_DIR/ios/Runner/Info.plist"
if grep -q "YOUR_FACEBOOK_APP_ID" "$INFO_PLIST"; then
  sed -i "s/YOUR_FACEBOOK_APP_ID/${FB_APP_ID}/g" "$INFO_PLIST"
fi
# Update URL scheme entries that may look like fbYOUR_FACEBOOK_APP_ID
sed -i "s/fbYOUR_FACEBOOK_APP_ID/fb${FB_APP_ID}/g" "$INFO_PLIST"

progress 90
# Clean up any temporary files (none for now)

progress 100
 echo "Firebase configuration and Facebook App ID have been set up successfully."

# End of script