#coding:utf-8
import json
import numpy as np

f = open('logs.json', 'r')
o = json.load(f)

for _type, varis in o.items():
    for key, arr in varis.items():
        print(_type, key, len(arr))
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
        for color1, v1 in mtx.items():
            for color2, v2 in v1.items():
                 arr = np.array(v2)
                 ave = np.average(arr)
                 var = np.var(arr)
                 med = np.median(arr)
                 print(_type, "\t", key, "\t", color1, "\t", color2, "\t", len(v2), "\t", med, "\t", ave, "\t", var)



#print(json.dumps(o, sort_keys = True, indent = 2))
f.close()
