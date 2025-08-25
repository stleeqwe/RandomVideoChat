#!/bin/bash
echo "🚨 완전 초기화 시작 (Xcode를 먼저 종료하세요!)"
read -p "Xcode를 종료했나요? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    # 강제 종료
    killall Xcode 2>/dev/null
    
    # 모든 DerivedData 삭제
    rm -rf ~/Library/Developer/Xcode/DerivedData/*
    
    # 캐시 삭제
    rm -rf ~/Library/Caches/com.apple.dt.Xcode
    
    # 시뮬레이터 리셋
    xcrun simctl shutdown all
    xcrun simctl erase all
    
    echo "✅ 완료! 이제 Xcode를 다시 실행하세요."
fi
