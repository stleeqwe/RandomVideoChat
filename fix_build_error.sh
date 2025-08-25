#!/bin/bash

echo "🔧 Xcode 빌드 오류 해결 스크립트"
echo "================================"
echo ""

# 1. Xcode 종료
echo "1️⃣ Xcode 종료 중..."
killall Xcode 2>/dev/null || echo "   Xcode가 실행 중이지 않습니다"
sleep 1

# 2. DerivedData 삭제
echo "2️⃣ DerivedData 삭제 중..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# 3. 프로젝트 관련 파일 정리
echo "3️⃣ 프로젝트 파일 정리 중..."
rm -rf RandomVideoChat.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
rm -rf RandomVideoChat.xcodeproj/xcuserdata/
rm -rf RandomVideoChat.xcodeproj/project.xcworkspace/xcuserdata/

# 4. SPM 캐시 정리
echo "4️⃣ Swift Package Manager 캐시 정리 중..."
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf ~/Library/org.swift.swiftpm

# 5. Xcode 캐시 정리
echo "5️⃣ Xcode 캐시 정리 중..."
rm -rf ~/Library/Caches/com.apple.dt.Xcode

# 6. 빌드 폴더 정리
echo "6️⃣ 빌드 폴더 정리 중..."
rm -rf build/

# 7. 패키지 의존성 재설정
echo "7️⃣ 패키지 의존성 재설정 중..."
xcodebuild -resolvePackageDependencies -project RandomVideoChat.xcodeproj > /dev/null 2>&1

echo ""
echo "✅ 완료!"
echo ""
echo "다음 단계:"
echo "1. Xcode를 다시 실행"
echo "2. RandomVideoChat.xcodeproj 열기"
echo "3. Product > Clean Build Folder (Shift+Cmd+K)"
echo "4. Product > Build (Cmd+B)"
echo ""
echo "또는 터미널에서:"
echo "xcodebuild -scheme RandomVideoChat -configuration Debug build"