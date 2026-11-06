-- Regular observed measurements. No damage prediction, buff, ammo or reload research.
local E={version=1}
local function copy(v)if type(v)~="table"then return v end;local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out end
local function finite(n)return type(n)=="number"and n==n and math.abs(n)<math.huge end
local function add(t,k,n)t[k]=(t[k]or 0)+(n or 1)end
function E.from_legacy(data)
 if not data then return end
 if data.status=="not_recorded"then return {version=1,status="not_recorded"}end
 if data.segments then local out={version=1,status="observed",segments={}};for _,part in ipairs(data.segments)do out.segments[#out.segments+1]=E.from_legacy(part)or {status="not_recorded"}end;return out end
 local out={version=1,status="observed",weapons={},coverage={}}
 for _,key in ipairs({"peril","peril_timeline","engagement_distance","distance_definitions","distance_class"})do out[key]=copy(data[key])end
 for id,w in pairs(data.weapons or {})do if w.engagement_distance then out.weapons[id]={label=w.label,engagement_distance=copy(w.engagement_distance)}end end
 return out
end
function E.new(saved)return {data=saved or {version=1,status="observed",weapons={},coverage={}}}end
function E.distance(s,snapshot,killed,distance,useful,kill_distance_known,weapon_only)
 local defs=s.data.distance_definitions
 if not defs or not finite(defs.close)or not finite(defs.far)or defs.far<=defs.close then return end
 if not snapshot or snapshot.category~="ranged"and snapshot.category~="explosion"then return end
 local data=s.data.engagement_distance
 if not data then data={version=1,categories={}};s.data.engagement_distance=data end
 local category=snapshot and snapshot.category or "unknown"
 if category~="ranged"and category~="explosion"then category="other"end
 local scope=data.categories[category];if not scope then scope={bands={},kill_bands={}};data.categories[category]=scope end
 local scopes=weapon_only and {}or {scope}
 local weapon=snapshot and snapshot.weapon;local w=weapon and s.data.weapons[weapon]
 if w then w.engagement_distance=w.engagement_distance or {bands={},kill_bands={}};scopes[#scopes+1]=w.engagement_distance end
 local function bucket(t,k)local b=t[k];if not b then b={hits=0,kills=0,damage=0,damage_samples=0};t[k]=b end;return b end
 local known=finite(distance)and distance>=0
 local class=s.data.distance_class
 local gradient=category=="ranged"and(class=="zealot"or class=="veteran"or class=="broker")
 local far_weight=known and gradient and math.sqrt(math.max(0,math.min(1,(distance-defs.close)/(defs.far-defs.close))))or nil
 local band
 if gradient then band=not known and "unknown"or distance<defs.close and "close"or distance==defs.close and "close_boundary"or far_weight<.25 and "gradient_0_25"or far_weight<.5 and "gradient_25_50"or far_weight<.75 and "gradient_50_75"or far_weight<1 and "gradient_75_100"or "far"end
 if not gradient then band=not known and "unknown"or distance<defs.close and "close"or "outside_close"end
 for _,scope in ipairs(scopes)do
 local b=bucket(scope.bands,band);add(b,"hits")
 if finite(useful)then add(b,"damage",useful);add(b,"damage_samples")end
 if killed then local kb=bucket(scope.kill_bands,known and kill_distance_known~=false and band or "unknown");add(kb,"kills")end
 local close_key=known and (distance<defs.close and "close"or "outside_close")or "unknown"
 scope.close_range=scope.close_range or {};local c=bucket(scope.close_range,close_key);add(c,"hits");if finite(useful)then add(c,"damage",useful);add(c,"damage_samples")end
 scope.close_range_kills=scope.close_range_kills or {};if killed then local k=known and kill_distance_known~=false and close_key or "unknown";add(scope.close_range_kills,k)end
 local class=s.data.distance_class
 if known and category=="ranged"and (class=="zealot"or class=="veteran"or class=="broker")then
  scope.curve=scope.curve or {samples=0,near_weight_sum=0,far_weight_sum=0,damage_weighted_near=0,damage_weighted_far=0,damage_samples=0,damage_weight=0}
  local g=scope.curve;add(g,"samples");add(g,"near_weight_sum",1-far_weight);add(g,"far_weight_sum",far_weight)
  if finite(useful)then add(g,"damage_weighted_near",useful*(1-far_weight));add(g,"damage_weighted_far",useful*far_weight);add(g,"damage_samples");add(g,"damage_weight",useful)end

 end
 end
end
function E.peril(s,id,personal,value,dt)
 if not id or not finite(dt)or dt<=0 then return end
 s.data.peril=s.data.peril or {version=1,members={}}
 local rows=s.data.peril.members;local row=rows[id]
 if not row then local n=0;for _ in pairs(rows)do n=n+1 end;if n>=16 then add(s.data.coverage,"peril_members_dropped");return end;row={source=personal and "local_component"or "replicated_component",observed_seconds=0,missing_seconds=0,weighted_peril=0,seconds_by_percent={}};rows[id]=row end
 if not finite(value)or value<0 or value>1 then add(row,"missing_seconds",dt);return end
 add(row,"observed_seconds",dt);add(row,"weighted_peril",value*dt)
 add(row.seconds_by_percent,tostring(math.min(100,math.floor(value*100))),dt)
end
function E.merge(a,b)
 if not a and not b then return end
 local out={version=1,status="observed",segments={}}
 local function append(v)if not v then out.segments[#out.segments+1]={version=1,status="not_recorded"}elseif v.segments then for _,segment in ipairs(v.segments)do out.segments[#out.segments+1]=copy(segment)end else out.segments[#out.segments+1]=copy(v)end end
 append(a);append(b);return out
end
return E
