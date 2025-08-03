#!/bin/bash
# ABOUTME: Script to increment the build number in pubspec.yaml for iOS/Android releases
# ABOUTME: Supports auto-increment or setting specific version/build numbers

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Navigate to project root
cd "$(dirname "$0")"

# Parse command line arguments
VERSION=""
BUILD=""
AUTO_INCREMENT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --version|-v)
            VERSION="$2"
            shift 2
            ;;
        --build|-b)
            BUILD="$2"
            shift 2
            ;;
        --auto|-a)
            AUTO_INCREMENT=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --auto, -a              Auto-increment build number"
            echo "  --version, -v VERSION   Set specific version (e.g., 1.0.0)"
            echo "  --build, -b BUILD       Set specific build number"
            echo "  --help, -h              Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --auto                    # Increment build number by 1"
            echo "  $0 --version 1.0.0           # Set version to 1.0.0"
            echo "  $0 --build 42                # Set build number to 42"
            echo "  $0 --version 1.0.0 --build 42 # Set both version and build"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Read current version from pubspec.yaml
CURRENT_VERSION_LINE=$(grep "^version:" pubspec.yaml)
CURRENT_FULL_VERSION=$(echo "$CURRENT_VERSION_LINE" | sed 's/version: //')
CURRENT_VERSION=$(echo "$CURRENT_FULL_VERSION" | cut -d'+' -f1)
CURRENT_BUILD=$(echo "$CURRENT_FULL_VERSION" | cut -d'+' -f2)

echo "📱 Current version: ${CURRENT_VERSION}+${CURRENT_BUILD}"

# Determine new version and build
if [[ "$AUTO_INCREMENT" == true ]]; then
    NEW_VERSION="$CURRENT_VERSION"
    NEW_BUILD=$((CURRENT_BUILD + 1))
    echo "🔄 Auto-incrementing build number..."
else
    # Use provided values or keep current
    NEW_VERSION="${VERSION:-$CURRENT_VERSION}"
    NEW_BUILD="${BUILD:-$CURRENT_BUILD}"
fi

# Update pubspec.yaml
NEW_FULL_VERSION="${NEW_VERSION}+${NEW_BUILD}"
sed -i.bak "s/^version: .*/version: ${NEW_FULL_VERSION}/" pubspec.yaml
rm pubspec.yaml.bak

echo -e "${GREEN}✅ Updated version to: ${NEW_FULL_VERSION}${NC}"

# Show what changed
echo ""
echo "📝 Changes:"
echo "  Version: $CURRENT_VERSION → $NEW_VERSION"
echo "  Build:   $CURRENT_BUILD → $NEW_BUILD"

# Update iOS Info.plist if needed (Flutter usually handles this automatically)
if [[ -f "ios/Runner/Info.plist" ]]; then
    echo ""
    echo "ℹ️  Note: Flutter will automatically update iOS CFBundleVersion during build"
fi

# Update Android build.gradle if needed (Flutter usually handles this automatically)
if [[ -f "android/app/build.gradle" ]]; then
    echo "ℹ️  Note: Flutter will automatically update Android versionCode during build"
fi

echo ""
echo -e "${YELLOW}💡 Next steps:${NC}"
echo "  1. Commit the version change: git add pubspec.yaml && git commit -m \"Bump version to ${NEW_FULL_VERSION}\""
echo "  2. Build for release: ./build_ios.sh release"
echo "  3. Upload to TestFlight via Xcode Organizer"