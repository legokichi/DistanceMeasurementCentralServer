# 位置推定と同期手法
## 問題設定
複数のスマートデバイスのスピーカを使って音場制御するには、
  デバイスの位置と同期が必要であるが、
  位置に関しては相対的な位置関係が得られれば良い。
また、
  機器間の相対距離がわかれば、
  非計量多次元尺度法(non-metric MDS)を用いて
  相対的な位置関係を推定することができる。
そして、
  機器間の同期は
  相対距離の計測と同時にできる。
これらのことを以下に示す。

## 相対距離の計測
信号伝播による測距は、
  基本的には三角測量の原理を利用している。
すなわち、
  三角形のある一辺の長さと二つの頂点の角度、
  二つの辺の長さと一つの頂点の角度、
  あるいは三つの辺の長さのいずれかが分かれば相対位置が算出できる。
受信信号の到来角度、
  つまり到来方向(DOA; direction of arrival, AOA: angle of arrival)を求めるには、
  指向性を持つ受信機を回転させて角度を求める通常のレーダーのほか、
  大量の同期した受信機を等間隔に並べ、受信機ごとの信号の到来時刻差(TDOA; Time Difference Of Arrival)から
  到来角度を求めるフェーズドアレイ(Phased Array)システムがある。
しかしながら、
  これら手法は、
  指向性のあるアンテナをその場で能動的に回さなければならないため、
  あるいは予め同期している必要があるため、
  本研究のようなスマートデバイスを多数使うシステムでは角度情報を直接的に得られない。
そのため、機器間の相対距離を基に位置を推定していく。

レーダーやソナーなどの波動の伝播を用いて機器間の距離を測るには、
  大きく分けて3つの方法がある。
第一の手法は、
  信号の時間差を利用するものである。
パルスを放出し、
  そのパルスが対象に反射し返ってくるまでの時間差(TOA: Time of Arrival)を用いて距離を算出する手法である。
  この代表例として、船舶用レーダーや魚群探知機がある。
また、
  パルスの反射の代わりに対象に取り付けられたアンテナを使って信号を増幅して返す、二次レーダーと呼ばれる手法もある。
こちらの代表例としては、
  航空機用の距離測定装置(disrance measuring equipment: DME)がある。
他に、
  発信側の位置を固定したアンカーノードからの信号の到来時間から距離を算出する仕組みもあり\cite{大槻知明}、
  これに基づいた方法として、GPSや潜水艇用測位装置\cite{中西俊之,Syed}がある。
```
\bibitem{大槻知明}
大槻知明.
"位置推定技術."
信学技報 (2009): 1-5.
```
```
中西俊之.
"6500m 潜水調査船システムの超音波技術."
日本音響学会誌 52.2 (1996): 131-136.
```
```
Syed, Affan A., and John S. Heidemann.
"Time Synchronization for High Latency Acoustic Networks."
INFOCOM. 2006.
```

第二の手法は、
  信号の位相差を利用するものである。
  固定周波数のトーン信号を対象へ向けて送信し、対象もこの信号を受信し、その波の数から距離を検出する手法がある。
  この手法は長距離でも極めて高精度に距離が計測できるため、
  人工衛星や惑星探査機の制御、干渉計などで使われている\cite{樊春明}。
```
\bibitem{樊春明}
樊春明, and 安田明生.
"M 系列を測距信号とした VSAT による衛星測距."
電子情報通信学会総合大会講演論文集 1995.1 (1995): 171.
```
第三の手法は、
  信号の強度(Received signal strength indication : RSSI)を利用するものである。
これは、
  三次元自由空間に球面波として放出された信号のエネルギーは、
  逆二乗則に基づく距離減衰を起こすという性質を用いている\cite{大槻知明}。
この手法は、
  簡単におおまかな位置がわかるため、
  Bluetooth Low Energyなどを用いたセンサネットワークや
  屋内での大まかな位置測位手法として利用されている\cite{大槻知明}。

提案手法では、
  実装の容易さ、測距にかかる時間、そして必要な精度を満たすことから、
  端末のスピーカとマイクロホンを利用したTOAによる二次レーダーにて測距を行う。

## 質問信号と応答信号の時間差による測距と同期
提案システムで利用している測距手法を示す。

スピーカとマイクロホンを備えたスマートデバイスAとBがあるとする。
デバイスAはデバイスA内時刻$t_0$に質問信号を放出する。
デバイスBはその信号をデバイスB内時刻$t_1$に観測し、
その後、時刻$t_2$にて応答信号を放出する。
デバイスAはその信号をデバイスA内時刻$t_3$に観測する。
音速$c$を仮定すると以下の式が成り立つ。
$$
t_0' = t_1 - \frac{(t_3 - t_0) - (t_2 - t_1)}{2}\\
d_{AB} = \frac{(t_3 - t_0) - (t_2 - t_1)}{2c}
$$

$t_0'$はデバイスAが信号を放出した時のデバイスB内時刻であり、$d_{AB}$はデバイスAB間の距離である。

![Two-way communication between nodes](clock_synchronization.png)

この手法は２端末間の同期と測距が同時にできるため、
  電波によるセンサネットワーク\cite[etc.]{Ganeriwal,Peng}や、
  ワイヤレスアコースティックセンサネットワークにも利用することが提案されている\cite{Hoflinger}。
```
Peng, Chunyi, et al.
"Beepbeep: a high accuracy acoustic ranging system using cots mobile devices."
Proceedings of the 5th international conference on Embedded networked sensor systems. ACM, 2007.
```
```
\bibitem{Ganeriwal}
Ganeriwal, Saurabh, Ram Kumar, and Mani B. Srivastava.
"Timing-sync protocol for sensor networks."
Proceedings of the 1st international conference on Embedded networked sensor systems. ACM, 2003.
```
```
\bibitem{Hoflinger}
Hoflinger, Fabian, et al.
"Acoustic self-calibrating system for indoor smartphone tracking (assist)."
Indoor Positioning and Indoor Navigation (IPIN), 2012 International Conference on. IEEE, 2012.
```

## 非計量多次元尺度法による相対位置推定
相対距離がわかれば、多次元尺度法で相対位置も求まる\cite{柴田一暁,小野順貴}。
多次元尺度法(MDS; Multi Dimensional Scaling)は、高次元のデータを低次元に縮約する手法である。
MDS法は、何らかの測度に基づくデータ間の距離を元に高次元データを低次元のユーグリッド空間に再配置する。
特に二次元に次元縮約することで、高次元データを散布図として表現できるようになる。
距離の公理を満たすデータに対しては代数的に解くことができる計量多次元尺度法(metric MDS)がある。
しかし、誤差あるいは距離が計測できない場合などの距離の公理が成り立たない場合はこれは使えない\cite{小松潤也}。
このようなデータには数値計算的に多次元尺度法を適用できる非計量多次元尺度法(non-metric MDS)が提案されている\cite{GUTTMAN,KRUSKAL}。
```
\bibitem{小松潤也}
小松 潤也,
"センサ位置推定における誤差最小化法と多次元尺度構成法の性能比較,"
千葉大学 工学部 都市環境システム学科 平成25年度 卒業論文.
```
```
\bibitem{Guttman}
Guttman, Louis.
"A basis for scaling qualitative data."
American sociological review (1944): 139-150.
```
```
\bibitem{KRUSKAL}
KRUSKAL, J. B.
"Non-metric multidimensional scaling: A numerical method."
Psychometrika, 1964, 29, 115129. (b)
```
非計量MDS法によって端末間の相対位置を求めるには、
  端末間の計測距離を$d_{ij}$、
  空間上の推定位置を$\hat{x}_i$とすると、
  それらの二乗誤差をストレス関数と名付けられた目的関数として定義し、
  ストレス関数を最小化するような$\hat{x}_i$を勾配法(最急降下法)によって解く\cite{島村和希}。

$$
\begin{align}
\\
& S_{tress} \overset{\mathrm{def}}{=}
\sqrt{
  \frac
  {\sum_{i=1}^N \sum_{j \in M(i)} (\|\hat{x}_i - \hat{x}_j\| - d_{ij})^2}
  {\sum_{i=1}^N \sum_{j \in M(i)} d_{ij}^2}
}\\
\\
\end{align}
$$
分母は階の収束を防ぐためである。
ここで$M(i)$は端末$i$が相対距離を計測できた端末の集合を表す\cite{島村和希}。
```
\bibitem{島村和希}
島村 和希,
"センサの相対位置推定のための最適化手法,"
千葉大学 大学院工学研究科 建築・都市科学専攻 都市環境システムコース 平成24年度 修士論文.
```
端末$i$の$n$回目の位置推定値をを$\hat{x}_i(n) $として表すと、最急降下法による更新式は以下のようになる。

$$
\begin{align}
\hat{x}_i (n + 1) & = \hat{x}_i (n) +
\left. \alpha \frac{\partial S_{tress}}{\partial \hat{x}_i} \right|_{\hat{x}_i = \hat{x}_i (n)}\\
\\
\frac{\partial S_{tress}}{\partial \hat{x}_i }
& = \left( \sum_{i=1}^N \sum_{j \in M(i)} d_{ij}^2 \right)^{-\frac{1}{2}}
    \frac{\partial}{\partial \hat{x}_i }
    \left(
      \sum_{i=1}^N \sum_{j \in M(i)} (\|\hat{x}_i - \hat{x}_j\| - d_{ij})^2
    \right)^{\frac{1}{2}} \\
& = \left( \sum_{i=1}^N \sum_{j \in M(i)} d_{ij}^2 \right)^{-\frac{1}{2}}
    \frac{1}{2}\left( \sum_{i=1}^N \sum_{j \in M(i)} (\|\hat{x}_i - \hat{x}_j\| - d_{ij})^2  \right)^{-\frac{1}{2}}
    \sum_{j\in M(i)} \frac{\partial (\|\hat{x}_i - \hat{x}_j\| - d_{ij})^2 }{\partial \hat{x_i}} \\
& = \left( \sum_{i=1}^N \sum_{j \in M(i)} d_{ij}^2 \right)^{-\frac{1}{2}}
    \frac{1}{2}\left( \sum_{i=1}^N \sum_{j \in M(i)} (\|\hat{x}_i - \hat{x}_j\| - d_{ij})^2  \right)^{-\frac{1}{2}}
    2 \sum_{j\in M(i)} (\|\hat{x}_i - \hat{x}_j\| - d_{ij}) \frac{\partial \|\hat{x}_i - \hat{x}_j\|}{\partial \hat{x_i}}\\
& = \left( \sum_{i=1}^N \sum_{j \in M(i)} d_{ij}^2 \right)^{-\frac{1}{2}}
    \left( \sum_{i=1}^N \sum_{j \in M(i)} (\|\hat{x}_i - \hat{x}_j\| - d_{ij})^2  \right)^{-\frac{1}{2}}
    \sum_{j\in M(i)} \left( 1 - \frac{d_{ij}}{\|\hat{x}_i - \hat{x}_j\|} \right)(\hat{x}_i - \hat{x}_j)
\end{align}
$$

ここで$\alpha$は最急降下法におけるステップ幅である。

このストレス関数の値の適合度は以下の表で判断する\cite{KRUSKAL2}。
```
\bibitem{KRUSKAL2}
KRUSKAL, J. B.
"Multidimensional scaling by optimizing goodness of fit to a non-metric hypothesis."
Psychometrika, 1964, 29, l-27. (a)
```

|ストレス関数の値|適合の程度|
|-|-|-|
|0.200|良くない適合|
|0.100|悪くない適合|
|0.050|良い適合|
|0.025|非常に良い適合|
|0.000|完全に適合|

アンカーノードを持たない場合、相対的な位置関係のみが推定可能であり、絶対的な位置や向きを決めることはできない\cite{島村和希}。
つまり、並進や回転、鏡像になり得る\cite{小野順貴}。

![mdsの動作原理の図解っぽいの]()

以上の通り、端末間の相対距離がわかれば、非計量MDS法によって端末間の相対位置が推定できる。

## 信号検出
TOAによって距離を計測するにはパルス信号の到来時間を正しく検出する必要がある。
受信した変調信号から必要な信号を検出する機構を検波という。
検波では
  受信変調波と周波数位相の一致した基準搬送波を再生し、
  これを受信変調波と掛け合わせて復調する
  相関検波という手法がある。
信号系列間の相関関数(correlation function)が系列の乱雑さやシステム性能を表す指標となる。
系列長$N$の二つの信号系列をa(t)とb(t)とすると、位相ずれ$\tau$、$b^*$を複素共役として
$$
R_{ab}(\tau) = \sum_{i=0}^{N-1}a(i+\tau)b^*(i)
$$
と定義する。
ここで、$a = b$の場合を自己相関数と呼び、$a\neq b $の場合を相互相関関数と呼ぶ。




![ここに同期検波回路のブロック線図](block_diagram.png)

* 相関検出器(coherent detection)
* 最適受信機
  * 整合フィルタ
  * 周波数軸上でのたたみ込み積分（相互相関）

![ここに相関検波回路のブロック線図](block_diagram.png)

* 相関検出器もここで説明







チャープ信号の帯域は可能な限り全体を使った。なぜならば、端末ごとにスピーカやマイクロホンの特性が異なるため、CDMAのように端末ごとに周波数を割り振るやり方では、ある端末には再生も検出もできない帯域を割り当ててしまうことがあるためである。
  * 単一チャープ信号のみでは精度が上がらない上、再生時間が長くなるため、個々のチャープ信号は短くし帯域を広げたのち、バーカー符号13を使いパルスを圧縮した。






### TSP
音響の世界ではインパルス応答の計測にTSP(time stretched pulse)
と呼ばれる周波数変調をかけた正弦波を使うことが多い\cite{Suzuki,守谷直也,金田豊}。
```
\bibitem{Suzuki}
Suzuki, Yôiti, et al.
"An optimum computer‐generated pulse signal suitable for the measurement of very long impulse responses."
The Journal of the Acoustical Society of America 97.2 (1995): 1119-1123.
```
```
\bibitem{守谷直也}
守谷直也, and 金田豊.
"雑音に起因する誤差を最小化するインパルス応答測定信号."
日本音響学会誌 64.12 (2008): 695-701.
```
```
\bibitem{金田豊}
金田豊.
"インパルス応答測定信号と測定誤差."
日本音響学会誌 69.10 (2013): 549-554.
```
これは、時間と共に周波数が上昇（又は下降）するような正弦波信号である。
インパルス応答測定用のインパルス信号は本来$t=0$にのみ全周波数成分に値を持つような信号が望ましい。
![](inpulse_responce.png)

TSPはそのようなTSPよりも継続時間が長くエネルギーが大きいため、
高いSN比でインパルス応答を計測できるという特徴がある\cite{音響工学基礎論}。
```
\bibitem{音響工学基礎論}
飯田一博.
"音響工学基礎論."
コロナ社 (2012/02).
```

TSP信号は、単位パルスのフーリエ変換の位相を周波数の２乗に比例して増加させたものを逆フーリエ変換して作成する。

$$
S(k) = \begin{cases}
  \exp(\frac{-j \pi k^2}{N}) & 0 \leq k \leq \frac{N}{2} \\
  S^*(N - k)                 & \frac{N}{2} \lt k \lt N
\end{cases}
$$
$j$は虚数単位、$*$は複素共役、$N$は2の冪乗である。
これはインパルスパルスを時間方向へ引き伸ばす技術であると言える。

しかしながら時間方向へ信号を引き伸ばすと後述するように時間分解能が下がるため、
  パルス幅の長いTSPは距離計測には向かない。

### Chirp信号
一方、レーダーの世界ではChirp信号と呼ばれるパルス圧縮技術が使われることが多い\cite{宇宙における電波計測と電波航法}。
```
\bibitem{宇宙における電波計測と電波航法}
高野 忠, 柏本 昌美, 佐藤 亨, 村田 正秋
"宇宙における電波計測と電波航法"
コロナ社 (2000/09)
```
パルスの送信時間とパルスの反射波との時間差から対象との距離を計測するパルスレーダでは、
  できるだけ幅の狭い大電力パルスを用いれば探知距離は増大しその上距離分解能を高めることができる。
しかしながら
  そのような短い時間に大電力を要するパルスは回路にダメージを与えたり効率が悪いなどの問題がある。
そのため
  信号を周波数方向へ引き伸ばすことで、信号の時間分解能を高め、SN比を高めようというのがChirp信号である。
Chirp信号の分解能はパルス幅ではなく帯域幅の逆数によって決まる\cite{アコースティックイメージング}。
```
\bibitem{アコースティックイメージング}
アコースティックイメージング
```
圧縮後の帯域幅を$f$、パルス長を$T$とすると、
  圧縮前に比べて振幅が$\sqrt{T\delta f}$倍、
  パルス幅は$1/T\delta f $倍になる\cite{レーダホログラフィ}。
```
\bibitem{レーダホログラフィ}
"新しい電波映像技術 レーダホログラフィ"
電子通信学会編
```
![](chirp_dia.png)

だが、
  使用帯域幅以上の圧縮はできないため、
  SN比をさらに高めようとするとパルス幅を大きくせざるを得ず、
  時間分解能が下がってしまう。

![ここにchirp信号の一部が入る](chirp.png)
![ここにchirp信号のスペクトログラムが入る](chirp_spectogram.png)

### Barker系列によるパルス圧縮
デジタルレーダーのにおいてはパルス圧縮に符号化変調も用いられる。
これは、
  相関検出器の相関特性がディラックの$\delta$関数に近いような符号系列を用いて変調する方式である。
その中でも、
  Barker系列という系列がある。
これは
  長さ$N$の有限長系列で、同期点以外での自己相関関数の絶対値の最大が$1/N$となるものである。
Barker系列は符号長$2\sim13$の間で存在することが知られており、表に示す。

|N|系列|
|-|-|
|2|++, +-|
|3|++-|
|4|+++-, ++-+|
|5|+++-+|
|7|+++--+-|
|11|+++---+--+-|
|13|+++++--++-+-+|

ここで-とは、BPSK(binary phase-shift keying)における+とは逆位相の信号（+の信号の振幅を-1倍したもの）である。
その自己相関は図のようにデルタ関数に近く、相関検出の信号として優れている。
![ここにバーカー符号の自己相関関数の図が入る](barker_autocorr.png)

これはパルスを時間方向へ圧縮する技術と言える。

### Chirp信号をBarker系列でBPSKなどの例
この符号化変調とチャープ信号を組み合わせることで、
  周波数方向と時間方向へエネルギーを分散しながら時間分解能を高める。

![理想的な帯域](barker_coded_chirp.png)
![帯域が狭くなっている図](barker_coded_chirp_err.png)
![ここに使用した信号の波形が入る](barker_bpsk_0.png)
![ここに使用した信号の波形が入る](barker_bpsk_1.png)
![ここに使用した信号の波形が入る](barker_chirp.png)

### BPSKで両者を組み合わせた手法
![ここにBPSKのQI図,信号空間ダイヤグラム](chirp_qi.png)
![ここにBPSK変調の時間軸図]()
* 二値位相切り換え系(BPSK)を用いてチャープパルスをbarker符号化
* barker系列の+に通常チャープ、-に逆位相チャープを使う
* 周波数方向と時間方向に圧縮された強力なパルスが作れる
![](barker_chirp.png)
![](barker_bpsk_0.png)
![](barker_bpsk_1.png)





### デジタル変調波の復調

* デジタル変調では、ある周期をもって変調がなされ、その１周期に対応する変調波の情報の単位はシンボルで表される


* 送信機から送られたデジタル変調は、受信機で復調されて元の情報が復元される。
* 受信機では雑音などの不要成分が加わって、送ったシンボルと異なったシンボルに謝ってしまうことがある。（シンボル誤り)
* シンボル誤り率を最小にした受信器を最適受信機という
* 最適受信のためには符号判定の段階で信号対雑音比が最大になるようにする
* そのために整合フィルタや相関器がある
* 相関器では到来する信号と共役の波形の信号を受信機で用意しておき、これと入力波を掛け合わせたあと、シンボル期間にわたり積分する

* 復調の方式には同期検波と非同期検波がある



## パルス圧縮

### SN比と距離分解能とドップラシフト分解能とかのトレードオフについて
* この辺にパルスレーダーの距離分解能およびパルス圧縮の必要性について

### 各種パルス圧縮について
* 精度の定義
* パルスレーダーの距離分解能

### Chirp信号によるパルス圧縮のあいまいさ
* Chirp信号は線形FM信号、Swept-Sine信号、TimeStretchedPulseなどとも呼ばれる信号
* 持続時間が長くパルスのエネルギーを圧縮できる

### Chirp信号をBarker系列でBPSKなどの例

![理想的な帯域](barker_coded_chirp.png)
![帯域が狭くなっている図](barker_coded_chirp_err.png)
![ここに使用した信号の波形が入る](barker_bpsk_0.png)
![ここに使用した信号の波形が入る](barker_bpsk_1.png)
![ここに使用した信号の波形が入る](barker_chirp.png)




# 測距に必要な信号処理

## 変調方式

* 位相シフト変調(PSK; Phase shift keying)

![ここにBPSKのQI図,信号空間ダイヤグラム](chirp_qi.png)
![ここにBPSK変調の時間軸図](chirp_qi.png)

### デジタル変調波の復調

* デジタル変調では、ある周期をもって変調がなされ、その１周期に対応する変調波の情報の単位はシンボルで表される


* 送信機から送られたデジタル変調は、受信機で復調されて元の情報が復元される。
* 受信機では雑音などの不要成分が加わって、送ったシンボルと異なったシンボルに謝ってしまうことがある。（シンボル誤り)
* シンボル誤り率を最小にした受信器を最適受信機という
* 最適受信のためには符号判定の段階で信号対雑音比が最大になるようにする
* そのために整合フィルタや相関器がある
* 相関器では到来する信号と共役の波形の信号を受信機で用意しておき、これと入力波を掛け合わせたあと、シンボル期間にわたり積分する

* 復調の方式には同期検波と非同期検波がある

#### 同期検波
* 同期検波回路では受信変調波と周波数位相の一致した基準搬送波を再生し
* これを受信変調波と掛け合わせて復調する
* この同期検波回路は相関器を用いた最適受信機（相関検波回路）と等価である

![ここに同期検波回路のブロック線図](block_diagram.png)

* 相関検出器(coherent detection)
* 最適受信機
  * 整合フィルタ
  * 周波数軸上でのたたみ込み積分（相互相関）

![ここに相関検波回路のブロック線図](block_diagram.png)

* 相関検出器もここで説明

## パルス圧縮
高精度パルスの検出の必要性
* 44100Hzサンプリング周波数のとき音速を340m/sとすると$\pm$1msの誤差で$\pm$34cm
* 人間の聴覚特性により各スピーカからの音に1ms以上の遅延が出ると違和感生じる
* 高精度なパルスの到来時刻の検出が必要

### [パルス圧縮と符号化](signal_processing.md)
* $\delta$関数を模した単一パルスが理想的だが実現困難
* 時間方向や周波数方向へエネルギーを分散するパルス圧縮技術が必要

### チャープパルスとTSPパルスとあいまい度関数
### SN比と距離分解能とドップラシフト分解能とかのトレードオフについて
* この辺にパルスレーダーの距離分解能およびパルス圧縮の必要性について

### 各種パルス圧縮について
* 精度の定義
* パルスレーダーの距離分解能

### Chirp信号によるパルス圧縮のあいまいさ
### チャープパルスによる周波数方向へのパルス圧縮
* 徐々に周波数が上がる(下がる)ような変調がされたsine信号
* 周波数方向にエネルギーが増える

![](chirp.png)
* Chirp信号は線形FM信号、Swept-Sine信号、TimeStretchedPulseなどとも呼ばれる信号
* 持続時間が長くパルスのエネルギーを圧縮できる

![ここにchirp信号の一部が入る](chirp.png)
![ここにchirp信号のスペクトログラムが入る](chirp_spectogram.png)



### Chirp信号をBarker系列でBPSKなどの例

![理想的な帯域](barker_coded_chirp.png)
![帯域が狭くなっている図](barker_coded_chirp_err.png)
![ここに使用した信号の波形が入る](barker_bpsk_0.png)
![ここに使用した信号の波形が入る](barker_bpsk_1.png)
![ここに使用した信号の波形が入る](barker_chirp.png)

### BPSKで両者を組み合わせた手法
* 二値位相切り換え系(BPSK)を用いてチャープパルスをbarker符号化
* barker系列の+に通常チャープ、-に逆位相チャープを使う
* 周波数方向と時間方向に圧縮された強力なパルスが作れる
![](barker_chirp.png)
![](barker_bpsk_0.png)
![](barker_bpsk_1.png)

### 単純チャープとBPSKでbarker符号化したチャープの比較
![](chirp_spectogram.png)
![](barker_coded_chirp.png)
* 単純チャープに比べ時間方向にエネルギーが増えている
