import urllib.request,urllib.error,json,secrets,base64,time
from pathlib import Path
url='https://www.cjym123.cn:8066/api/petmemorial/garden'
key=secrets.token_hex(32)
def req(method,token=key,body=None):
 data=json.dumps(body,ensure_ascii=False).encode() if body is not None else None
 r=urllib.request.Request(url,data=data,method=method,headers={'Authorization':'Bearer '+token,'Content-Type':'application/json'})
 try:
  with urllib.request.urlopen(r,timeout=20) as response: return response.status,json.load(response)
 except urllib.error.HTTPError as e:
  return e.code,json.load(e)
g={'id':'smoke-'+secrets.token_hex(4),'name':'测试花园（自动清理）','species':'cat','story':'仅用于验证私密备份，不是真实用户资料。','theme':'sage','createdAt':time.time()*1000,'flowerCount':2,'candleCount':1,'photos':[],'letters':[{'id':'test-letter','text':'给小猫的一封测试信。','createdAt':time.time()*1000}]}
image=base64.b64encode((Path(__file__).parent/'fixtures/test-photo.jpg').read_bytes()).decode()
print('Synthetic JPEG encoded bytes:',len(image))
if len(image)<200000:
 g['photos']=[{'id':str(i),'caption':'测试照片','createdAt':time.time()*1000,'imageBase64':image} for i in range(6)]
try:
 assert req('GET')[0]==404
 assert req('GET',token='invalid')[0]==401
 status,result=req('PUT',body={'version':0,'garden':g});assert status==200,(status,result)
 status,result=req('GET');assert status==200 and result['garden']==g
 assert req('GET',token=secrets.token_hex(32))[0]==404
 assert req('PUT',body={'version':0,'garden':g})[0]==409
 g['theme']='moon'
 status,result=req('PUT',body={'version':1,'garden':g});assert status==200 and result['version']==2
 assert req('GET')[1]['garden']['theme']=='moon'
 print('PASS: create, six-photo readback, owner isolation, stale-write rejection, update')
finally:
 assert req('DELETE')[0]==200
 assert req('GET')[0]==404
 print('PASS: delete and no residual test record')
for path in ['/login','/im/bot/navi/vip/products','/api/sounds','/api/petmemorial/health']:
 with urllib.request.urlopen('https://www.cjym123.cn:8066'+path,timeout=20) as r: print(path,r.status)
with urllib.request.urlopen('https://www.cjym123.cn/',timeout=20) as r: print('homepage',r.status)
