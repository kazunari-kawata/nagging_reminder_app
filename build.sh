#!/bin/sh

SCHEME='nagging_reminder_app'
SIM_NAME='iPhone 17 Pro' # シミュレータ名
DESTINATION="platform=iOS Simulator,name=$SIM_NAME"
CONFIG='Debug' # 'Debug' or 'Release'
DERIVED_DATA_PATH='./build'
APP_NAME='nagging_reminder_app'
APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIG-iphonesimulator/$APP_NAME.app"
BUNDLE_ID='bridgesllc.co.jp.nagging-reminder-app'

CLEAN=''; [ "$1" = "clean" ] && CLEAN='clean'

# アプリのビルド
xcodebuild -scheme $SCHEME -destination "$DESTINATION" -configuration $CONFIG -derivedDataPath $DERIVED_DATA_PATH $CLEAN build

# シミュレータの起動
xcrun simctl boot "$SIM_NAME"

# Xcodeのシミュレータアプリケーションを開く
open -a Simulator

# シミュレータにアプリをインストール
xcrun simctl install booted "$APP_PATH"

# シミュレータでアプリを起動
xcrun simctl launch booted "$BUNDLE_ID"