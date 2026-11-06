-- Incident reducers composed into Records; shared survival definitions stay in the facade.
return function(Records,deep_copy,key,survival_events)
function Records:survival_event(event)
    if event == "peril_detonated" then return self:psyker_explosion() end
    local m, definition = self.mission, survival_events[event]
    if not m or not definition then return false end
    m.failed[event] = true
    if m.context then local record=self:mode_streak(m.context.patch,m.context.mode);local scoped=self:class_mode_streak(m.context.patch,m.context.mode,m.context.class);for id,d in pairs(Records.mode_streak_fields or {}) do if d.event==event then record.current[id]=0;scoped.current[id]=0 end end end
    local row = self:mission_row(m.context)
    row[definition.current] = 0
    if event == "mutant_charged" then
        m.mutant_catches = (m.mutant_catches or 0) + 1
        row.best.mutant_charges_mission = math.max(row.best.mutant_charges_mission or 0, m.mutant_catches)
    end
    if event == "knocked_down" then
        m.personal_downs = (m.personal_downs or 0) + 1
        row.best.personal_downs_mission = math.max(row.best.personal_downs_mission or 0, m.personal_downs)
    end
    self.dirty = true
    return true
end

local incident_fields={knocked_down="downs",dog_pounced="pounces",trapper_netted="nets",mutant_charged="mutant_charges",died="deaths",pickup="pickups"}
-- Each rise in a teammate's count is numbered, so a tie goes to whoever reached it first, in play and in a rebuild alike.
function Records.mark_reached(people,person,field)
 local n=0;for _,p in pairs(people)do if type(p)=="table"and type(p.reached)=="table"then for _,v in pairs(p.reached)do if type(v)=="number"and v>n then n=v end end end end
 person.reached=type(person.reached)=="table"and person.reached or {};person.reached[field]=n+1
end
local function names(credit,p,who)who=type(who)=="table"and who or p;return type(credit)=="table"and (p.class or "unknown-class")==credit.class and who.friend_name==credit.friend_name end
-- Ids of the people, the one a tie goes to first, never by pairs() order: the highest count, and of those on it, whoever reached it first.
-- A match saved before counts were numbered gives it to the operative its saved record names (credit, or credit(x,y) when first needed),
-- then the lowest id. The rest follow in any order, as none of them can take the record from the first. The player's own row never leads.
function Records.reach_order(people,field,credit,identities,x,y)
 local list,best,bn,ba,bp={}
 for id,p in pairs(people or {})do if type(p)=="table"then list[#list+1]=id
  if not p.personal then local c,r,take=p.counts,p.reached;local n,at
   if type(c)=="table"then n=c[field]else n=p[field]end;if type(n)~="number"then n=0 end
   if type(r)=="table"then at=r[field];if type(at)~="number"then at=nil end end
   if best==nil or n>bn then take=true
   elseif n==bn then
    if (at or ba)and at~=ba then take=at~=nil and (ba==nil or at<ba)
    else
     local a,b=false,false
     if not at then if type(credit)=="function"then credit=credit(x,y)or false end;if credit then a,b=names(credit,p,identities and identities[id]),names(credit,bp,identities and identities[best])end end
     if a~=b then take=a elseif type(id)~=type(best)then take=type(id)<type(best)else take=id<best end
    end
   end
   if take then best,bn,ba,bp=id,n,at,p end
  end
 end end
 for i,id in ipairs(list)do if id==best then list[i]=list[1];list[1]=id;break end end
 return list
end
-- The operative each saved teammate record names, by the match holding it.
function Records.record_credits(rows)
 local out={}
 for _,row in pairs(rows or {})do if type(row)=="table"then for name,id in pairs(row.best_runs or {})do local src=row.best_weapons and row.best_weapons[name]
  if id~=nil and type(src)=="table"and type(name)=="string"and name:find("teammate_",1,true)==1 then out[id]=out[id]or {};out[id][name]=src end
 end end end
 return out
end
function Records:incident_record(name,value,class,identity)
    local m=self.mission;if not m then return end
    local row=self:mission_row(m.context)
    if value>(row.best[name] or -1) or value==row.best[name] and not (row.best_weapons and row.best_weapons[name]) then
        row.best[name]=value;row.best_weapons=row.best_weapons or {};row.best_weapons[name]={class=class or (name:find("teammate_",1,true)==1 and "unknown-class") or m.context.class}
        if identity and identity.friend_name then row.best_weapons[name].friend_name=identity.friend_name end
        m.record_values=m.record_values or {};m.record_values[name]=value
        m.record_updates=m.record_updates or {};row.best_runs=row.best_runs or {}
        m.record_updates[#m.record_updates+1]={row=row,name=name,value=value}
        self.dirty=true
    end
end
function Records:incident(event,personal,member,class)
    local m=self.mission;local field=incident_fields[event];if not m or not field then return end
    m.incidents=m.incidents or {personal={},team={},members={}}
    local stats=m.incidents;stats.team[field]=(stats.team[field] or 0)+1
    self:incident_record("team_"..field.."_mission",stats.team[field])
    if event=="knocked_down" then m.team_downs=stats.team[field] end
    if event=="pickup" and not personal and not member then stats.unattributed_pickups=(stats.unattributed_pickups or 0)+1 end
    if personal then
        stats.personal[field]=(stats.personal[field] or 0)+1
        local id=field=="mutant_charges" and "mutant_charges_mission" or "personal_"..field.."_mission"
        self:incident_record(id,stats.personal[field])
        if event=="died" then m.failed.died=true;m.failed.knocked_down=true;self:mission_row(m.context).undowned_current=0;self:mission_row(m.context).death_free_current=0;self:mode_streak(m.context.patch,m.context.mode).current.undowned=0;local scoped=self:class_mode_streak(m.context.patch,m.context.mode,m.context.class);scoped.current.undowned=0;scoped.current.death_free=0 end
    elseif member then
        local person=stats.members[member] or {class=class,counts={}};stats.members[member]=person
        person.counts[field]=(person.counts[field] or 0)+1;person.class=class or person.class;Records.mark_reached(stats.members,person,field)
        self:incident_record("teammate_"..field.."_mission",person.counts[field],person.class,m.context.operative_identities and m.context.operative_identities[member])
    end
end
-- Reported damage attribution and estimated specialist kick outcomes.
function Records:friendly_fire_pair(actor,victim,damage,outcome,source)
 local m=self.mission;if not m then return end;actor=actor or "unknown_operative";victim=victim or "unknown_operative"
 m.friendly_fire_pairs=m.friendly_fire_pairs or {};local pairs=m.friendly_fire_pairs;pairs[actor]=pairs[actor]or {};local row=pairs[actor][victim]or {damage=0,murders=0,suicides=0};pairs[actor][victim]=row
 if type(damage)=="number"and damage>0 then
  row.damage=row.damage+damage
  row.damage_sources=row.damage_sources or {version=1};local key=source or "other"
  row.damage_sources[key]=(row.damage_sources[key]or 0)+damage
 end
 if outcome=="murder"then row.murders=row.murders+1 elseif outcome=="suicide"then row.suicides=row.suicides+1 end
 self.dirty=true
end
function Records.incident_counts(run)
 local stats=deep_copy(run.incidents or {personal={},team={},members={}});local converted=0
 for _,e in ipairs(run.lethality_events or {})do if e.outcome=="down_to_death"then
  converted=converted+1;local counts=e.personal and stats.personal or e.victim and stats.members and stats.members[e.victim]and stats.members[e.victim].counts
  if counts then counts.downs=math.max(0,(counts.downs or 0)-1)end
 end end
 if stats.team then stats.team.downs=math.max(0,(stats.team.downs or 0)-converted)end
 return stats
end

function Records:finalize_distinct_incidents(m)
 if not m or not m.incidents then return end;local converted=false;for _,e in ipairs(m.lethality_events or {})do if e.outcome=="down_to_death"then converted=true;break end end;if not converted then return end;local previous=self.mission;self.mission=m
 local fields={"personal_downs_mission","team_downs_mission","teammate_downs_mission"}
 if not m.recalculating and m.data_before then for _,row in ipairs(self:rows_for(m.context))do local before=m.data_before and m.data_before.rows and m.data_before.rows[key(row.context,row.aggregate)]
  for _,field in ipairs(fields)do row.best[field]=before and before.best[field]or nil;row.best_weapons=row.best_weapons or {};row.best_weapons[field]=before and before.best_weapons and deep_copy(before.best_weapons[field])or nil;row.best_runs=row.best_runs or {};row.best_runs[field]=before and before.best_runs and before.best_runs[field]or nil end
 end end
 if not m.data_only then local counts=Records.incident_counts(m);self:incident_record("personal_downs_mission",counts.personal and counts.personal.downs or 0);self:incident_record("team_downs_mission",counts.team and counts.team.downs or 0)
  local who=m.context.operative_identities
  for _,id in ipairs(Records.reach_order(counts.members,"downs",m.record_credits and m.record_credits.teammate_downs_mission,who))do local p=counts.members[id];self:incident_record("teammate_downs_mission",p.counts and p.counts.downs or 0,p.class,who and who[id])end
 end
 self.mission=previous
end

function Records:pickup_pair(actor,victim,state)
 local m=self.mission;if not m or not actor or not victim then return end
 m.pickup_pairs=m.pickup_pairs or {};m.pickup_pairs[actor]=m.pickup_pairs[actor]or {};m.pickup_pairs[actor][victim]=(m.pickup_pairs[actor][victim]or 0)+1;state=(state=="knocked_down"or state=="hogtied")and state or "unknown";if state then m.pickup_states=m.pickup_states or {};m.pickup_states[actor]=m.pickup_states[actor]or {};local row=m.pickup_states[actor][victim]or {};m.pickup_states[actor][victim]=row;row[state]=(row[state]or 0)+1 end;self.dirty=true
end
function Records:combat_incident(field,amount,personal,member,class,specialist)
    local m=self.mission
    if not m or (field~="friendly_fire" and field~="lethal_kicks" and field~="murders" and field~="suicides") or type(amount)~="number" or amount<=0 or amount~=amount or amount==math.huge then return end
    m.incidents=m.incidents or {personal={},team={},members={}}
    local stats=m.incidents;local row=self:mission_row(m.context)
    row.combat_totals=row.combat_totals or {}
    local function add(scope,values)
        values[field]=(values[field] or 0)+amount
        self:incident_record(scope.."_"..field.."_mission",values[field],class)
        local key=scope.."_"..field;row.combat_totals[key]=(row.combat_totals[key] or 0)+amount
        if specialist then values.kicks_by_specialist=values.kicks_by_specialist or {};values.kicks_by_specialist[specialist]=(values.kicks_by_specialist[specialist] or 0)+amount end
    end
    add("team",stats.team)
    if personal then add("personal",stats.personal)
    elseif member then
        local person=stats.members[member] or {class=class,counts={}};stats.members[member]=person;person.class=class or person.class
        person.counts[field]=(person.counts[field] or 0)+amount;Records.mark_reached(stats.members,person,field)
        self:incident_record("teammate_"..field.."_mission",person.counts[field],person.class,m.context.operative_identities and m.context.operative_identities[member])
        if specialist then person.counts.kicks_by_specialist=person.counts.kicks_by_specialist or {};person.counts.kicks_by_specialist[specialist]=(person.counts.kicks_by_specialist[specialist] or 0)+amount end
    end
    self.dirty=true
end
function Records:credit_bot_pickup()
 local m=self.mission;if not m or not m.incidents then return end;local stats=m.incidents;stats.unattributed_pickups=math.max(0,(stats.unattributed_pickups or 0)-1);stats.bot_pickups=(stats.bot_pickups or 0)+1;self.dirty=true
end
function Records:credit_pickup(personal,member,class)
    -- Upgrade an already-counted pickup whose helper became known later.
    local m=self.mission;if not m then return end;local stats=m.incidents
    stats.unattributed_pickups=math.max(0,(stats.unattributed_pickups or 0)-1)
    if personal then stats.personal.pickups=(stats.personal.pickups or 0)+1;self:incident_record("personal_pickups_mission",stats.personal.pickups)
    elseif member then local person=stats.members[member] or {class=class,counts={}};stats.members[member]=person;person.counts.pickups=(person.counts.pickups or 0)+1;Records.mark_reached(stats.members,person,"pickups");self:incident_record("teammate_pickups_mission",person.counts.pickups,class,m.context.operative_identities and m.context.operative_identities[member]) end
end
function Records:complete_incidents(m)
    if not m.incidents then return end
    if m.context.combat_tracking_v56 then
        for _,field in ipairs({"friendly_fire","lethal_kicks","murders","suicides"}) do for _,scope in ipairs({"personal","team","teammate"}) do local row=self:mission_row(m.context);local id=scope.."_"..field.."_mission";if row.best[id]==nil then row.best[id]=0 end end end
    end
    for _,field in pairs(incident_fields) do
        local row=self:mission_row(m.context)
        for _,id in ipairs({"team_"..field.."_mission",field=="mutant_charges" and "mutant_charges_mission" or "personal_"..field.."_mission","teammate_"..field.."_mission"}) do if row.best[id]==nil then row.best[id]=0;self.dirty=true end end
    end
end

function Records:lethality_state(victim,class,personal,state,sources,replace)
 local m=self.mission;if not m then return end;m.lethality_events=m.lethality_events or {};m.lethality_active=m.lethality_active or {}
 local index=m.lethality_active[victim];local e=index and m.lethality_events[index]
 if not e then e={victim=victim,class=class,personal=personal,outcome=state=="knocked_down" and "down" or "direct_death",sources=deep_copy(sources or {})};m.lethality_events[#m.lethality_events+1]=e;m.lethality_active[victim]=#m.lethality_events
 elseif state~="knocked_down" and e.outcome=="down" then e.outcome="down_to_death" end
 e.class=class or e.class
 -- A cause seen after the event, as Perils after its down, takes the enemy's place.
 if replace then for i=#e.sources,1,-1 do if e.sources[i].group~="environment" then table.remove(e.sources,i) end end end
 if #e.sources==0 and sources and #sources>0 then e.sources=deep_copy(sources) end
 if sources and #sources>0 and sources[1].enemy~="unknown_cause" then for i=#e.sources,1,-1 do if e.sources[i].enemy=="unknown_cause" then table.remove(e.sources,i) end end end
 -- A later fall report can add the environmental overlap to an already observed down/death.
 for _,source in ipairs(sources or {}) do local found=false;for _,old in ipairs(e.sources)do if old.enemy==source.enemy then found=true end end;if not found then e.sources[#e.sources+1]=deep_copy(source) end end
 self.dirty=true
end
function Records:lethality_recovered(victim)
 local m=self.mission;if m and m.lethality_active then m.lethality_active[victim]=nil end
end

end
