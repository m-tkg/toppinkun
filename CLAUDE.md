# CLAUDE.md — Toppinkun

このリポジトリで作業する際のガイド。

**メニューバー常駐アプリ（kun シリーズ）共通の方針は、同梱の [`CLAUDE_base.md`](./CLAUDE_base.md) を参照**
（Swift Package 構成・日英ローカライズ・アップデート・kunkit 連携・リリース手順・ブランチ運用など）。
本ファイルには Toppinkun 固有の事項のみを記す。共通方針を変えるときは
[kun-template](https://github.com/m-tkg/kun-template) の `CLAUDE_base.md`（canonical）を編集し、本リポジトリはそれに追従する。

---

# Toppinkun 固有事項

## 概要
ユーザーが指定したウィンドウを常に最前面に表示するメニューバー常駐アプリ。bundle ID は `com.mtkg.toppinkun`。

## 機能
- **ホットキーで固定/解除**（既定 `⌃⌘T`、設定「固定」タブで変更可）: 押下時の前面アプリの最前面ウィンドウを固定する。
  同じウィンドウで押すと解除、別ウィンドウで押すと付け替え。**同時に固定できるのは1枚**。
- **ミラー表示**: 他アプリが前面の間、固定ウィンドウのライブ映像を `.floating` パネルに表示する。
  固定中アプリ自身が前面のときはパネルを隠し、本物を直接操作させる。
- **クリックで前面化**: ミラーをクリックすると固定中アプリをアクティブ化し、対象ウィンドウを raise する。
- **自動解除・追従**: ウィンドウが閉じられる/アプリが終了すると解除。移動・リサイズには 0.25 秒間隔で追従。
- **メニュー**: 固定/解除（ホットキー表示付き）・固定中のウィンドウ名・「固定を解除」。

## 技術メモ
- **AX の raise では最前面にできない（実機確認済み）**。背面アプリのウィンドウに `kAXRaiseAction` を実行しても
  前面アプリの最上位ウィンドウの直下までしか上がらない。他アプリのウィンドウレベルを変える公開 API も無い
  （SIP 無効が前提の scripting addition 方式は不採用）。そのため ScreenCaptureKit のミラー方式を採る。
- 構成:
  - `ToppinkunCore/PinState.swift`: 固定対象と「ミラーを出す/隠す/解除する」判定の純粋な状態機械（TDD）。
  - `PinController`: OS イベント（前面アプリ変化・アプリ終了・追従タイマー）を `PinState` へ入力し、出力を実行する。
  - `WindowLocator`: `CGWindowList` で前面ウィンドウ・ウィンドウ情報を取得（座標は左上原点。AppKit へ変換して使う）。
  - `WindowMirrorStream`: `SCContentFilter(desktopIndependentWindow:)` で1枚をキャプチャ（30fps）。
    **キャプチャはミラー表示中（他アプリが前面の間）だけ動かす**。キャプチャ中は macOS が対象ウィンドウのタイトルバーに
    紫の「共有中」バッジを重ねて信号機ボタンを塞ぐため（消す公開 API は無い）。再表示時は停止時の最終フレームを先に出す。
  - `MirrorPanel`: 非アクティブ化・枠なし・全 Space の `NSPanel`。フレームの `IOSurface` を layer に直接載せる。
  - `WindowActivator`: CGWindowID と AX 要素を対応付ける公開 API が無いため、**フレーム一致**で AX ウィンドウを特定して raise。
- 権限（TCC）:
  - **画面収録（必須）**。`CGRequestScreenCaptureAccess` だけでは新しい macOS でシステム設定の一覧に載らないことがあるため、
    `SCShareableContent` も呼んで登録させる。許可後はアプリの再起動が必要。
  - **アクセシビリティ（任意）**。無くてもアクティブ化はするが、対象ウィンドウが前面に来ないことがある。
  - ローカルビルドは bundle ID が `.local` で別扱いのため、本番とは別に許可が必要。
- 既知の制約: ミラーは映像なので操作はクリックで本物を前面化してから。固定中アプリが前面のとき、同アプリの別ウィンドウに
  隠れうる。最小化中は最後のフレームが残る。

## Kuntraykun 連携（実装済み・kunkit 利用）
- `KuntraykunBridge`（kunkit の `KunIntegrationBridge`）を標準配線で使用。
  `StatusBarController.makeKuntraykunBridge()` → `AppDelegate` で `start()`。
- v2: アイコンは `KuntraykunIconExport.export(_:)` で書き出し済み（アイコンを差し替える箇所を
  追加したら、その全てで export し直すこと）。
- v3: 更新有無は `kuntraykunBridge?.reportUpdate(_:)` で通知済み。
- v4: メニュー文言の変化は `onMenuContentChanged` → `exportMenuSnapshot()` で再書き出し済み
  （メニュー項目を動的に変える機能を足したら、同じ配線に乗せる）。
