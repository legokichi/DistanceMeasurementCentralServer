何書いていいのかわからないから徒然なるままに書き出してみよう。

えーとまず、このシステムはなにか、について。

このリポジトリにあるコードはノートパソコンやスマートフォンなどのマイクとスピーカを備え、
ウェブブラウザが動き、ネットワークにつながるスマートデバイスをアレイ化し同期的に制御するためのものである。
アレイ化し同期的に制御、とはどういうことかというと、一例を挙げるならば、
スマートデバイスの持っているスピーカを同期的に制御することで、
複数のスマートデバイスをまとめてスピーカアレイシステムとして動かすことができる。
また、マイクロホンアレイを構築して、音源分離などができる。
などの用途を目指している。
というわけで、このライブラリはスマートデバイス間での時刻的同期を実現する。
具体的は、各スマートデバイスのWebBrowserのAudioContextのcurrentTimeの、相対的なズレを計測する。
以下にその概要を説明しよう。