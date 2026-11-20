-- Information Overload: the Havoc screen's figures, gathered from the open Havoc screen, the Strike Team, the Havoc board and saved history, then counted into one plain model.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local B=mod:io_dofile(base.."board_briefing")
local Overview=mod:io_dofile(base.."io_overview")
local I=mod:io_dofile(base.."player_identity")
local Faction=mod:io_dofile(base.."havoc_faction")
local M={}
-- the standing figure under each name: this week's best where it is known and above nought (yours, from the screen; the board does not
-- share a teammate's), else the season's best the game's presence shares for everyone, marked with when
M.LABEL="This Week"
M.SEASON="This Season"
M.EVERY=.5
local WHERE={hub="In The Mourningstar",mission="In A Mission"}
local UNTRACKED="Your runs here were saved before downs were recorded."
local KINDS={"ranged","melee","special","boss","hazard"}

-- the counting: plain tables in, the model out, nothing read from the game
local function timed(runs)local backend=false;for _,r in ipairs(runs)do if r.won and r.time and r.backend then backend=true end end
 local out={};for _,r in ipairs(runs)do if r.won and r.time and (r.backend==true)==backend then out[#out+1]=r end end;return out end
local function cause(l,x,lit)return {l,x.n,x.kind,lit}end
-- what downs you on a map: the lead line as the Mission Board words it, then every cause with its kind, most first, the first eight
-- as the Threats bars and the next six under them
local function downs(runs)
 local tracked,ev=0,{}
 for _,r in ipairs(runs)do if r.tracked then tracked=tracked+1;for _,e in ipairs(r.events or {})do ev[#ev+1]=e end end end
 local d={tracked=tracked,runs=#runs,head="",line="",bars={},also={},all={},unknown=0,more=0}
 if #runs==0 then return d end
 if tracked==0 then d.line=UNTRACKED;return d end
 d.total=#ev
 local b=B.downs({runs=runs})
 if b.none then d.line=b.none else d.head,d.line=b.head,b.line end
 local byKind,byLabel,labels={},{},{}
 for _,e in ipairs(ev)do if e[1]then byKind[e[2]]=(byKind[e[2]]or 0)+1;local x=byLabel[e[1]]
  if not x then x={n=0,kind=e[2]};byLabel[e[1]]=x;labels[#labels+1]=e[1]end;x.n=x.n+1 else d.unknown=d.unknown+1 end end
 local top,tied=nil,{}
 for _,k in ipairs(KINDS)do if byKind[k]and (not top or byKind[k]>byKind[top])then top=k end end
 if top then for _,k in ipairs(KINDS)do if byKind[k]==byKind[top]then tied[k]=true end end;d.kind=top end
 table.sort(labels,function(a,b)local x,y=byLabel[a],byLabel[b];if x.n~=y.n then return x.n>y.n end
  local tx,ty=tied[x.kind]and 1 or 0,tied[y.kind]and 1 or 0;if tx~=ty then return tx>ty end;local la,lb=a:lower(),b:lower();if la~=lb then return la<lb end;return a<b end)
 for i,l in ipairs(labels)do local x=byLabel[l];local lit=tied[x.kind]==true;d.all[i]=cause(l,x,lit)
  if i<=8 then d.bars[i]=cause(l,x,lit)elseif i<=14 then d.also[#d.also+1]=cause(l,x,lit)end end
 d.more=math.max(0,#labels-14)
 return d
end
-- one map's record from your Havoc runs there, newest first; mates holds each teammate's identity keys when in a Strike Team
function M.map(m,mates)
 local runs=m.runs or {};local n=#runs;local w=0
 for _,r in ipairs(runs)do if r.won then w=w+1 end end
 local o={base=m.base,runs=n,won=w,lost=n-w,at_rank={},strip={},downs=downs(runs)}
 if n>0 then o.last,o.since=runs[1].date,runs[n].date end
 local best,top,lo,hi
 for _,r in ipairs(timed(runs))do if not best or r.time<best.time then best=r end end
 if best then o.best_clear={B.time_text(best),best.rank,best.date}end
 local by,order={},{}
 for _,r in ipairs(runs)do local s=r.won and 1 or 2
  if type(r.dmg)=="number"and r.dmg>0 and (r.ranked or r.ranked==nil and not r.imported)and (not top or r.dmg>top.dmg)then top=r end
  local k=r.rank;if k then local a=o.at_rank[k];if not a then a={0,0};o.at_rank[k]=a end;a[s]=a[s]+1;if not lo or k<lo then lo=k end;if not hi or k>hi then hi=k end end
  local cl=r.cls or Overview.dash;local c=by[cl];if not c then c={cl,0,0,#order+1};by[cl]=c;order[#order+1]=c end;c[s+1]=c[s+1]+1
  if #o.strip<12 then o.strip[#o.strip+1]={r.rank,cl,r.won==true}end
 end
 if top then o.best_damage={Overview.commas(math.floor(top.dmg+.5)),top.cls,top.date}end
 if lo then o.ranks={lo,hi}end
 table.sort(order,function(a,b)if a[2]~=b[2]then return a[2]>b[2]end;local x,y=a[2]+a[3],b[2]+b[3];if x~=y then return x>y end;return a[4]<b[4]end)
 if order[1]then o.op={order[1][1],order[1][2],order[1][3]}end
 -- your runs here with any of this Strike Team, as the mockup counts them
 if mates and #mates>0 then local any={0,0}
  for _,r in ipairs(runs)do local s,with=r.won and 1 or 2,false
   for _,ks in ipairs(mates)do for _,k in ipairs(ks)do if r.keys and r.keys[k]then with=true end end end
   if with then any[s]=any[s]+1 end end
  o.team_any=any end
 return o
end
local function record(r)if type(r)=="table"and (r[1]or 0)+(r[2]or 0)>0 then return {games=r[1]+r[2],won=r[1],lost=r[2]}end end
-- the week's best when known and above nought, else the season's with its when
local function stand(p,week)if not week then return p.cadence,nil end;local w=tonumber(p.week);if w and w>0 then return w,nil end;return p.cadence,M.SEASON end
function M.build(src)
 local label=src.label or M.LABEL;local week=label=="This Week"
 local ps=src.players or {};local team=#ps>=2;local mates={}
 -- inviting the people played with recently is not built, so the layout draws no invite
 local model={team=team,my_rank=src.my_rank,max_rank=src.max_rank,sharing=src.sharing==true,invites=false,launch=src.launch,owner_launch=src.owner_launch,reset=src.reset,standing_label=label,
  presence_full=src.presence_full==true or nil,presence_changed=src.presence_changed==true or nil,
  players={},votes={},mine={},leaders={},recent={},maps={},together={}}
 for i,p in ipairs(ps)do local sub,when=stand(p,week)
  local x={who=p.who,account=p.account,me=p.me==true or nil,mod=p.mod,none=p.none,a=p.a,high=p.high,sub=sub,when=when}
  if not p.me then x.mate=record(p.mate)
   if team then local r=x.mate;model.together[#model.together+1]={who=p.who,account=p.account,games=r and r.games or 0,won=r and r.won or 0,lost=r and r.lost or 0}
    mates[#mates+1]=p.keys or {}end end
  model.players[i]=x
 end
 -- each tile's voters in party order, yours first; every tile tied on the top count above nought leads
 local top=0
 for k,l in pairs(src.votes or {})do local c={};for i,j in ipairs(l)do c[i]=j end;model.votes[k]=c;if c[1]==1 then model.mine[k]=true end;if #c>top then top=#c end end
 for k,c in pairs(model.votes)do if top>0 and #c==top then model.leaders[k]=true end end
 if not team then for _,r in ipairs(src.recent or {})do if #model.recent<3 then local sub,when=stand(r,week)
  local g=record({r.won,r.lost})or {games=0,won=0,lost=0}
  model.recent[#model.recent+1]={who=r.who,account=r.account,games=g.games,won=g.won,lost=g.lost,high=r.high,sub=sub,when=when,where=r.where,can_invite=r.can_invite==true}
  model.together[#model.together+1]={who=r.who,account=r.account,games=g.games,won=g.won,lost=g.lost}end end end
 for key,m in pairs(src.maps or {})do model.maps[key]=M.map(m,team and mates or nil)end
 return model
end

-- the gathering: the game and saved history read into plain source tables
local function call(o,name)local f=type(o)=="table"and o[name];if type(f)~="function"then return nil end;local ok,r=pcall(f,o);if ok then return r end end
local function loc(L,key)if type(key)~="string"or not L then return nil end;local ok,s=pcall(L,key)
 if ok and type(s)=="string"and s~=key and s~=""and not s:find("<unlocalized",1,true)then return s end end
local function localizer(deps)return deps.localize or Localize end
-- a player's name as plain words: the engine would read {# in it as markup and draw it past its fitted room
local function clean(s)s=tostring(s or "");local n;repeat s,n=s:gsub("{#","{")until n==0;return s end
local T
local function tables(deps)
 if deps.tables then return deps.tables end
 if not T then T={missions=require("scripts/settings/mission/mission_templates"),types=require("scripts/settings/mission/mission_types"),
  zones=require("scripts/settings/zones/zones"),circumstances=require("scripts/settings/circumstance/circumstance_templates")}end
 return T
end
-- the view's own flag reading, used when the view cannot be asked
local PREFIX={circumstances="^havoc%-circ%-(.+)$",factions="^havoc%-faction%-(.+)$"}
local function flags(set)local out={circumstances={},factions={}}
 if type(set)=="table"then for k,v in pairs(set)do local f=type(k)=="string"and k or type(v)=="string"and v
  if f then for cat,p in pairs(PREFIX)do local x=f:match(p);if x then out[cat][(x:gsub("maelstrom_plus","havoc"))]=true end end end end end
 return out end
-- an Assignment as the game's screen shows it, from its map, rank, faction and modifier ids; modifiers in id order
function M.assignment(map,rank,faction,ids,deps)
 deps=deps or {};local t=tables(deps);local L=localizer(deps)
 local mt=type(map)=="string"and t.missions[map];if not mt then return nil end
 local name=loc(L,mt.mission_name)or "";local ty=t.types[mt.mission_type or "undefined"];local z=t.zones[mt.zone_id]
 local a={map=map,name=name,base=(B.split(name)),zone=z and loc(L,z.name)or "",type=ty and loc(L,ty.name)or "",text=loc(L,mt.mission_description)or "",
  rank=tonumber(rank),faction=Faction.label(faction),texture=mt.texture_big,mods={}}
 local list={};for _,id in ipairs(ids or {})do list[#list+1]=id end;table.sort(list)
 for _,id in ipairs(list)do local c=t.circumstances[id];local ui=type(c)=="table"and c.ui
  if ui then a.mods[#a.mods+1]={id=id,title=loc(L,ui.display_name)or "",desc=loc(L,ui.description)or "",icon=ui.icon}end end
 return a
end
-- your own Assignment: the order the open screen shows, read with the screen's own flag reading, under the order's id as the board knows it
function M.own(view,deps)
 local order=type(view)=="table"and view._parent and view._parent.havoc_order
 local bp=type(order)=="table"and order.blueprint;local map=type(bp)=="table"and bp.template and bp.template.id
 if type(map)~="string"then return nil end
 local ok,ex=pcall(view._extract_havoc_flags_data,view);if not ok or type(ex)~="table"then ex=flags(bp.flags)end
 local ids={};for id in pairs(ex.circumstances or {})do ids[#ids+1]=id end
 local a=M.assignment(map,order.data and order.data.rank,(next(ex.factions or {})),ids,deps);if a then a.assignment_id=order.id end
 return a
end
-- your counted runs, read once per history change: the Havoc runs by map, everyone's record with you over every mode, who you played with last
local hist
function M.history(tracker)
 local data=type(tracker)=="table"and tracker.data;if type(data)~="table"then return nil end
 local list=data.run_history or {}
 local key=tostring(data).."|"..tostring(data.run_sequence).."|"..tostring(data.history_policy_revision).."|"..#list
 if hist and hist.key==key then return hist end
 I.learn(data)
 local idx=B.index(tracker);local h={maps={},people=idx.people,tracker=tracker}
 for k,l in pairs(idx.maps)do local out={};for _,run in ipairs(l)do if run.context.mode=="havoc"then out[#out+1]=run end end;if #out>0 then h.maps[k]=out end end
 hist={key=key,h=h,people=idx.people,runs={}}
 return hist
end
-- the three people played with last over every mode, newest first; read only when playing alone
local function last3(h)
 if h.recent then return h.recent end
 local tracker=h.h.tracker;local data=tracker.data;local recent,seen={},{}
 for _,run in ipairs(Overview.runs(tracker))do local c=run.context;local new={}
  for _,set in ipairs({c.operative_roster or {},I.team_accounts(data,c)})do for id,p in pairs(set)do
   if type(p)=="table"and not p.personal and tostring(id)~=tostring(c.character)then local k=I.key(p)
    if k and not seen[k]then seen[k]=true;new[#new+1]={k=k,who=clean(p.steam_name or p.friend_name or p.name),account=p.account_id and tostring(p.account_id)}end end end end
  table.sort(new,function(a,b)local x,y=a.who:lower(),b.who:lower();if x~=y then return x<y end;return a.k<b.k end)
  for _,p in ipairs(new)do local r=h.people[p.k]or {0,0};p.won,p.lost=r[1],r[2];recent[#recent+1]=p end
  if #recent>=3 then break end
 end
 h.recent=recent;return recent
end
-- one map's Havoc runs in plain rows, as the Mission Board reads them, with each run's teammates as identity keys
local function keys(run,data)local c=run.context;local out={}
 for _,set in ipairs({c.operative_roster or {},I.team_accounts(data,c)})do for id,p in pairs(set)do
  if type(p)=="table"and not p.personal and tostring(id)~=tostring(c.character)then local k=I.key(p);if k then out[k]=true end
   if p.account_id then out["account:"..tostring(p.account_id)]=true end end end end
 return out end
function M.runs(h,key,basis)
 local id=key.."|"..basis;local got=h.runs[id];if got then return got end
 local list=h.h.maps[key];got={runs={}}
 local m=list and B.map(h.h,key,basis)
 if m then got.base=m.base
  for i,r in ipairs(m.runs)do local run=list[i]
   got.runs[i]={date=r.date,rank=tonumber(run.context.difficulty),cls=r.cls,won=r.won,time=r.time,backend=r.backend,dmg=r.dmg,imported=r.imported,ranked=r.ranked,est=r.est,tracked=r.tracked,events=r.events,keys=keys(run,h.h.tracker.data)}end end
 h.runs[id]=got;return got
end
-- the board leaves out the Emperor's Fading Light, which the rank brings as the game's own generator adds it: I from 16, II from 30
local function faded(x)local out={};for i,v in ipairs(type(x.modifiers)=="table"and x.modifiers or {})do out[i]=v end;local r=tonumber(x.rank)
 if r and r>=30 then out[#out+1]="mutator_highest_difficulty"elseif r and r>=16 then out[#out+1]="mutator_increased_difficulty"end;return out end
local function presence(managers,id)local p=managers and managers.presence;local c=type(p)=="table"and p._presences_by_account_id
 local e=type(c)=="table"and id and c[id];return type(e)=="table"and e or nil end
-- you first, then your Strike Team in the party's order, with the Havoc standing each one's presence carries and the Assignment each shares
-- through the board once their I/O has shaken hands with yours; data that is missing says nothing about whether a teammate runs I/O
function M.party(view,deps,h,snap)
 local managers=deps.managers or Managers;local party=managers and managers.party_immaterium
 local myself=call(party,"get_myself");local my=call(myself,"account_id");my=my and tostring(my)
 local mine=managers and call(managers.presence,"presence_entry_myself")
 local wd=type(view)=="table"and view._parent and view._parent._havoc_week_data
 local me={who="You",account=my,me=true,mod=true,week=type(wd)=="table"and tonumber(wd.week_rank)or nil,
  high=tonumber(call(myself,"havoc_rank_all_time_high")or call(mine,"havoc_rank_all_time_high")),
  cadence=tonumber(call(myself,"havoc_rank_cadence_high")or call(mine,"havoc_rank_cadence_high"))}
 local list={me};local members=call(party,"all_members")
 for _,m in ipairs(type(members)=="table"and members or {})do local id=call(m,"account_id")
  if id and m~=myself and tostring(id)~=my then id=tostring(id);local k=I.key({account_id=id})
   local p={who=clean(call(m,"name")),account=id,keys={k,"account:"..id},high=tonumber(call(m,"havoc_rank_all_time_high")),cadence=tonumber(call(m,"havoc_rank_cadence_high"))}
   local r=h and I.lookup(h.people,k);if r then p.mate={r[1],r[2]}end
   local b=snap and snap.members[id]
   -- a tile carried over a join or leave shows its Assignment while the board reconnects
   if type(b)=="table"and (b.protocol_status=="ready"or b.carried)then p.mod=true
    local x=type(snap.maps[id])=="table"and snap.maps[id].assignment
    if type(x)=="table"then p.a=M.assignment(x.map,x.rank,x.faction,faded(x),deps);if p.a then p.a.assignment_id,p.a.owner=x.assignment_id,id end
    elseif b.assignment_status=="none"then p.none=true end end
   list[#list+1]=p end end
 return list
end
local function recent(h,deps)local managers=deps.managers or Managers;local out={}
 for _,p in ipairs(h and last3(h)or {})do if #out<3 then local e=presence(managers,p.account)
  local where=e and call(e,"is_online")~=false and WHERE[call(e,"activity_id")]or nil
  out[#out+1]={who=p.who,account=p.account,won=p.won,lost=p.lost,where=where,can_invite=where==WHERE.hub,
   high=e and tonumber(call(e,"havoc_rank_all_time_high")),cadence=e and tonumber(call(e,"havoc_rank_cadence_high"))}end end
 return out end
-- the game's reset line, split into its words and the time, colour tags dropped; read again only when the game's text changes, and the same
-- table kept while the words do not, so the Help tour dimming the time's colour lays nothing out again
local rs={}
function M.reset(view,deps)
 local wb=type(view)=="table"and view._widgets_by_name;local w=wb and wb.reward_timer_header
 local s=w and w.content and w.content.text;if type(s)~="string"then return nil end
 if s==rs.raw then return rs.out end
 local label=loc(localizer(deps or {}),"loc_havoc_time");local out
 if label and s:sub(1,#label)==label then local v=s:sub(#label+1):gsub("{#[^}]*}",""):gsub("^[ \t\r\n]+",""):gsub("[ \t\r\n]+$","");if v~=""then out={label,v}end end
 local was=rs.out;if out and was and was[1]==out[1]and was[2]==out[2]then out=was end
 rs.raw,rs.out=s,out;return out
end
-- the Havoc board's snapshot, read afresh each time since the composition root publishes the board after the screens load; no board, a fault
-- or a board that is off is no sharing
local function snapshot(deps)local b=deps.board or mod.io_havoc;local f=type(b)=="table"and b.snapshot;if type(f)~="function"then return nil end
 local ok,s=pcall(f);if ok and type(s)=="table"and s.enabled and s.myself~=nil and type(s.members)=="table"and type(s.maps)=="table"then return s end end
-- who voted for each tile's Assignment, in party order: yours from your own choices so it shows at once, a teammate's as its owner confirmed
-- it, and only while the board's Assignment for that owner is the one the tile shows
local function tally(snap,players)
 local out,mine={},type(snap.choices)=="table"and snap.choices or {}
 for k,p in ipairs(players)do local x=p.a;local mp=x and snap.maps[x.owner]
  if type(mp)=="table"and type(mp.assignment)=="table"and mp.assignment.assignment_id==x.assignment_id then local vs=type(mp.votes)=="table"and mp.votes or {};local list={}
   for j,q in ipairs(players)do if j==1 and mine[x.owner]==1 or j>1 and q.account and vs[q.account]==1 then list[#list+1]=j end end
   if #list>0 then out[k]=list end end end
 return out end
-- the top rank a win cannot raise, from the game's Havoc settings where it has them
local function top(deps)local managers=deps.managers or Managers;local hs=managers and managers.data_service and managers.data_service.havoc;local s=hs and call(hs,"get_settings");return type(s)=="table"and tonumber(s.max_rank)or 40 end
function M.gather(view,deps)
 deps=deps or {}
 local tracker=deps.tracker or deps.dashboard_tracker;if type(tracker)=="function"then tracker=tracker()end
 local h=M.history(tracker)
 local opts=deps.options or (mod.io_display_options and mod.io_display_options())or {}
 local basis=opts.boss_map_timing and "boss"or "victory"
 local snap=snapshot(deps)
 local a=M.own(view,deps);local players=M.party(view,deps,h,snap);players[1].a=a
 if a then a.owner=snap and snap.myself or players[1].account end
 local sharing=snap~=nil and #players>=2;local L=sharing and type(snap.launch)=="table"and snap.launch
 local src={hkey=h and h.key,basis=basis,label=deps.label or M.LABEL,my_rank=a and a.rank,max_rank=top(deps),players=players,maps={},reset=M.reset(view,deps),
  sharing=sharing,votes=sharing and tally(snap,players)or nil,launch=L and {id=L.id,status=L.status,owner=L.owner,reason=L.reason}or nil,
  owner_launch=sharing and type(snap.owner_launch)=="table"and {requester=snap.owner_launch.requester,status=snap.owner_launch.status}or nil,
  presence_full=sharing and snap.presence_full==true or nil,presence_changed=sharing and snap.presence_changed==true or nil}
 if #players<2 then src.recent=recent(h,deps)end
 for _,p in ipairs(players)do local key=p.a and p.a.map
  if key and not src.maps[key]then local r=h and M.runs(h,key,basis);src.maps[key]={base=r and r.base or p.a.base,runs=r and r.runs or {}}end end
 return src
end
-- everything the model is counted from in one string, the history by its key and the reset line left out, so the model is counted again only on a change
local SKIP={maps=true,reset=true}
local function ser(v,out)
 if type(v)~="table"then out[#out+1]=tostring(v);return end
 local ks={};for k in pairs(v)do if not SKIP[k]then ks[#ks+1]=k end end;table.sort(ks,function(a,b)return tostring(a)<tostring(b)end)
 out[#out+1]="{";for _,k in ipairs(ks)do out[#out+1]=tostring(k);out[#out+1]="=";ser(v[k],out);out[#out+1]=";"end;out[#out+1]="}"
end
function M.key(src)local out={};ser(src,out);return table.concat(out)end
-- the model for the open screen: read at most every M.EVERY seconds of t, counted again only when what it is counted from changes
local held={}
function M.get(view,deps,t)
 deps=deps or {}
 if held.model and held.view==view and t and held.t and t>=held.t and t-held.t<(deps.every or M.EVERY)then
  local r=M.reset(view,deps);if r then held.model.reset=r end;return held.model,false end
 local src=M.gather(view,deps);local key=M.key(src);local fresh=false
 if key~=held.key then held.model=M.build(src);held.key=key;fresh=true end
 held.view,held.t=view,t
 if src.reset then held.model.reset=src.reset end
 return held.model,fresh
end
-- the next ask reads afresh, as a vote just cast must show at once
function M.again()held.t=nil end
function M.drop()held={};hist=nil;rs={}end
return M
