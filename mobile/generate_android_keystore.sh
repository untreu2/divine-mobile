#!/bin/bash
# ABOUTME: Script to generate Android release keystore for OpenVine app
# ABOUTME: Guides user through the keystore generation process

echo "🔐 Android Release Keystore Generation for OpenVine"
echo "=================================================="
echo ""
echo "This script will help you generate a release keystore for signing your Android app."
echo "IMPORTANT: Keep this keystore file and passwords SECURE. You'll need them for all future updates!"
echo ""
echo "You'll be asked for:"
echo "1. Keystore password (minimum 6 characters) - SAVE THIS!"
echo "2. Key password (can be same as keystore password) - SAVE THIS!"
echo "3. Your name (CN)"
echo "4. Organizational unit (OU) - e.g., 'Mobile Development'"
echo "5. Organization (O) - e.g., 'OpenVine'"
echo "6. City/Locality (L)"
echo "7. State/Province (ST)"
echo "8. Country code (C) - e.g., 'US'"
echo ""
echo "Press Enter to continue..."
read

# Generate the keystore
keytool -genkey -v \
    -keystore ~/android-keys/openvine/upload-keystore.jks \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -alias upload

echo ""
echo "✅ Keystore generated successfully!"
echo ""
echo "📁 Keystore location: ~/android-keys/openvine/upload-keystore.jks"
echo ""
echo "⚠️  IMPORTANT REMINDERS:"
echo "1. NEVER commit the keystore file to version control"
echo "2. NEVER share the keystore file publicly"
echo "3. SAVE your passwords in a secure password manager"
echo "4. BACKUP the keystore file - you'll need it for all future app updates"
echo ""
echo "Next steps:"
echo "1. The script will create a key.properties file with your keystore info"
echo "2. Your app will be configured to use this keystore for release builds"