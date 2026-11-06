-- Existing boss reducers, composed into the shared Records facade.
return function(Records)
function Records:class_bosses(patch,mode,class)
 self.data.class_boss_tallies=self.data.class_boss_tallies or {};local g=self.data.class_boss_tallies;g[patch]=g[patch] or {};g[patch][mode]=g[patch][mode] or {};g[patch][mode][class]=g[patch][mode][class] or {};return g[patch][mode][class]
end
function Records:initialize_class_bosses()
 if self.data.class_bosses_initialized then return end
 for _,run in ipairs(self.data.run_history or {}) do local c=run.context;for id,entry in pairs(run.boss_kills or {}) do local totals=self:class_bosses(c.patch,c.mode,c.class);local old=totals[id] or {label=entry.label,count=0};totals[id]=old;old.count=old.count+entry.count end end
 self.data.class_bosses_initialized=true;self.dirty=true
end
function Records:boss_defeated(id,label,token,weakened)
 local m=self.mission;if not m then return false end
 m.boss_seen=m.boss_seen or {};if m.boss_seen[token] then return false end;m.boss_seen[token]=true
 local scoped=self:class_bosses(m.context.patch,m.context.mode,m.context.class);local c=scoped[id] or {label=label,count=0};scoped[id]=c;c.count=c.count+1;if weakened then c.weakened=(c.weakened or 0)+1 end
 m.boss_kills=m.boss_kills or {};local event=m.boss_kills[id] or {label=label,count=0};m.boss_kills[id]=event;event.count=event.count+1;if weakened then event.weakened=(event.weakened or 0)+1 end
 self.data.boss_tallies=self.data.boss_tallies or {};local groups=self.data.boss_tallies;local patch=m.context.patch;groups[patch]=groups[patch] or {};groups[patch][m.context.mode]=groups[patch][m.context.mode] or {};local totals=groups[patch][m.context.mode]
 local value=totals[id] or {label=label,count=0};totals[id]=value;value.count=value.count+1;if weakened then value.weakened=(value.weakened or 0)+1 end;self.dirty=true;return true
end
function Records:boss_killing_blow(id,label,token,weakened)
 local m=self.mission;if not m or id=="hexbound_ritual" then return false end
 m.boss_credit_seen=m.boss_credit_seen or {};if m.boss_credit_seen[token] then return false end;m.boss_credit_seen[token]=true
 -- Death reports and team death notifications can arrive in either order.
 m.boss_kills=m.boss_kills or {};local e=m.boss_kills[id] or {label=label,count=0};m.boss_kills[id]=e
 e.personal=(e.personal or 0)+1;if weakened then e.personal_weakened=(e.personal_weakened or 0)+1 end
 self.dirty=true;return true
end
function Records:boss_operative_killing_blow(actor,class,personal,identity,id,label,token,weakened)
 local m=self.mission;if not m or id=="hexbound_ritual"then return false end
 m.boss_operative_seen=m.boss_operative_seen or {};if m.boss_operative_seen[token]then return false end;m.boss_operative_seen[token]=true
 m.boss_operatives=m.boss_operatives or {};local row=m.boss_operatives[actor]or {class=class,personal=personal,friend_name=identity and identity.friend_name,total=0,real=0,weakened=0};m.boss_operatives[actor]=row
 row.total=row.total+1;local kind=weakened and "weakened"or "real";row[kind]=row[kind]+1;Records.mark_reached(m.boss_operatives,row,"total");Records.mark_reached(m.boss_operatives,row,kind)
 if personal then self:boss_killing_blow(id,label,token,weakened)end
 self.dirty=true;return true
end
function Records:complete_boss_records(m)
 local previous=self.mission;if not m.id then self.mission=m end
 local totals={personal={total=0,real=0,weakened=0},team={total=0,real=0,weakened=0}};local rituals=0
 for id,e in pairs(m.boss_kills or {})do
  if id=="hexbound_ritual"then rituals=rituals+(e.count or 0)
  else
   local t,p=e.count or 0,e.personal or 0;local tw,pw=e.weakened or 0,e.personal_weakened or 0
   totals.team.total=totals.team.total+t;totals.team.weakened=totals.team.weakened+tw;totals.team.real=totals.team.real+t-tw
   totals.personal.total=totals.personal.total+p;totals.personal.weakened=totals.personal.weakened+pw;totals.personal.real=totals.personal.real+p-pw
  end
 end
 for scope,values in pairs(totals)do for kind,n in pairs(values)do self:best(m.context,scope.."_boss_"..kind.."_mission",n)end end
 self:best(m.context,"team_ritual_stops_mission",rituals)
 for _,kind in ipairs({"total","real","weakened"})do local name="teammate_boss_"..kind.."_mission"
  for _,id in ipairs(Records.reach_order(m.boss_operatives,kind,m.record_credits and m.record_credits[name]))do local person=m.boss_operatives[id];if not person.personal then self:incident_record(name,person[kind]or 0,person.class,person)end end
 end
 self.mission=previous
end
function Records:normalize_boss_records()
 if self.data.boss_records_0470 then return end
 local excluded={renegade_captain=true,cultist_captain=true,["Scab Captain"]=true,["Admonition Champion"]=true}
 local function unknown(name)return type(name)=="string" and (excluded[name] or name:find("Scab Captain",1,true) or name:find("Admonition Champion",1,true))end
 local function remove(entries)if type(entries)=="table"then for id,e in pairs(entries)do if excluded[id] or type(e)=="table" and unknown(e.label)then entries[id]=nil end end end end
 for _,patch in pairs(self.data.boss_tallies or {})do for _,entries in pairs(patch)do remove(entries)end end
 for _,patch in pairs(self.data.class_boss_tallies or {})do for _,mode in pairs(patch)do for _,entries in pairs(mode)do remove(entries)end end end
 for _,run in ipairs(self.data.run_history or {})do remove(run.boss_kills)end
 for _,row in pairs(self.data.rows or {})do
  for enemy in pairs(row.enemy_hits or {})do if unknown(enemy)then row.enemy_hits[enemy]=nil end end
  local function clear(best,sources,runs)
   for metric,source in pairs(sources or {})do if unknown(source.enemy)then if best then best[metric]=nil end;sources[metric]=nil;if runs then runs[metric]=nil end end end
  end
  clear(row.best,row.best_weapons,row.best_runs)
  for _,bucket in pairs(row.armour_best or {})do clear(bucket.best,bucket.sources)end
 end
 -- Accepted historical matches can supply team totals; absent killing-blow data is not invented.
 for _,run in ipairs(self.data.run_history or {})do
  if run.context and not run.data_only and not run.context.training_history_test and run.context.difficulty~="psykhanium"then
   self:complete_boss_records(run)
   local totals={total=0,real=0,weakened=0};local rituals=0
   for id,e in pairs(run.boss_kills or {})do if id=="hexbound_ritual"then rituals=rituals+(e.count or 0)else totals.total=totals.total+(e.count or 0);totals.weakened=totals.weakened+(e.weakened or 0);totals.real=totals.real+(e.count or 0)-(e.weakened or 0)end end
   for _,row in ipairs(self:rows_for(run.context))do row.best_runs=row.best_runs or {};for kind,n in pairs(totals)do local metric="team_boss_"..kind.."_mission";if n>0 and row.best[metric]==n and not row.best_runs[metric]then row.best_runs[metric]=run.id end end;if rituals>0 and row.best.team_ritual_stops_mission==rituals and not row.best_runs.team_ritual_stops_mission then row.best_runs.team_ritual_stops_mission=run.id end end
  end
 end
 -- Historical weakened status was not collected: missing values mean full-strength.
 self.data.boss_records_0470=true;self.dirty=true
end
end
