# アニメーション実装 デバッグログ

**日付:** 2026年4月9日
**ブランチ:** `feature/add-how-to-demo`
**ステータス:** 一時中断

---

## 要件

タスク完了・複製時に移動先がわかるよう、ゆっくりしたアニメーションを追加する：
- スワイプで完了 → カードが右にスライドして退出
- 移動先セクションへ左から右にスライドして挿入

---

## 実装した変更（ContentView.swift）

### 1. アニメーション本体
- `@Environment(\.accessibilityReduceMotion)` で reduceMotion 対応
- `taskMoveAnimation` = `.easeInOut(duration: 0.5)`（reduceMotion時は0）
- `onComplete` / `onDuplicate` を `withAnimation(taskMoveAnimation) { ... }` でラップ
- `.transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))` をカードに付与
- スワイプ完了時：`dragOffset = cardWidth + 50` で右方向にスライドアウト → 0.4秒後に `onComplete()` コールバック

### 2. その他の変更
- `LazyVStack` → `VStack` に変更（transition互換性のため）
- `.id()` にタスクの状態を含めてアニメーション発火を補助
- undo snackbar の表示/非表示にもアニメーション適用

---

## 発生した問題：実機でブランク画面（黒画面）

シミュレータではビルド成功・正常動作するが、**実機では画面が完全に黒/空白**になる。

---

## デバッグ経緯

### Phase 1: View Hierarchy 調査
- Xcode の View Hierarchy Debugger で確認
- `TransitionTraitKey` が TaskCardView に付与されていることを確認 → ビューツリー自体は存在
- **結論:** ビューは構築されているが画面に描画されていない

### Phase 2: LazyVStack → VStack 変更
- `LazyVStack` と `.transition()` の互換性問題を疑い `VStack` に変更
- **結果:** 改善なし

### Phase 3: debugPrint 追加（失敗）
- `let _ = debugPrint(...)` + `return` を `@ViewBuilder` の body に追加
- **発見:** `return` キーワードが `@ViewBuilder` DSL の解釈を壊す
  - Swift は `return` があると通常の関数戻り値として扱い、ViewBuilder DSL を無視する
  - ビューは構築されるが画面にマウントされない
- **教訓:** `@ViewBuilder` body 内で `return` は絶対に使わない

### Phase 4: debugPrint 全除去後もブランク画面継続
- debugPrint と return を全て除去してクリーンビルド
- **結果:** まだブランク画面 → debugPrint が原因ではなく、別の根本原因がある

### Phase 5: 初期化コード調査
- 全マネージャクラスの `init()` を調査（TaskManager, AppSettings, TimerManager, PurchaseManager, InterstitialAdManager, ReviewManager）
- TaskManager.load() で `tasks = decoded` → `didSet` → `save()` の二重書き込みを発見
- TimerManager も同様のパターン
- **結論:** UserDefaults の同期 I/O は重いが、ブランク画面の直接原因ではない

### Phase 6: `.transition()` 除去テスト
- `.transition(.asymmetric(...))` を除去
- **結果:** まだブランク画面（この時点で transition は原因ではないと判明）

### Phase 7: 安全なデバッグログ追加（成功パターン）
- `let _ = print(...)` を `var body: some View` 内（@ViewBuilder body）のみで使用 → OK
- `some View` を返す computed property（`tasksPageView`, `headerSection` 等）では `let _ = print()` が opaque return type エラーを起こす → `.onAppear {}` のみ使用
- 全箇所に `[DBG-APP]` / `[DBG-CV]` / `[DBG-CARD]` プレフィックス付きログを追加

### Phase 8: ログ分析で fullScreenCover 問題を特定
**コンソール出力:**
```
[DBG-APP] body evaluated: privacy=false tutorial=false tasks=0
[DBG-APP] fullScreenCover#1 (Privacy) get -> true
[DBG-APP] fullScreenCover#2 (Onboarding) get -> false
[DBG-CV] body: tab=0 tasks=0 editing=false showAdd=false showSettings=false showUndo=false showAdFree=false
```

**発見:**
- `privacy=false` → PrivacyNoticeView の fullScreenCover が `isPresented=true`
- しかし `PrivacyNoticeView.onAppear` が出力されない → 実際にはレンダリングされていない
- `ZStack.onAppear` も出力されない → **どのビューも画面にマウントされていない**
- **原因:** App に2つの `.fullScreenCover` + ContentView 内に1つ = 合計3つの fullScreenCover が同一ビュー階層にあり、実機で描画デッドロック

### Phase 9: fullScreenCover → if/else 条件分岐に変更
- App の2つの `.fullScreenCover` を `if/else if/else` で直接ビューを切り替える方式に変更
- **結果:** 画面が表示されるようになった✅

### Phase 10: OnboardingView のボタンでクラッシュ
- `if/else` パターンだと、`settings.tutorialCompleted = true` を設定した瞬間にビューツリーが完全に破棄・再作成される
- OnboardingView の `SwipeHintView` が `DispatchQueue.main.asyncAfter` で再帰的アニメーションを実行中のため、ビュー破棄時にクラッシュ

### Phase 11: 単一 fullScreenCover 方式に変更
- ContentView を常に背面に配置
- 1つの `.fullScreenCover` 内で Privacy/Onboarding を `if/else` 分岐
- `isPresented` = `!privacyAccepted || !tutorialCompleted`
- **結果:** 未検証（この時点で一時中断を決定）

---

## 学んだこと

### SwiftUI の制約
1. **`@ViewBuilder` body 内で `return` は使えない** — Swift が通常関数として解釈し、ViewBuilder DSL が無効になる
2. **`let _ = print()` は `var body: some View` 内では使えるが、`some View` を返す computed property では opaque return type エラーになる** — `.onAppear` を使う
3. **同一ビュー階層に複数の `.fullScreenCover` を置くと実機で描画デッドロックが発生する可能性がある** — シミュレータでは再現しない場合がある
4. **`if/else` でビューを切り替えるとビューツリーが完全に破棄・再作成される** — アニメーション中のビューがクラッシュする可能性

### デバッグ手法
- `[DBG-XXX]` プレフィックス付き print で階層的にログを追跡
- `.onAppear` がコールされるかどうかでビューが実際にマウントされたかを判定
- `fullScreenCover` の `isPresented` の `get` にログを仕込んで呼び出し状況を確認

---

## 次回再開時の推奨アプローチ

1. **App の構造を先に安定化** — fullScreenCover の競合問題を完全解決してから着手
2. **アニメーションは `.transition()` ではなく `matchedGeometryEffect` か手動 offset** — transition は ForEach + 条件分岐との相性が悪い
3. **SwipeHintView の再帰アニメーションを `TimelineView` か `.onAppear`+`repeatForever` に変更** — DispatchQueue の再帰呼び出しはビュー破棄時に安全でない
4. **実機テストを頻繁に** — シミュレータでは再現しない問題が多い
