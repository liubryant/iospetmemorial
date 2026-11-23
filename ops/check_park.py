import secrets,concurrent.futures,urllib.request,urllib.error,json
class Response:
 def __init__(self,status,data): self.status_code=status; self.data=data
 def json(self): return json.loads(self.data)
 def raise_for_status(self): assert self.status_code==200,(self.status_code,self.data)
class Requests:
 def request(self,method,url,headers=None,json=None,timeout=20):
  data=None if json is None else __import__('json').dumps(json).encode()
  h=dict(headers or {});h['Content-Type']='application/json'
  try:
   with urllib.request.urlopen(urllib.request.Request(url,data=data,headers=h,method=method),timeout=timeout) as r: return Response(r.status,r.read())
  except urllib.error.HTTPError as e: return Response(e.code,e.read())
 def put(self,url,**kwargs): return self.request('PUT',url,**kwargs)
requests=Requests()
url='https://www.cjym123.cn:8066/api/petmemorial/park'
keys=[secrets.token_hex(32) for _ in range(2)]
def req(i,method,body=None):
 return requests.request(method,url,headers={'Authorization':'Bearer '+keys[i]},json=body,timeout=20)
try:
 initial=req(0,'GET'); initial.raise_for_status(); used={p['index'] for p in initial.json()}
 empty=[i for i in range(48) if i not in used]; assert len(empty)>=2
 body={'index':empty[-1],'name':'接口验收临时资料','story':'测试完成立即删除','photo':'','letters':[{'text':'THIS_MUST_NOT_BE_PUBLIC'}]}
 with concurrent.futures.ThreadPoolExecutor(2) as pool:
  results=list(pool.map(lambda i:req(i,'PUT',body),[0,1]))
 assert sorted(r.status_code for r in results)==[200,409],[r.status_code for r in results]
 winner=0 if results[0].status_code==200 else 1; loser=1-winner
 rows=req(winner,'GET').json(); own=[p for p in rows if p['isMine']]; assert len(own)==1
 assert all(set(p)=={'index','name','story','photo','isMine','publicId','flowers','candles'} for p in rows)
 assert 'THIS_MUST_NOT_BE_PUBLIC' not in str(rows)
 moved=dict(body,index=empty[-2]); assert req(winner,'PUT',moved).status_code==200
 assert [p['index'] for p in req(winner,'GET').json() if p['isMine']]==[empty[-2]]
 r=req(loser,'PUT',body); assert r.status_code==200,(r.status_code,r.data)
 assert req(winner,'PUT',body).status_code==409
 assert [p['index'] for p in req(winner,'GET').json() if p['isMine']]==[empty[-2]]
 assert requests.put(url,json=body,timeout=20).status_code==401
 print('PASS: race claim, one owner one plot, move, failed move preserved, public field allowlist, authentication')
finally:
 for i in range(2):
  r=req(i,'DELETE'); assert r.status_code==200
 for i in range(2): assert not any(p['isMine'] for p in req(i,'GET').json())
 print('PASS: release; temporary test records removed')
