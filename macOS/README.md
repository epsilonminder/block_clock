# Block Clock for macOS

昔のHTML時計を、Xcodeなしで動く軽量なmacOSメニューバーアプリにしたものです。

## ビルド

```sh
chmod +x build.sh
./build.sh
```

完成したアプリは `dist/Block Clock.app` に作成されます。

## 操作

- 時計をドラッグ: 移動
- 時計をダブルクリック: 終了
- メニューバーの `◷`: 表示／非表示、最前面表示、数字表示、表示サイズの切り替え、終了

位置は終了時に保存されます。
