#!/bin/bash

echo "🧹 Xcode 빌드 캐시 완전 정리 시작..."

# 1. DerivedData 삭제
echo "📁 DerivedData 삭제 중..."
rm -rf ~/Library/Developer/Xcode/DerivedData/RandomVideoChat-*
rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex

# 2. 프로젝트 빌드 폴더 삭제
echo "📁 프로젝트 빌드 폴더 삭제 중..."
rm -rf build/
rm -rf *.xcodeproj/project.xcworkspace/xcuserdata/
rm -rf *.xcodeproj/xcuserdata/

# 3. 시뮬레이터 종료 및 초기화
echo "📱 시뮬레이터 정리 중..."
xcrun simctl shutdown all 2>/dev/null

# 4. Xcode 빌드 정리
echo "🔨 Xcode 빌드 정리 중..."
xcodebuild -scheme RandomVideoChat clean 2>/dev/null

# 5. CocoaPods 캐시 정리 (있는 경우)
if [ -f "Podfile" ]; then
    echo "🌱 CocoaPods 캐시 정리 중..."
    pod cache clean --all 2>/dev/null
fi

# 6. SPM 캐시 정리
echo "📦 Swift Package Manager 캐시 정리 중..."
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf ~/Library/org.swift.swiftpm

echo "✅ 캐시 정리 완료!"
echo ""
echo "이제 Xcode에서:"
echo "1. Xcode를 완전히 종료했다가 다시 실행"
echo "2. Product > Clean Build Folder (Shift+Cmd+K)"
echo "3. Product > Build (Cmd+B)"
echo ""
echo "또는 터미널에서:"
echo "xcodebuild -scheme RandomVideoChat -configuration Debug -sdk iphonesimulator build"