Maeve インストールガイド
========================

動作環境
---------
Maeve は現在 Windows 環境のみ対応しています

ダウンロード
------------
https://github.com/henshiru/maeve から適当な方法で入手してください。

Zipで取るのが一番簡単でしょう。(https://github.com/henshiru/maeve/zipball/master)

環境構築
-------------

### Ruby 1.8 のインストール
Ruby 1.8 (1.9には対応していないので注意してください) を  http://rubyinstaller.org からダウンロードしてインストールしてください。

インストール中に表示される "Associate .rb and .rbw files with this Ruby installation" にはチェックを入れておくとmain.rbをダブルクリックするだけで起動できるので便利です。

### gem (wxruby と ruby-opengl) のインストール
ruby-opengl の適当なバージョン(例: ruby-opengl-0.60.1-i386-mswin32.gem)を
 http://rubyforge.org/frs/?group_id=2103 からダウンロードしてください。

スタート->プログラム->Ruby 1.8.x-xxxx->Start Command Prompt with Ruby

    gem install wxruby
    cd <ruby-openglをダウンロードしたディレクトリ>
    gem install ruby-opengl-0.60.1-i386-mswin32.gem

起動
------

lib/main.rb をダブルクリックしてください
