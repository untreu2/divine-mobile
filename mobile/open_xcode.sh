#!/bin/bash
# Open the iOS project in Xcode using the workspace (required for CocoaPods)

cd ios
if [ -d "Runner.xcworkspace" ]; then
  echo "Opening Runner.xcworkspace in Xcode..."
  open Runner.xcworkspace
else
  echo "ERROR: Runner.xcworkspace not found!"
  echo "Run 'cd ios && pod install' first"
  exit 1
fi
