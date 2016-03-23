#coding:utf-8
import json

f = open('log.json', 'r')
jsonData = json.load(f)
print(json.dumps(jsonData, sort_keys = True, indent = 2))
f.close()
