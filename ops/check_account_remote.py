import os,re,zipfile,subprocess,secrets,hashlib,json,ssl,urllib.request,urllib.error
with zipfile.ZipFile('/home/repo/bootdo/target/bootdo-1.7.0.jar') as z:
 config=z.read('BOOT-INF/classes/application-pro.yml').decode()
def setting(name):
 value=re.search(r'^\s+'+name+r':\s*(.+)$',config,re.M).group(1).strip()
 return value.strip('\"\'')
env=dict(os.environ,MYSQL_PWD=setting('password'))
def sql(query):
 p=subprocess.run(['mysql','-h','127.0.0.1','-u',setting('username'),'-N','-B','bootdo'],input=query,universal_newlines=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=env)
 if p.returncode: raise RuntimeError('Database test setup failed: '+p.stderr[:180])
 return p.stdout.strip()
keys=[secrets.token_hex(32) for _ in range(4)]
tokens=['petqa_'+secrets.token_hex(32) for _ in range(2)]
phones=['qaPM'+secrets.token_hex(5) for _ in range(2)]
hashof=lambda s:hashlib.sha256(s.encode()).hexdigest()
context=ssl._create_unverified_context()
def req(path,method='GET',body=None,guest=0,account=None,bind=False):
 headers={'Content-Type':'application/json','Authorization':'Bearer '+(tokens[account] if bind else keys[guest])}
 if bind: headers['X-Guest-Key']=keys[guest]
 elif account is not None: headers['X-App-Token']=tokens[account]
 data=None if body is None else json.dumps(body).encode()
 r=urllib.request.Request('https://127.0.0.1:8066/api/petmemorial/'+path,data=data,headers=headers,method=method)
 try:
  with urllib.request.urlopen(r,context=context,timeout=15) as response:return(response.status,json.load(response))
 except urllib.error.HTTPError as error:return(error.code,json.load(error))
ids=[]
createdPhones=[]
try:
 for phone,token in zip(phones,tokens):
  assert sql("SELECT COUNT(*) FROM ai_app_user WHERE phone='%s';"%phone)=='0'
  sql("INSERT INTO ai_app_user(phone,app_name,gmt_create,gmt_modified) VALUES ('%s','PetMemorial QA',NOW(),NOW());"%phone)
  createdPhones.append(phone)
  ids.append(int(sql("SELECT id FROM ai_app_user WHERE phone='%s';"%phone)))
  sql("INSERT INTO ai_app_access_token(token_hash,phone,expires_at,gmt_create) VALUES ('%s','%s',DATE_ADD(NOW(),INTERVAL 10 MINUTE),NOW());"%(hashof(token),phone))
 garden={'id':'qa-account','name':'账号验收临时资料','species':'cat','story':'测试后删除','theme':'sage','createdAt':1700000000000,'flowerCount':0,'candleCount':0,'photos':[],'letters':[{'id':'private','text':'PRIVATE_LETTER','createdAt':1700000000000}]}
 assert req('garden','PUT',{'version':0,'garden':garden})[0]==200
 status,rows=req('park');assert status==200
 empty=next(i for i in range(47,-1,-1) if all(p['index']!=i for p in rows))
 assert req('park','PUT',{'index':empty,'name':'账号验收','story':'测试后删除','photo':''})[0]==200
 status,bound=req('account/bind','POST',{'attachGuest':True},account=0,bind=True);assert status==200,(status,bound)
 assert bound['userId']==str(ids[0]) and bound['adoptedGuest']
 assert req('garden')[0]==401
 assert req('park')[0]==401
 assert req('garden',account=0)[1]['garden']['letters'][0]['text']=='PRIVATE_LETTER'
 assert req('garden',account=1)[0]==401
 status,b=req('account/bind','POST',{'attachGuest':False},guest=1,account=1,bind=True);assert status==200
 assert req('garden',guest=1,account=1)[0]==404
 assert not any(p['isMine'] for p in req('park',guest=1,account=1)[1])
 assert req('garden',guest=2,account=0)[1]['garden']['name']=='账号验收临时资料'
 assert any(p['isMine'] and p['index']==empty for p in req('park',guest=2,account=0)[1])
 status,repeat=req('account/bind','POST',{'attachGuest':True},guest=3,account=0,bind=True);assert status==200 and not repeat['adoptedGuest']
 assert req('garden',guest=3,account=0)[1]['garden']['name']=='账号验收临时资料'
 print('PASS: existing user ID, guest adoption, bound-key denied, account isolation, cross-device ownership, no overwrite on repeated login')
finally:
 owners={hashof(k) for k in keys}
 if ids:
  idlist=','.join(map(str,ids));mapped=sql('SELECT owner_hash FROM pet_memorial_account WHERE user_id IN (%s);'%idlist)
  owners.update(mapped.splitlines())
  owners.discard('');quoted=','.join("'%s'"%h for h in owners)
  sql('DELETE FROM pet_memorial_plot WHERE owner_hash IN (%s); DELETE FROM pet_memorial_garden WHERE owner_hash IN (%s); DELETE FROM pet_memorial_account WHERE user_id IN (%s);'%(quoted,quoted,idlist))
 for phone,token in zip(phones,tokens):
  if phone not in createdPhones: continue
  sql("DELETE FROM ai_app_access_token WHERE token_hash='%s'; DELETE FROM ai_app_user WHERE phone='%s';"%(hashof(token),phone))
 print('Temporary test users, tokens, private data and plots removed')
