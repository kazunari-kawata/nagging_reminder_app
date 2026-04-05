# Baddger – Nagging Reminder App

しつこくアラートを出し続けるタスク管理アプリです。

---

## 必要な環境

| 項目                  | バージョン |
| --------------------- | ---------- |
| Xcode                 | 26.x 以上  |
| iOS Deployment Target | 26.2 以上  |
| Swift                 | 5.0        |

---

## シミュレーターでの起動方法

プロジェクトルートに `build.sh` というスクリプトが用意されています。  
このスクリプトを使うと、**ビルド → シミュレーター起動 → インストール → アプリ起動**まで一括で実行できます。

### 1. build.sh の設定を確認する

`build.sh` をテキストエディタ（または VS Code）で開き、以下の変数を環境に合わせて書き換えます。

```sh
SCHEME='nagging_reminder_app'          # Xcodeのスキーム名
SIM_NAME='iPhone 17 Pro'               # 起動したいシミュレーターの名前
CONFIG='Debug'                         # Debug or Release
APP_NAME='nagging_reminder_app'        # .app のファイル名（拡張子なし）
BUNDLE_ID='bridgesllc.co.jp.nagging-reminder-app'  # バンドルID
```

**利用可能なシミュレーター名の確認方法：**

```bash
xcrun simctl list devices
```

上記コマンドを実行すると、インストール済みのシミュレーター一覧が表示されます。  
`SIM_NAME` に設定する名前は、この一覧に表示される名前と **完全に一致** させてください。

---

### 2. スクリプトに実行権限を付与する（初回のみ）

ターミナルでプロジェクトのルートディレクトリに移動し、以下を実行します。

```bash
cd /path/to/nagging_reminder_app
chmod +x build.sh
```

---

### 3. ビルド & 起動

通常のビルド：

```bash
./build.sh
```

クリーンビルド（キャッシュを削除してビルドしたい場合）：

```bash
./build.sh clean
```

実行すると以下の順番で処理が進みます：

1. `xcodebuild` でアプリをビルド
2. シミュレーターを起動
3. Simulator アプリを前面に表示
4. ビルドしたアプリをシミュレーターにインストール
5. アプリを起動

---

### よくあるエラー

#### `xcode-select` 関連のエラーが出る場合

```bash
sudo xcode-select -switch /Applications/Xcode.app/Contents/Developer
```

#### `xcrun: error: unable to find utility "simctl"` が出る場合

Xcode の Command Line Tools が設定されていません。上のコマンドを実行してください。

#### シミュレーターが見つからないというエラーが出る場合

`SIM_NAME` に設定した名前が `xcrun simctl list devices` の表示と一致しているか確認してください。

---

## Xcode から直接起動する場合

`build.sh` を使わずに Xcode GUI から起動することもできます。

1. `nagging_reminder_app.xcodeproj` を Xcode で開く
2. ツールバーのデバイス選択から使用するシミュレーターを選択
3. `⌘R` でビルド＆起動

---

## バージョン情報

| 項目       | 値                                      |
| ---------- | --------------------------------------- |
| バージョン | 1.0.2                                   |
| ビルド番号 | 2                                       |
| Bundle ID  | `bridgesllc.co.jp.nagging-reminder-app` |
