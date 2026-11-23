import secrets,json,urllib.request,urllib.error,concurrent.futures
base='https://www.cjym123.cn:8066/api/petmemorial/'
keys=[secrets.token_hex(32) for _ in range(3)]
def req(who,method,path,body=None):
 h={} if who is None else {'Authorization':'Bearer '+keys[who]}
 if body is not None:h['Content-Type']='application/json'
 r=urllib.request.Request(base+path,data=None if body is None else json.dumps(body).encode(),headers=h,method=method)
 try:
  with urllib.request.urlopen(r,timeout=25) as p:return p.status,p.read().decode()
 except urllib.error.HTTPError as e:return e.code,e.read().decode()
def good(who,method,path,body=None):
 status,data=req(who,method,path,body);assert status==200,(status,data);return json.loads(data)
def mine():return next(x for x in good(0,'GET','park') if x['isMine'])
try:
 used={x['index'] for x in good(0,'GET','park')};empty=[i for i in range(48) if i not in used];assert len(empty)>2
 body={'index':empty[0],'name':'<b>QA</b>','story':'<script>private()</script>','photo':'','letters':['SECRET_NOT_PUBLIC']}
 good(0,'PUT','park',body);p=mine();id=p['publicId'];assert p['flowers']==0
 status,html=req(None,'GET','public/'+id);assert status==200
 assert '&lt;b&gt;QA&lt;/b&gt;' in html and '<script>private()' not in html and 'SECRET_NOT_PUBLIC' not in html
 assert req(None,'POST','community/'+id+'/flower')[0]==401
 with concurrent.futures.ThreadPoolExecutor(4) as pool:results=list(pool.map(lambda _:req(1,'POST','community/'+id+'/flower'),range(8)))
 assert all(s==200 for s,_ in results),results
 good(1,'POST','community/'+id+'/candle');summary=good(1,'GET','community/'+id)
 assert summary['flowers']==1 and summary['candles']==1 and set(summary['sent'])=={'flower','candle'} and summary['visits']==[]
 owner=good(0,'GET','community/'+id);assert len(owner['visits'])==2 and all(set(v)=={'kind','time','visitor'} for v in owner['visits'])
 good(1,'POST','community/'+id+'/favorite');assert id in good(1,'GET','community')['favorites'];assert id not in good(2,'GET','community')['favorites']
 good(1,'POST','community/'+id+'/unfavorite');assert id not in good(1,'GET','community')['favorites'];good(1,'POST','community/'+id+'/favorite')
 body['index']=empty[1];good(0,'PUT','park',body);assert mine()['publicId']==id and mine()['flowers']==1
 good(0,'DELETE','park');assert req(None,'GET','public/'+id)[0]==404 and req(1,'POST','community/'+id+'/flower')[0]==404
 assert id not in good(1,'GET','community')['favorites']
 good(2,'PUT','park',dict(body,index=empty[1],name='全新的伙伴QA'));new=next(x for x in good(2,'GET','park') if x['isMine'])
 assert new['publicId']!=id and new['flowers']==0 and new['candles']==0
 assert req(None,'GET','public/'+id)[0]==404
 print('PASS: public HTML escaping/privacy; authenticated tributes; concurrent daily deduplication; owner-only visitor log; private favorites; stable links after move; release revocation; new occupant isolation')
finally:
 for i in [0,2]:assert req(i,'DELETE','park')[0]==200
 print('Temporary public monuments, favorites and tributes removed')
