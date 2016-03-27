#coding:utf-8
import json
import numpy as np
from scipy import stats

f = open('logs.json', 'r')
o = json.load(f)

for _type, varis in o.items():
    for key, arr in varis.items():
        mtx = {
            "yellow":  {"yellow": [],"lime": [],"magenta": [],"cyan": []},
            "lime":    {"yellow": [],"lime": [],"magenta": [],"cyan": []},
            "magenta": {"yellow": [],"lime": [],"magenta": [],"cyan": []},
            "cyan":    {"yellow": [],"lime": [],"magenta": [],"cyan": []} }
        for elm in arr:
            if len(elm["distribute"]) == 0: continue
            distances = elm["distribute"][0]["json"]["distances"]
            if len(distances.keys()) != 4: continue
            for color1, v1 in distances.items():
                for color2, v2 in v1.items():
                    mtx[color1][color2].append(v2)
        s = set()
        print(_type
            ,"\t",key
            ,"\t",len(arr)
        )
        for color1, v1 in mtx.items():
            s.add(color1)
            for color2, v2 in v1.items():
                if color2 in s: continue
                if color1 == "cyan" or color1 == "lime": color1 += "___"
                if color2 == "cyan" or color2 == "lime": color2 += "___"
                if color1 == "yellow": color1 += "_"
                if color2 == "yellow": color2 += "_"
                a = np.array(v2)
                print(
                    str(len(v2))
                    ,"\t",color1
                    ,"\t",color2
                    ,"\t",np.average(a)  ## 平均
                    ,"\t",np.mean(a)       ## 算術平均
                    ,"\t",np.median(a)     ## 中央値
                    ,"\t",stats.scoreatpercentile(a, 25) #第2四分位
                    ,"\t",stats.scoreatpercentile(a, 50) #中央値
                    ,"\t",stats.scoreatpercentile(a, 75) #第3四分位
                    ,"\t",np.ptp(a)        ## 値の範囲(最大値-最小値)
                    ,"\t",np.amax(a)       ## 最大値
                    ,"\t",np.amin(a)       ## 最小値
                    ,"\t",np.var(a)        ## 分散
                    ,"\t",np.std(a)        ## 標準偏差
                )


f.close()
