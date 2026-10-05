#!/bin/zsh
# macOS のシステム設定を defaults コマンドで適用する
# 反映にはログアウト or 再起動が必要なものがある
set -eu

echo "==> 外観"
# ダークモード
defaults write -g AppleInterfaceStyle -string Dark
# アイコンとウィジェットのスタイル（ダーク）
defaults write -g AppleIconAppearanceTheme -string RegularDark

echo "==> キーボード"
# キーのリピート速度（設定アプリの最速 = 2）
defaults write -g KeyRepeat -int 2
# リピート入力認識までの時間（設定アプリの最短 = 15）
defaults write -g InitialKeyRepeat -int 15

# 修飾キーの割り当て（内蔵キーボード）
#   キーコード: 0x700000000 + HID Usage ID
#     Caps Lock  = 0x39 -> 30064771129
#     左 Control = 0xE0 -> 30064771296
#     右 Control = 0xE4 -> 30064771300
#     左 Option  = 0xE2 -> 30064771298
#     右 Option  = 0xE6 -> 30064771302
#   割り当て:
#     左 Control -> 左 Option
#     右 Control -> 右 Option
#     Caps Lock  -> 右 Control
mapping() {
  echo "<dict><key>HIDKeyboardModifierMappingDst</key><integer>$1</integer><key>HIDKeyboardModifierMappingSrc</key><integer>$2</integer></dict>"
}

# 内蔵キーボードの VendorID / ProductID を取得（機種によって異なるため）
kb_info=$(ioreg -r -c AppleHIDKeyboardEventDriverV2 -d1 | grep -A20 '"Product" = "Apple Internal Keyboard')
vendor_id=$(echo "$kb_info" | awk -F' = ' '/"VendorID"/ {print $2; exit}')
product_id=$(echo "$kb_info" | awk -F' = ' '/"ProductID"/ {print $2; exit}')

if [[ -n "$vendor_id" && -n "$product_id" ]]; then
  defaults -currentHost write -g "com.apple.keyboard.modifiermapping.${vendor_id}-${product_id}-0" -array \
    "$(mapping 30064771298 30064771296)" \
    "$(mapping 30064771302 30064771300)" \
    "$(mapping 30064771300 30064771129)"
  echo "    内蔵キーボード (${vendor_id}-${product_id}) に修飾キー設定を適用しました"
else
  echo "    内蔵キーボードが見つからないため修飾キー設定をスキップしました" >&2
fi

echo "==> ウィジェット"
# デスクトップにウィジェットを表示する（0 = 表示）
defaults write com.apple.WindowManager StandardHideWidgets -int 0
# ステージマネージャ使用時にウィジェットを表示する（0 = 表示）
defaults write com.apple.WindowManager StageManagerHideWidgets -int 0

echo "==> Finder"
# すべてのファイル名拡張子を表示
defaults write -g AppleShowAllExtensions -bool true
killall Finder

echo "==> メニューバー"
# ディスプレイ（18 = メニューバーとコントロールセンターに表示）
defaults -currentHost write com.apple.controlcenter Display -int 18
# キーボードの輝度（2 = メニューバーに表示、8 = 表示しない）
defaults -currentHost write com.apple.controlcenter KeyboardBrightness -int 2
killall ControlCenter

echo "完了。キーボードと外観の設定はログアウト後に反映されます。"
