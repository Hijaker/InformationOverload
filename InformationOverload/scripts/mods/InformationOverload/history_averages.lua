local A={CACHE_VERSION="history-projections-2"}
local function bucket()return {games=0,wins=0,damage=0,damage_games=0,team_damage=0,defense={downs=0,deaths=0,pickups=0},defense_games=0}end
local function add(a,b)for _,k in ipairs({"downs","deaths","pickups"})do a[k]=a[k]+(b and b[k]or 0)end end
local function merge_numbers(target,source)
 for k,v in pairs(source)do if type(v)=="number"then target[k]=(target[k]or 0)+v elseif type(v)=="table"then target[k]=target[k]or {};merge_numbers(target[k],v)end end
end
function A.build(history,mode,T,R,cached,lazy)
 local out={games=0,damage=0,damage_games=0,defense={downs=0,deaths=0,pickups=0},defense_games=0,friendly={damage=0,murders=0,suicides=0,games=0},leaves={attempts=0,games=0},kills={horde=0,trash_melee=0,trash_ranged=0,elite_melee=0,elite_ranged=0,special=0,elite=0,boss=0},kill_games=0,role_games=0,armour={},classes={},personal={}}
 if cached then
  for _,run in ipairs(history or {})do if not mode or (run.context or {}).mode==mode then local row=cached[tostring(run.id)];if row or not lazy then merge_numbers(out,row or A.build({run},mode,T,R))end end end
  return out
 end
 for _,run in ipairs(history or {})do local c=run.context or {}
  if (not mode or c.mode==mode)and type(run.victory)=="boolean"and not run.data_only and not run.discarded and not run.hidden_contributions  and not c.training_history_test and c.difficulty~="psykhanium"then
   out.games=out.games+1
   local capture=c.detail_capture or {};local team=run.incidents and run.incidents.team
   if capture.friendly_fire or team and team.friendly_fire~=nil then
    out.friendly.games=out.friendly.games+1
    for _,field in ipairs({"friendly_fire","murders","suicides"})do local key=field=="friendly_fire"and "damage"or field;out.friendly[key]=out.friendly[key]+(team and team[field]or 0)end
   end
   if run.leave_abuse or run.failed_leave_abuse then
    out.leaves.games=out.leaves.games+1
    for _,list in ipairs({run.leave_abuse or {},run.failed_leave_abuse or {}})do for _,entry in pairs(list)do out.leaves.attempts=out.leaves.attempts+(entry.count or 0)end end
   end
   local roster={};for id,p in pairs(c.operative_roster or {})do roster[tostring(id)]=p end
   roster[tostring(c.character)]=roster[tostring(c.character)]or {class=c.class,personal=true}
   if c.class then local v=out.personal[c.class]or bucket();out.personal[c.class]=v;v.games=v.games+1;if run.victory then v.wins=v.wins+1 end end
   local totals={};local damage=run.team_damage
   if damage then
    local team=T.summary(damage,nil,"total").useful;out.damage=out.damage+team;out.damage_games=out.damage_games+1
    for _,key in pairs({"unarmored","armored","super_armor","berserker","resistant","disgustingly_resilient","unknown"})do out.armour[key]=(out.armour[key]or 0)+T.summary(damage,nil,"total",key).useful end
    for id,p in pairs(damage.members or {})do local actor=roster[tostring(id)];local class=p.class or actor and actor.class;if class and id~="unknown_operative"then local n=T.summary(damage,id,"total").useful;totals[class]=(totals[class]or 0)+n end end
    for class,n in pairs(totals)do local v=out.classes[class]or bucket();out.classes[class]=v;v.damage=v.damage+n;v.team_damage=v.team_damage+team;v.damage_games=v.damage_games+1 end
    local personal=damage.members and damage.members[tostring(c.character)]
    if personal and c.class then local v=out.personal[c.class]or bucket();out.personal[c.class]=v;v.damage=v.damage+T.summary(damage,tostring(c.character),"total").useful;v.damage_games=v.damage_games+1 end
   end
   if run.party_records then
    out.kill_games=out.kill_games+1
    local fixed=run.party_records.fixed_roles
    if fixed then out.role_games=out.role_games+1 end
    for _,p in pairs(run.party_records.members or {})do local k=p.kills or {}
     if fixed then for _,pair in ipairs({{"trash_melee","trash_fixed_melee"},{"trash_ranged","trash_fixed_ranged"},{"elite_melee","elite_melee"},{"elite_ranged","elite_ranged"}})do out.kills[pair[1]]=out.kills[pair[1]]+(k[pair[2]]or 0)end end
     out.kills.horde=out.kills.horde+(k.horde_melee or 0)+(k.horde_ranged or 0)
     for _,key in ipairs({"special","elite","boss"})do out.kills[key]=out.kills[key]+(k[key]or 0)end
    end
   end
   if run.incidents then
    local incidents=R.incident_counts(run);local team=incidents.team;local byclass={};local summed={downs=0,deaths=0,pickups=0}
    for id,p in pairs(roster)do if p.class then local v=byclass[p.class]or {downs=0,deaths=0,pickups=0};byclass[p.class]=v;local row=p.personal and incidents.personal or incidents.members and incidents.members[id]and incidents.members[id].counts;add(v,row);add(summed,row)end end
    summed.pickups=summed.pickups+(incidents.unattributed_pickups or 0)+(incidents.bot_pickups or 0)
    add(out.defense,{downs=team and team.downs or summed.downs,deaths=team and team.deaths or summed.deaths,pickups=team and team.pickups or summed.pickups});out.defense_games=out.defense_games+1
    for class,counts in pairs(byclass)do local v=out.classes[class]or bucket();out.classes[class]=v;add(v.defense,counts);v.defense_games=v.defense_games+1 end
    if c.class then local v=out.personal[c.class]or bucket();out.personal[c.class]=v;add(v.defense,incidents.personal);v.defense_games=v.defense_games+1 end
   end
  end
 end
 return out
end
-- Completed outcomes only: an early leave's synthetic loss is not an extrema sample.
function A.extreme_eligible(run,include_excluded)
 local c=run.context or {}
 return type(run.victory)=="boolean"and not run.interrupted and run.run_kind~="early_leave"
  and not run.discarded and not run.hidden_contributions and (include_excluded or not run.stats_excluded)and not run.data_only
  and not c.training_history_test and c.difficulty~="psykhanium"and c.difficulty~="TEST ONLY"
end
-- Per-run extrema share the average projection's eligibility rules. Each metric
-- keeps its own source match; missing measurements are not converted to zero.
function A.extreme_row(run,T,R,summary)
 if not A.extreme_eligible(run,true)then return {}end
 local a=summary or A.build({run},nil,T,R);local out={};local c=run.context or {}
 local function put(key,n)
  if type(n)~="number"or n~=n then return end
  local v=out[key]
  if not v then out[key]={low=n,high=n}
  else if n<v.low then v.low=n end;if n>v.high then v.high=n end end
 end
 if (a.games or 0)==0 then return out end
 if (a.damage_games or 0)>0 then
  put("damage",a.damage)
  if a.damage>0 then for k,n in pairs(a.armour)do put("armour."..k,n/a.damage)end end
  for id,p in pairs(run.team_damage and run.team_damage.members or {})do
   if id~="unknown_operative"then
    local actor=(c.operative_roster or {})[tostring(id)]or {}
    local class=p.class or actor.class or (tostring(id)==tostring(c.character)and c.class)
    if class then
     local raw=T.summary(run.team_damage,id,"total").useful
     put("class."..class..".damage",raw)
     if a.damage>0 then put("class."..class..".share",raw/a.damage)end
    end
   end
  end
 end
 local me=c.class and a.personal[c.class]
 if me and (me.damage_games or 0)>0 then put("personal.damage",me.damage)end
 if (a.kill_games or 0)>0 then for _,k in ipairs({"horde","elite","special","boss"})do put("kills."..k,(a.kills[k]or 0)/a.kill_games)end end
 if (a.role_games or 0)>0 then for _,k in ipairs({"trash_melee","trash_ranged","elite_melee","elite_ranged"})do put("kills."..k,(a.kills[k]or 0)/a.role_games)end end
 if (a.defense_games or 0)>0 then
  for k,n in pairs(a.defense)do put("defense."..k,n/a.defense_games)end
  local counts=R.incident_counts(run)
  if counts.personal then for _,k in ipairs({"downs","deaths","pickups"})do
   put("personal.defense."..k,(counts.personal[k]or 0)/a.defense_games)
   if c.class then put("class."..c.class..".defense."..k,(counts.personal[k]or 0)/a.defense_games)end
  end end
  -- a teammate with no incident has no members row, so the roster counts them as 0, as Average does
  for id,actor in pairs(c.operative_roster or {})do if not actor.personal and tostring(id)~=tostring(c.character)then
   local p=counts.members and counts.members[tostring(id)]or {};local class=p.class or actor.class
   if class then for _,k in ipairs({"downs","deaths","pickups"})do
    put("class."..class..".defense."..k,((p.counts or {})[k]or 0)/a.defense_games)
   end end
  end end
 end
 if (a.friendly and a.friendly.games or 0)>0 then
  for _,k in ipairs({"damage","murders","suicides"})do put("friendly."..k,(a.friendly[k]or 0)/a.friendly.games)end
 end
 return out
end
function A.extremes(history,mode,rows,selection)
 local out={};local field=selection=="lowest"and "low"or "high"
 for _,run in ipairs(history or {})do if A.extreme_eligible(run)and (not mode or (run.context or {}).mode==mode)then
  local values=rows and rows[tostring(run.id)]or {}
  for key,pair in pairs(values)do
   local n=pair[field];local id=run.id
   if n~=nil and (out[key]==nil or (field=="low"and n<out[key])or (field=="high"and n>out[key]))then
    out[key]=n;out[key..".id"]=id
   end
  end
 end end
 return out
end
-- Disposable per-match projections let filtered overviews sum small numbers
-- without reopening every detailed damage/party file during navigation.
-- A prepare runs in slices: each step works until more() says stop, always building at least one row, and returns true once every row is done.
function A.prepare_job(history,T,R,previous,token)return {history=history or {},T=T,R=R,previous=previous,token=token,out={rows={},extremes={},tokens={}},i=0}end
function A.prepare_step(job,more)
 local history,out,previous,built=job.history,job.out,job.previous,false
 while job.i<#history do
  if built and more and not more()then return false end
  job.i=job.i+1;local run=history[job.i]
  if not run.hidden_contributions then
   local id=tostring(run.id);local key=job.token(run)
   local reuse=previous and previous.tokens and previous.tokens[id]==key
   local row=reuse and previous.rows[id]
   local values=reuse and previous.extremes and previous.extremes[id]
   -- A fresh row decodes a whole match file; step the collector after each, or a full rebuild piles up hundreds of MB of dead matches before Lua starts its next cycle.
   if not row or not values then
    row=row or A.build({run},(run.context or {}).mode,job.T,job.R)
    values=A.extreme_row(run,job.T,job.R,row);collectgarbage("step",4096);built=true
   end
   out.rows[id]=row;out.extremes[id]=values;out.tokens[id]=key
  end
 end
 return true
end
function A.prepare(history,T,R,previous,token)local job=A.prepare_job(history,T,R,previous,token);A.prepare_step(job);return job.out end
function A.rows(data,R,labels,damage_class,defense_class,format,options)
 options=options or {}
 local left,right={},{};local function row(list,text,heading,kind)local r={text=text,heading=heading,kind=kind};r.height=math.max(heading and 32 or 25,options.measure and options.measure(r)or 0);list[#list+1]=r end
 local function gap(list)list[#list+1]={text="",height=12}end
 local function average(n,d)return format(n/d)end
 row(left,"Team Damage Stats, no overkill",true)
 if data.damage_games>0 then row(left,"Average Team Damage: "..average(data.damage,data.damage_games))end
 local p=data.personal[damage_class];if damage_class then row(left,"Personal Damage Class",false,"damage_class")end;if p and p.damage_games>0 then row(left,"Average Personal Damage: "..average(p.damage,p.damage_games))end
 local classes={};for c in pairs(data.classes)do classes[#classes+1]=c end;table.sort(classes,function(a,b)return R.class_name(a)<R.class_name(b)end)
 local damage_classes={};for _,c in ipairs(classes)do if data.classes[c].damage_games>0 then damage_classes[#damage_classes+1]=c end end
 table.sort(damage_classes,function(a,b)
  local x,y=data.classes[a],data.classes[b]
  local xs=x.team_damage>0 and x.damage/x.team_damage or 0;local ys=y.team_damage>0 and y.damage/y.team_damage or 0
  if xs~=ys then return xs>ys end
  return R.class_name(a)<R.class_name(b)
 end)
 for _,c in ipairs(damage_classes)do local v=data.classes[c];if v.damage_games>0 then row(left,R.class_name(c)..": "..average(v.damage,v.damage_games).." ("..string.format("%.1f%%",v.team_damage>0 and 100*v.damage/v.team_damage or 0).." of Team Damage)")end end
 gap(left);row(left,"Average Enemies Killed Per Game",true)
 if data.kill_games>0 then for _,e in ipairs({{"horde","Trash Enemies"},{"elite","Elites"},{"special","Specials"},{"boss","Bosses"}})do row(left,e[2]..": "..average(data.kills[e[1]],data.kill_games));if (data.role_games or 0)>0 and (e[1]=="horde"or e[1]=="elite")then local prefix=e[1]=="horde"and "trash"or "elite";for _,kind in ipairs({"ranged","melee"})do row(left,"   "..(kind=="ranged"and "Ranged"or "Melee")..": "..average(data.kills[prefix.."_"..kind]or 0,data.role_games))end end end end
 row(right,"Average Armour Breakdown",true);right[#right].hover={"Shares of effective damage, excluding overkill.","These are damage shares, not shares of enemies.","Armour is taken from saved damage attribution; older/remote reports may lack hit-zone resolution."}
 if data.damage>0 then local keys={};for key,n in pairs(data.armour)do if n>0 then keys[#keys+1]=key end end;table.sort(keys,function(a,b)return data.armour[a]>data.armour[b]end);for _,key in ipairs(keys)do row(right,(labels[key]or "Unknown Armour-Type")..": "..string.format("%.1f%%",100*data.armour[key]/data.damage))end end

 if options.enemy_lines then gap(right);row(right,"Enemy Breakdown",true);row(right,"",false,"enemy_controls");for _,line in ipairs(options.enemy_lines)do row(right,line)end end
 local function defense(title,v,kind,target,align)target=target or right;if v and v.defense_games>0 then row(target,title,true);target[#target].card_align=align;if kind then row(target,"Class",false,kind)end;for _,key in ipairs({"downs","deaths","pickups"})do row(target,({downs="Downs",deaths="Deaths",pickups="Pickups"})[key]..": "..average(v.defense[key],v.defense_games))end;gap(target)end end
 -- Defensive blocks begin below both upper columns and share aligned rows.
 local function height(list)local n=0;for _,r in ipairs(list)do n=n+(r.height or (r.heading and 32 or 25))end;return n end
 local top=math.max(height(left),height(right))+28
 local function pad(list,y)local n=height(list);if n<y then list[#list+1]={text="",height=y-n}end end
 pad(left,top);pad(right,top)
 defense("Average Team Defensive Stats",data,nil,left,"defense_totals")
 if data.personal[defense_class]and data.personal[defense_class].defense_games>0 then defense("Personal Defensive Stats",data.personal[defense_class],"defense_class",right,"defense_totals")elseif defense_class then row(right,"Personal Defensive Stats",true,"defense_class");right[#right].card_align="defense_totals";gap(right)end
 local block_top=math.max(height(left),height(right));local col=0;local pair=1
 for _,c in ipairs(classes)do if data.classes[c].defense_games>0 then
  local target=col==0 and left or right;pad(target,block_top)
  defense("Average Defensive Stats for "..R.class_name(c),data.classes[c],nil,target,"defense_classes_"..pair)
  if col==1 then block_top=math.max(height(left),height(right));pair=pair+1 end;col=1-col
 end end
 local incidents_top=math.max(height(left),height(right))+20;pad(left,incidents_top);pad(right,incidents_top)
 local friendly=data.friendly or {};local friendly_lines={}
 for _,entry in ipairs({{"damage","Damage Dealt"},{"murders","Murders"},{"suicides","Suicides"}})do
  if (friendly.games or 0)>0 and (friendly[entry[1]]or 0)/friendly.games>=0.05 then friendly_lines[#friendly_lines+1]=entry[2]..": "..average(friendly[entry[1]],friendly.games)end
 end
 if #friendly_lines>0 then row(left,"Average Team Friendly Fire",true);left[#left].card_align="incident_averages";for _,line in ipairs(friendly_lines)do row(left,line)end end
 local leaves=data.leaves or {}
 if options.show_leave_abuse and (leaves.games or 0)>0 and (leaves.attempts or 0)/leaves.games>=0.05 then row(right,"Average Leave-Scumming",true);right[#right].card_align="incident_averages";row(right,"Attempts: "..average(leaves.attempts,leaves.games))end

 local rows={};local bottom=0;for col,list in ipairs({left,right})do local y=0;for _,r in ipairs(list)do r.col=col-1;r.y=y;r.height=r.height or (r.heading and 32 or 25);rows[#rows+1]=r;y=y+r.height end;bottom=math.max(bottom,y)end
 return rows,bottom
end
return A

