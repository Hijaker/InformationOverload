-- Immutable data files + one atomic catalog commit. Settings retain options only.
local S={};S.__index=S
local datasets={history_baseline_v1="history-baseline",lifetime_records_v1="general",solo_records_v1="solo",psykhanium_logs_v1="psykhanium"}
local legacy_keys={"lifetime_records_v1","solo_records_v1","psykhanium_logs_v1","stats_patch_group_v1","unfinished_run_v1","solo_unfinished_v1","patch_merge_backup_v1"}
local class_maps={class_overview=true,class_win_streaks=true,class_mode_streaks=true,class_boss_tallies=true,class_events=true}
local patch_maps={class_overview=true,mode_streaks=true,running_tallies=true,boss_tallies=true,blo_global=true,blo_weapons=true,maelstrom_streaks=true,class_win_streaks=true,class_mode_streaks=true,class_boss_tallies=true,class_events=true}
-- step, when given, is told how many entries each table held, so a save spread over frames can pause inside a big value
local function clone(v,step)local t={};if type(v)~="table"then return v end;local mt=getmetatable(v);if mt and mt.io_materialize then v=mt.io_materialize(v)end;local n=0;for k,x in pairs(v)do t[k]=clone(x,step);n=n+1 end;if step then step(n)end;return t end
local function equal(a,b,step)
 if type(a)~=type(b)then return false end;if type(a)~="table"then return a==b end
 local am,bm=getmetatable(a),getmetatable(b)
 if am and am.io_materialize then a=am.io_materialize(a)end
 if bm and bm.io_materialize then b=bm.io_materialize(b)end
 local n=0;for k,v in pairs(a)do if not equal(v,b[k],step)then return false end;n=n+1 end;for k in pairs(b)do if a[k]==nil then return false end end;if step then step(n)end;return true
end
S.equal=equal
local function validate_dataset(data)
 assert(type(data)=="table"and data.schema==1 and type(data.rows)=="table","Unsupported or damaged saved record format; original data was retained")
 assert(data.run_history==nil or type(data.run_history)=="table","Damaged match history; original data was retained")
end
local function safe(v)
 v=tostring(v or "unverified-patch"):gsub("[^%w_.%-]","_"):gsub("%.%.","_")
 if v==""or v=="."then return "unverified-patch"end;return v
end
-- JSON arrays preserve integer keys; sparse/mixed maps use explicit numeric-key tags.
local function pack(v,seen,step,sizes)
 if type(v)~="table"then
  assert(type(v)=="nil"or type(v)=="string"or type(v)=="number"or type(v)=="boolean","Unsupported saved value")
  if type(v)=="number"then assert(v==v and math.abs(v)<math.huge,"Non-finite saved number");if v%1~=0 or math.abs(v)>10000000000000 then return {["@float"]=string.format("%.17g",v)}end end
  return v
 end
 local mt=getmetatable(v);if mt and mt.io_materialize then v=mt.io_materialize(v)end
 seen=seen or {};assert(not seen[v],"Cyclic saved data");seen[v]=true
 local n,count,arr=0,0,true;for k in pairs(v)do count=count+1;if type(k)~="number"or k<1 or k%1~=0 then arr=false else n=math.max(n,k)end end;arr=arr and n==count and count>0
 local t,size={},1;for k,x in pairs(v)do local key=k
  if not arr then if type(k)=="number"then key="@n:"..string.format("%.17g",k)elseif type(k)=="string"then key=k:sub(1,1)=="@"and "@s:"..k or k else error("Unsupported saved key")end end
  local p=pack(x,seen,step,sizes);t[key]=p;if sizes then size=size+(sizes[p]or 1)end
 end;seen[v]=nil
 if sizes then sizes[t]=size;step(count)end
 return t
end
local function unpack_value(v,step)
 if type(v)~="table"then return v end
 if step then step()end
 if type(v["@float"])=="string"and next(v)=="@float"and next(v,"@float")==nil then return assert(tonumber(v["@float"]))end
 -- Decode in place: the JSON decoder already owns this fresh tree. Building
 -- another complete tree doubles transient memory for large history files.
 local renames
 for k,x in pairs(v)do
  local key=k
  if type(k)=="string"then if k:sub(1,3)=="@n:"then key=assert(tonumber(k:sub(4)))elseif k:sub(1,3)=="@s:"then key=k:sub(4)end end
  local value=unpack_value(x,step)
  if key~=k then renames=renames or {};renames[#renames+1]={old=k,key=key,value=value}else v[k]=value end
 end
 if renames then
  for _,e in ipairs(renames)do v[e.old]=nil end
  for _,e in ipairs(renames)do v[e.key]=e.value end
 end
 return v
end

function S.new(adapter,patch)
 return setmetatable({a=adapter,patch=patch,values={},pending=false,cache={},inheritances={},manifest={format=1,revision=0,entries={}},dirty={},history_refs=setmetatable({},{__mode="k"}),recovery_baselines=setmetatable({},{__mode="k"}),ready=false},S)
end
function S:encode(value)return self.a.json.encode(pack(value))end
-- In a save spread over frames, packing, encoding, copying and comparing pause every so many entries.
S.slice_entries=4000
-- and a big file is read, written and read back a part at a time, pausing between parts
function S:part_pause()
 local job=self.job;local co=coroutine.running();if job and job.save and co and job.cos[co]then return function()self:pause(true)end end
end
function S:bytes(path)
 local pause=self.a.read_parts and self:part_pause()
 local function get(p)if pause then return self.a.read_parts(p,pause)end;return self.a.read(p)end
 local source=self.backup_sources and self.backup_sources[path]
 return get(path)or source and get(source)or nil
end
function S:stepper()
 local job=self.job;local co=coroutine.running();if not(job and job.save and co and job.cos[co])then return nil end
 local n,limit=0,self.slice_entries;return function(k)n=n+k;if n>=limit then n=0;self:pause(true)end end
end
-- There a big value is packed, then encoded a part at a time. Small parts go to the encoder together, so it runs about
-- once a slice, and the JSON decodes to the same value as one call's would. tail lists fields already encoded as
-- "key":value, which join the object before its closing brace without the whole being copied again.
function S:encode_sliced(value,tail)
 local function join(out)
  if tail and tail[1]then local last=out[#out];assert(last:sub(-1)=="}","Unsupported saved value")
   out[#out]=last:sub(1,-2);if last~="{}"then out[#out+1]=","end
   for i,field in ipairs(tail)do if i>1 then out[#out+1]=","end;out[#out+1]=field end;out[#out+1]="}"
  end
  return table.concat(out)
 end
 local step=self:stepper();if not step then return join({self:encode(value)})end
 local json,limit,sizes,out=self.a.json,self.slice_entries,{},{}
 local root=pack(value,nil,step,sizes)
 local function put(t)
  local size=sizes[t]or 1
  if size<=limit then out[#out+1]=json.encode(t);step(size);return end
  local list,group,weight,first=t[1]~=nil,{},0,true
  local function comma()if first then first=false else out[#out+1]=","end end
  local function send()if weight>0 then comma();out[#out+1]=json.encode(group):sub(2,-2);step(weight);group,weight={},0 end end
  local function one(k,x)local w=sizes[x]or 1
   if w>limit then send();comma();if not list then out[#out+1]=json.encode(k)..":"end;put(x)
   else if list then group[#group+1]=x else group[k]=x end;weight=weight+w;if weight>=limit then send()end end
  end
  out[#out+1]=list and "["or "{"
  if list then for i=1,#t do one(i,t[i])end else for k,x in pairs(t)do one(k,x)end end
  send();out[#out+1]=list and "]"or "}"
 end
 put(root)
 return join(out)
end
function S:decode(bytes)return unpack_value(self.a.json.decode(bytes))end
-- An import reads a big match a step at a time: the read, the decode and the unpacking each end with a pause, and the
-- unpacking pauses as it goes. Only the decode runs under pcall, as a pause cannot leave one.
function S:read_sliced(path,pause)
 assert(type(path)=="string"and not path:find("..",1,true)and not path:match("^[/\\]")and not path:find(":",1,true),"Invalid data path")
 local bytes=self.a.read(path);if not bytes then return nil end
 pause()
 local ok,raw=pcall(self.a.json.decode,bytes);bytes=nil
 if not ok then error("Unreadable Information Overload file: "..path,0)end
 pause()
 local n=0
 return unpack_value(raw,function()n=n+1;if n%2000==0 then pause()end end)
end
-- Where each top-level field of a JSON object starts and ends, found by its brackets and quotes alone, so fields can be copied
-- out of a file without decoding it; nil when the bytes are not an object. pause is called every so many brackets.
local function json_fields(s,pause)
 local find,byte,n=string.find,string.byte,0
 local function quote_end(q)local p=q+1;while true do local e=find(s,'["\\]',p);if not e then return nil end;if byte(s,e)==34 then return e end;p=e+2 end end
 local function value_end(v)
  local c=byte(s,v);if c==34 then return quote_end(v)end
  if c~=123 and c~=91 then local e=find(s,"[,}%]%s]",v);return e and e>v and e-1 or nil end
  local depth,p=0,v
  while true do
   p=find(s,'[%[%]{}"]',p);if not p then return nil end
   c=byte(s,p)
   if c==34 then p=quote_end(p);if not p then return nil end
   elseif c==123 or c==91 then depth=depth+1
   else depth=depth-1;if depth==0 then return p end end
   p=p+1;n=n+1;if n>=2000 then n=0;pause()end
  end
 end
 local out,p={},find(s,"{",1,true)
 if not p or s:sub(1,p-1):find("[^%s\239\187\191]")then return nil end;p=p+1
 while true do
  p=find(s,"[^%s,]",p);if not p then return nil end
  local c=byte(s,p);if c==125 then return out end;if c~=34 then return nil end
  local e=quote_end(p);if not e then return nil end
  local _,colon=find(s,"^%s*:%s*",e+1);if not colon then return nil end
  local stop=value_end(colon+1);if not stop then return nil end
  out[s:sub(p+1,e-1)]={colon+1,stop};p=stop+1
 end
end
function S:read(path)
 assert(type(path)=="string"and not path:find("..",1,true)and not path:match("^[/\\]")and not path:find(":",1,true),"Invalid data path")
 local bytes=self.a.read(path)
 if not bytes and self.backup_sources and self.backup_sources[path]then bytes=self.a.read(self.backup_sources[path])end
 if not bytes then return nil end
 local ok,value=pcall(self.decode,self,bytes);if not ok then error("Unreadable Information Overload file: "..path)end
 return value
end
-- A file read straight after its write waits for the virus scan, so a save reads back what it wrote in one pass before
-- it commits. What is held to compare is checked early once it passes this many bytes.
S.verify_batch=4*1024*1024
function S:immutable(path,value,bytes,whole)
 bytes=bytes or whole and self:encode(value)or self:encode_sliced(value);self:pause(true);local existing=self.a.read(path)
 if existing then local ok,decoded=pcall(self.decode,self,existing);assert(existing==bytes or ok and equal(decoded,value),"Snapshot filename collision: "..path);return path end
 self:room(#bytes)
 self.written=self.written or {};self.written[path]=true
 local pause=self.a.write_parts and self:part_pause()
 local wrote;if pause then wrote=self.a.write_parts(path,bytes,pause)else wrote=self.a.write(path,bytes)end
 if not wrote then self.a.remove(path);error("Cannot write Information Overload file: "..path,0)end
 self:to_verify(path,bytes,pause and true)
 return path
end
-- a data file written in parts is read back in parts too; the catalog's tmp is read whole, so no file the commit renames is
-- left open by a save given up
function S:to_verify(path,bytes,parts)local list=self.unverified or {held=0};self.unverified=list;list[#list+1]={path,bytes,parts};list.held=list.held+#bytes end
-- the files held are checked before one that would take them past the batch is written, so none is read back the moment it is written
function S:room(size)local list=self.unverified;if list and list[1]and list.held+size>self.verify_batch then self:verify_pending()end end
-- the bytes read back are compared, not decoded and compared value by value, which cost as much again as the write for a big match
function S:verify_pending()
 local list=self.unverified or {};self.unverified=nil
 for _,e in ipairs(list)do self:pause(true)
  local pause=e[3]and self.a.same and self:part_pause();local same;if pause then same=self.a.same(e[1],e[2],pause)else same=self.a.read(e[1])==e[2]end
  if not same then self.a.remove(e[1]);error("Saved data verification failed: "..e[1],0)end;self:pause(true)
 end
end
function S:resolve(desc)
 if not desc then return nil end
 local token=desc.file.."\0"..(desc.transforms and self:encode(desc.transforms)or "")
 if self.cache[token]then return self.cache[token]end
 local value=assert(self:read(desc.file),"Missing saved data: "..desc.file)
 for _,carry in ipairs(desc.transforms or {})do
  self.patch.carry(value,carry.old,carry.new,carry.policy)
  value=S.only_patch(value,carry.new)
 end
 self.cache[token]=value;return value
end
function S.only_patch(data,patch)
 local result={}
 for name,value in pairs(data)do
  if name=="rows"then local rows={};for id,row in pairs(value)do if row.context.patch==patch then rows[id]=row end end;result.rows=rows
  elseif patch_maps[name]then if value[patch]~=nil then result[name]={[patch]=value[patch]}end
  else result[name]=value end
 end;return result
end
local function class_chunk(chunks,patch,class)
 local id="classes/"..safe(class);chunks[patch]=chunks[patch]or {};local group=chunks[patch]
 group[id]=group[id]or {};return group[id],id
end
function S.partition(data)
 local shared,chunks={},{}
 for name,value in pairs(data or {})do
  if name=="run_history"then
  elseif name=="rows"then
   shared.rows={}
   for id,row in pairs(value)do local chunk=class_chunk(chunks,row.context.patch or "unverified-patch",row.context.class or "unknown");chunk.rows=chunk.rows or {};chunk.rows[id]=row end
  elseif class_maps[name]then
   shared[name]={}
   for patch,modes in pairs(value)do shared[name][patch]={};for mode,classes in pairs(modes)do shared[name][patch][mode]={};for class,stats in pairs(classes)do
    local chunk=class_chunk(chunks,patch,class);chunk[name]=chunk[name]or {};chunk[name][patch]=chunk[name][patch]or {};chunk[name][patch][mode]=chunk[name][patch][mode]or {};chunk[name][patch][mode][class]=stats
   end end end
  elseif name=="blo_global"or name=="blo_weapons"then
   shared[name]={};for patch,stats in pairs(value)do local chunk=class_chunk(chunks,patch,"ogryn");chunk[name]={[patch]=stats}end
  elseif name=="maelstrom_streaks"then
   shared[name]={};for patch,stats in pairs(value)do chunks[patch]=chunks[patch]or {};chunks[patch]["streaks/overall"]=chunks[patch]["streaks/overall"]or {};chunks[patch]["streaks/overall"][name]={[patch]={overall=stats.overall,classes={}}}
    for class,scoped in pairs(stats.classes or {})do local chunk=class_chunk(chunks,patch,class);chunk[name]={[patch]={classes={[class]=scoped}}}end
   end
  elseif patch_maps[name]then
   shared[name]={};local category=name=="mode_streaks"and "streaks/overall"or "running_tallies/overall"
   for patch,stats in pairs(value)do chunks[patch]=chunks[patch]or {};chunks[patch][category]=chunks[patch][category]or {};chunks[patch][category][name]={[patch]=stats}end
  else shared[name]=value end
 end
 return shared,chunks
end
local function merge(target,value)
 for k,v in pairs(value)do if type(v)=="table"and type(target[k])=="table"then merge(target[k],v)else target[k]=clone(v)end end
end
-- Keep compact reconstruction sources resident; large viewing/test data stays file-backed.
local detail_fields={measurements=true,experimental=true,combat_timeline=true,party_records=true,damage=true,team_damage=true,performance=true,damage_diagnostics=true,compact_damage_test=true,talent_test=true}
function S:release_details()self.detail_file=nil;self.detail_value=nil end
function S:history_detail(desc)
 if self.detail_file~=desc.file then self.detail_value=assert(self:read(desc.file),"Missing match file");self.detail_file=desc.file end
 return self.detail_value
end
-- The End Screen's moment can live in the match's catalog entry rather than its file, so marking it writes no match, and no save compares it.
local function without_end_screen(marks)
 if type(marks)~="table"or marks.end_screen==nil then return marks end
 local t={};for k,v in pairs(marks)do if k~="end_screen"then t[k]=v end end;return next(t)and t or nil
end
-- what a later save compares a match with: copies of its resident fields, not the exclusion flag, which the launch sets from the policy
local function snapshot_of(full,step)
 local t={};for k,v in pairs(full)do if k=="completion_markers"then t[k]=clone(without_end_screen(v),step)elseif not detail_fields[k]and k~="stats_excluded"then t[k]=clone(v,step)end end;return t
end
-- the damage figures pages read without a match's details, from the match or from a table of its damage, team damage and context
local function damage_info(full)
 local total=full.damage and full.damage.total
 local damage_total=total and total.all and math.max(0,(total.all.total or 0)-(total.void_shield and total.void_shield.total or 0))or 0
 local reported=total and total.all and total.all.total;local team_total
 if S.run_damage_info then damage_total,team_total,reported=S.run_damage_info(full)end
 local useful,team_useful;if S.run_useful then useful,team_useful=S.run_useful(full)end
 return {io_damage_total=damage_total,io_damage_reported=reported,io_team_damage_total=team_total,io_damage_useful=useful or false,io_team_damage_useful=team_useful or false}
end
function S:history_load(desc,full,taken)
 full=full or assert(self:read(desc.file),"Missing match file");local summary,fields={},{}
 local marks=full.completion_markers;local in_file=type(marks)=="table"and marks.end_screen or nil
 if desc.end_screen~=nil and in_file==nil then if type(marks)~="table"then marks={};full.completion_markers=marks end;marks.end_screen=desc.end_screen end
 for k,v in pairs(full)do if detail_fields[k]then fields[k]=true else summary[k]=v end end
 -- a match written again from its file holds only its resident fields here, and the details copied across are named
 local known=taken and taken.known;if known then for k in pairs(known.fields)do fields[k]=true end end
 local store=self
 -- details are read by the name the reference holds, so a backup move that renames the file renames it there alone
 local ref={desc=clone(desc),end_screen=in_file,fields=fields};if taken then ref.end_screen=taken.end_screen end
 local mt=damage_info(known and taken.probe or full)
 mt.__index=function(_,key)if fields[key]then return store:history_detail(ref.desc)[key]end end
 mt.io_materialize=function(row)
  local result={};for k,v in pairs(row)do result[k]=v end
  if next(fields)then local details=store:history_detail(ref.desc);for k in pairs(fields)do if rawget(row,k)==nil then result[k]=details[k]end end end
  return result
 end
 setmetatable(summary,mt)
 -- Snapshot only the small resident source, never a second complete match.
 ref.summary=taken and taken.summary or snapshot_of(summary);self.history_refs[summary]=ref
 return summary
end
function S:compact_history(view,dirty,late)
 view,dirty=view or self.values,dirty or self.dirty
 local moved={};for _,move in ipairs(self.manifest.backup_moves or {})do moved[move.from]=move.to end
 for key,entry in pairs(self.manifest.entries)do if datasets[key]and dirty[key]then
  local data=view[key];local history=data and data.run_history
  if history then for i,desc in ipairs(entry.history or {})do local run=history[i]
   -- a match still listed under the file it was read from was found unchanged when the catalog was built
   local ref=run and self.history_refs[run]
   -- and one a backup move takes is the same match under a new name, so it is not read again
   if ref and ref.desc.file~=desc.file and moved[ref.desc.file]==desc.file then ref.desc=clone(desc)
   elseif run and late and late[key]then
    -- its records changed while a save spread over frames ran, so what it wrote may be older: a match it wrote stays whole
    -- in memory, tied to no file, and the next save writes it again
    local taken=self.snapshots and self.snapshots[run]
    if ref and ref.desc.file~=desc.file and taken and taken.known then
     -- one written again from its file keeps what it holds in memory and reads the rest from the file just written, which has
     -- every detail it had, and is compared later with the snapshot taken before that file was packed
     ref.desc=clone(desc);ref.summary=taken.summary;ref.end_screen=taken.end_screen;for k in pairs(taken.known.fields)do ref.fields[k]=true end
     local mt=getmetatable(run);for k,v in pairs(damage_info(taken.probe))do mt[k]=v end
    elseif ref and ref.desc.file~=desc.file then local mt=getmetatable(run);local full=mt and mt.io_materialize and mt.io_materialize(run)or run;for k,v in pairs(full)do run[k]=v end;setmetatable(run,nil);self.history_refs[run]=nil end
   elseif run and not (ref and ref.desc.file==desc.file)then
    -- made from the match in hand, not decoded again from the file just written and checked, and compared later with the
    -- snapshot taken before its file was packed; one written again from its file has its details named by the snapshot
    local taken=self.snapshots and self.snapshots[run]
    local mt=getmetatable(run);local full,src=not(taken and taken.known)and mt and mt.io_materialize and mt.io_materialize(run)or run,{};for k,v in pairs(full)do src[k]=v end
    local loaded=self:history_load(desc,src,taken)
    -- Preserve row identity, including recovery snapshots sharing completed rows.
    for k in pairs(run)do run[k]=nil end;for k,v in pairs(loaded)do run[k]=v end
    setmetatable(run,getmetatable(loaded));self.history_refs[run]=self.history_refs[loaded]
   end
  end end
 end end
 self:release_details()
end
function S:history_descriptor(run)
 local ref=self.history_refs[run];if not ref then return nil end
 if ref.desc.file:sub(1,22)=="reconstruction_import/"then return nil end
 for field in pairs(detail_fields)do if rawget(run,field)~=nil then return nil end end
 local resident={};for k,v in pairs(run)do if k=="completion_markers"then resident[k]=without_end_screen(v)elseif k~="stats_excluded"then resident[k]=v end end
 if equal(resident,ref.summary,self:stepper())then return clone(ref.desc)end
end
-- A missing or unreadable file is left out and listed in the catalog's missing list, which keeps
-- it off the cleanup pass. Its entry or records chunk stays in the catalog until the mod writes
-- over it, and match files are retried every launch, so a briefly locked file comes back.
-- What the launch could not read stays in skipped until the next launch, as only a launch reads it again.
function S:skip(key,desc,reason,match)
 local r=desc and clone(desc)or {};r.key=key;r.reason=tostring(reason);r.match=match
 self.skipped=self.skipped or {};self.skipped[#self.skipped+1]=r
end
function S:dataset_load(entry,key)
 local kind,lost=datasets[key],false;local rebuild=kind=="general"and entry.history_present
 local function part(desc,patch,category)
  if not kind then return self:resolve(desc)end
  local ok,v=pcall(self.resolve,self,desc)
  if ok and type(v)=="table"and (patch or v.schema==1 and type(v.rows)=="table")then return v end
  self:skip(key,desc,ok and "Damaged saved records"or v);lost=true
  if patch and not rebuild then local h=self.held_chunks or {};self.held_chunks=h;h[kind]=h[kind]or {};h[kind][patch]=h[kind][patch]or {};h[kind][patch][category]=desc end
 end
 local data=clone(kind and (part(entry.shared)or {schema=1,rows={}})or assert(part(entry.shared),"Missing shared records"))
 for patch,chunks in pairs(entry.patches or {})do for category,desc in pairs(chunks)do local v=part(desc,patch,category);if v then merge(data,v)end end end
 if lost and rebuild then data.history_cache_rebuild_required=true end
 local missing=kind and self.prior_missing or {}
 if entry.history_present then data.run_history={};local listed,ids={},{}
  for _,desc in ipairs(entry.history or {})do listed[desc.file]=true
   local read,full=pcall(self.read,self,desc.file)
   if read and type(full)=="table"then data.run_history[#data.run_history+1]=self:history_load(desc,full);ids[tostring(desc.id)]=true else self:skip(key,desc,read and "Missing match file"or full,kind and true)end
  end
  -- Same id within the run sequence: a reset or import since then must not bring it back.
  local seq=tonumber(data.run_sequence)
  for _,r in ipairs(missing)do local id=tonumber(r.id)
   if r.key==key and r.match and not listed[r.file]and not ids[tostring(r.id)]and (not seq or id and id<=seq)then
    local read,full=pcall(self.read,self,r.file)
    if read and type(full)=="table"then
     local desc=clone(r);desc.key,desc.reason,desc.match=nil,nil,nil
     local at=#data.run_history+1;if id then for i,run in ipairs(data.run_history)do if (tonumber(run.id)or 0)>id then at=i;break end end end
     table.insert(data.run_history,at,self:history_load(desc,full));listed[r.file]=true;ids[tostring(r.id)]=true
     data.history_cache_rebuild_required=true;self.restored=self.restored or {};self.restored[key]=true
    end
   end
  end
 end
 if entry.cache_pending then data.history_cache_rebuild_required=true end
 if data.history_cache_rebuild_required then
  local seq=tonumber(data.run_sequence)or 0;for _,run in ipairs(data.run_history or {})do seq=math.max(seq,tonumber(run.id)or 0)end
  for _,list in ipairs({missing,self.skipped or {}})do for _,r in ipairs(list)do if r.key==key and r.match then seq=math.max(seq,tonumber(r.id)or 0)end end end
  data.run_sequence=seq
 end
 validate_dataset(data);return data
end
local recovery_keys={unfinished_run_v1=true,solo_unfinished_v1=true}
function S:entry_load(key,entry)
 -- friend summaries saved before they shared one file are read from a file each, and the next save writes them as one
 if key=="friend_summaries_v1"and entry.friends then local out={};for id,desc in pairs(entry.friends)do local ok,v=pcall(self.resolve,self,desc);if ok and v~=nil then out[id]=clone(v)else self:skip(key,desc,v)end end;self.dirty[key]=true;self.pending=true;return out end
 if datasets[key]then return self:dataset_load(entry,key)end
 local value=clone(self:resolve(entry))
 if entry.before then value.data_before=self:dataset_load(entry.before,key)end
 return value
end
local function referenced(entry,paths)
 if type(entry)~="table"then return end
 if type(entry.file)=="string"then paths[entry.file]=true end
 for _,child in pairs(entry)do if type(child)=="table"then referenced(child,paths)end end
end
-- Records datasets still fail closed on a damaged shape: holding one back would let a fresh
-- value replace the entry and the cleanup pass delete its files.
function S:load_manifest(manifest)
 assert(type(manifest)=="table"and manifest.format==1 and type(manifest.entries)=="table","Invalid storage catalog")
 self.prior_missing=manifest.missing
 local values={};for key,entry in pairs(manifest.entries)do
  if datasets[key]then values[key]=self:entry_load(key,entry)else
   local ok,value=pcall(self.entry_load,self,key,entry)
   if ok then values[key]=value else
    local files={};referenced(entry,files);for path in pairs(files)do local read,v=pcall(self.read,self,path);if not read or v==nil then self:skip(key,{file=path},value)end end
    if not recovery_keys[key]then self.held=self.held or {};self.held[key]=true end
   end
  end
 end;self.prior_missing=nil;return values
end
-- Combat checkpoints have their own small atomic journal. Completed history
-- and the derived-data catalog are not rewritten by this path.
-- Timeline events are append-only: each checkpoint writes only the events added
-- since the last commit, and the envelope lists the chunks to reassemble.
-- Chunks are numbered 1..n with no gaps, so a later session finds the ones no
-- envelope names by reading on past the highest number an envelope records.
local timeline_lists={"events","streak_events"}
local function timeline_file(path)return type(path)=="string"and path:match("^recovery/timeline%-[%w_.%-]+%.json$")~=nil end
local function timeline_path(n)return "recovery/timeline-"..tostring(n)..".json"end
-- Observation groups change in place, so they ride along as a log under "obs": copies of the
-- groups marked since the last checkpoint, applied in order so the latest copy of each wins.
-- Peril samples are append-only like events; desc.peril says where each "p" list lives.
local function peril_list(ex,at)
 local pt=type(ex)=="table"and ex.peril_timeline;local row=type(pt)=="table"and type(pt.members)=="table"and pt.members[at.member]
 local seg=type(row)=="table"and type(row.segments)=="table"and row.segments[at.segment];return type(seg)=="table"and seg.samples
end
function S:timeline_load(desc,ex)
 local tl=clone(desc.data);local n_obs,groups,applied,peril=desc.observations,{},0,desc.peril or {}
 for _,chunk in ipairs(desc.chunks or {})do
  assert(timeline_file(chunk.file),"Invalid recovery timeline")
  local parts=assert(self:read(chunk.file),"Missing recovery timeline: "..chunk.file)
  for key,count in pairs(chunk.counts)do
   local part=parts[key]
   if key=="obs"then
    assert(n_obs and type(part)=="table"and part.from==applied+1 and type(part.items)=="table"and #part.items>=count,"Damaged recovery timeline: "..chunk.file)
    for n=1,count do local e=part.items[n];assert(type(e)=="table"and type(e.group)=="table"and type(e.i)=="number"and e.i>=1 and e.i<=n_obs,"Damaged recovery timeline: "..chunk.file);groups[e.i]=e.group end
    applied=applied+count
   else
    local list
    if peril[key]then list=peril_list(ex,peril[key])else local i,field=tostring(key):match("^(%d+):(.+)$");local s=tl.segments[tonumber(i)];list=s and s[field]end
    assert(type(list)=="table"and type(part)=="table"and part.from==#list+1 and type(part.items)=="table"and #part.items>=count,"Damaged recovery timeline: "..chunk.file)
    for n=1,count do list[#list+1]=part.items[n]end
   end
  end
 end
 if not n_obs then return tl end
 local obs={};for i=1,n_obs do obs[i]=assert(groups[i],"Missing recovery observation")end
 return tl,obs
end
local function experimental_rest(self,ex,live,peril)
 local rest={};for k,v in pairs(ex)do if k~="observations"then rest[k]=v end end
 local pt=ex.peril_timeline;if type(pt)~="table"or type(pt.members)~="table"then return rest end
 local p={};for k,v in pairs(pt)do p[k]=v end;p.members={};rest.peril_timeline=p
 local keys=self.peril_keys or setmetatable({},{__mode="k"});self.peril_keys=keys
 for id,row in pairs(pt.members)do local r=row
  if type(row)=="table"and type(row.segments)=="table"then r={};for k,v in pairs(row)do r[k]=v end;r.segments={}
   for j,seg in pairs(row.segments)do local c=seg
    if type(seg)=="table"and type(seg.samples)=="table"then
     local key=keys[seg.samples];if not key then self.peril_next=(self.peril_next or 0)+1;key="p"..self.peril_next;keys[seg.samples]=key end
     c={};for k,v in pairs(seg)do c[k]=v end;c.samples={};live[key]=seg.samples;peril[key]={member=id,segment=j}
    end
    r.segments[j]=c
   end
  end
  p.members[id]=r
 end
 return rest
end
-- A retry after a failed commit rewrites the same chunk with a superset, so an
-- envelope that did land still reads its prefix. Anything else takes a new number.
function S:timeline_journal(tl,ex)
 local data,live,peril,rest,obs={},{},{}
 for k,v in pairs(tl)do data[k]=v end;data.segments={}
 for i,s in ipairs(tl.segments)do
  local copy={};for k,v in pairs(s)do copy[k]=v end;data.segments[i]=copy
  for _,field in ipairs(timeline_lists)do if type(s[field])=="table"then live[i..":"..field]=s[field];copy[field]={}end end
 end
 if ex then rest=experimental_rest(self,ex,live,peril);obs=type(ex.observations)=="table"and ex.observations or nil end
 local old=self.timeline_state;local lists,chunks={},{}
 if old then lists,chunks=old.lists,old.chunks
  for key,e in pairs(lists)do if key=="obs"and e.ref~=obs or key~="obs"and(live[key]~=e.ref or #e.ref<e.count)then lists,chunks={},{};break end end
 end
 local parts,counts,state,write={},{},{}
 for key,list in pairs(live)do
  local from=(lists[key]and lists[key].count or 0)+1
  state[key]={ref=list,count=#list,from=from}
  if #list>=from then local items={};for n=from,#list do items[#items+1]=list[n]end;parts[key]={from=from,items=items};counts[key]=#items end
 end
 -- Copies wait in pending until an envelope lands, so a retry rewrites them unchanged.
 if obs then
  local base=lists.obs and lists.obs.count or 0;local log=self.obs_log
  if not log or log.ref~=obs or base~=log.base and base~=log.base+#log.pending then log={ref=obs,base=base,pending={},refs={}}
  elseif base~=log.base then log.base,log.pending=base,{}end
  self.obs_log=log
  -- A table with no marks (a finished or reloaded run) compares each group with its last copy instead.
  local mt=getmetatable(obs);local touched=mt and mt.io_touched;log.copies=not touched and(log.copies or {})or nil
  for i=1,#obs do local group=obs[i]
   if log.refs[i]~=group or(touched and touched[group]or not touched and not equal(log.copies[i],group))then
    local c=clone(group);log.pending[#log.pending+1]={i=i,group=c};log.refs[i]=group;if touched then touched[group]=nil else log.copies[i]=c end
   end
  end
  state.obs={ref=obs,count=base+#log.pending,from=base+1}
  if log.pending[1]then parts.obs={from=base+1,items=log.pending};counts.obs=#log.pending end
 end
 local retry=self.timeline_retry
 if retry then for key,e in pairs(retry.lists)do local now=state[key];if not now or now.ref~=e.ref or now.from~=e.from or now.count<e.count then retry=nil;break end end end
 self.timeline_retry=retry
 local last=self.timeline_last or 0
 -- The returned function writes the chunk after the envelope is encoded:
 -- logged items never change, so they can be encoded a few a frame.
 if next(parts)then
  local n=retry and retry.n or (self.timeline_last or 0)+1
  local path=timeline_path(n);last=math.max(last,n)
  local all={};for i,c in ipairs(chunks)do all[i]=c end;all[#all+1]={file=path,counts=counts};chunks=all
  write=function()
   local bytes=self:encode_parts(parts)
   self.timeline_files=self.timeline_files or {};self.timeline_files[path]=true;self.journal_written=true
   assert(self.a.write(path,bytes),"Cannot write recovery timeline: "..path)
   self.timeline_last=math.max(self.timeline_last or 0,n);self.timeline_retry={n=n,lists=state}
  end
 end
 return {data=data,chunks=chunks,last=last,observations=obs and #obs or nil,peril=next(peril)and peril or nil},{lists=state,chunks=chunks},rest,write
end
function S:encode_parts(parts)
 local out={}
 for key,part in pairs(parts)do
  local items={};for i,item in ipairs(part.items)do items[i]=self:encode(item);self:pause()end
  out[#out+1]=self.a.json.encode(key)..':{"from":'..self:encode(part.from)..',"items":['..table.concat(items,",").."]}"
 end
 return "{"..table.concat(out,",").."}"
end
-- Chunks go highest number first and before the envelopes, so a cleanup cut
-- short still leaves 1..k for the next session to find. The journal is let go
-- at once and its files listed for removing.
local function drop_journal(self)
 local paths={};for path in pairs(self.timeline_files or {})do paths[#paths+1]=path end
 table.sort(paths,function(a,b)return (tonumber(a:match("(%d+)%.json$"))or 0)>(tonumber(b:match("(%d+)%.json$"))or 0)end)
 for _,path in ipairs({"recovery/checkpoint.json","recovery/checkpoint.json.bak","recovery/checkpoint-0.json","recovery/checkpoint-1.json"})do paths[#paths+1]=path end
 self.timeline_files={};self.timeline_state=nil;self.timeline_retry=nil;self.timeline_last=0;self.journal_written=nil;self.checkpoint_serial=nil;self.obs_log=nil
 return paths
end
function S:clear_journal()for _,path in ipairs(drop_journal(self))do self.a.remove(path)end end
function S:open_checkpoint()
 local candidates,last={},0
 local files=self.timeline_files or {};self.timeline_files=files
 for _,path in ipairs({"recovery/checkpoint-0.json","recovery/checkpoint-1.json","recovery/checkpoint.json","recovery/checkpoint.json.bak"})do
  local ok,envelope=pcall(self.read,self,path)
  if ok and type(envelope)=="table"then
   local tl=type(envelope.timeline)=="table"and envelope.timeline
   for _,chunk in ipairs(tl and type(tl.chunks)=="table"and tl.chunks or {})do if type(chunk)=="table"and timeline_file(chunk.file)then files[chunk.file]=true end end
   last=math.max(last,tl and tonumber(tl.last)or 0)
  end
  if ok and envelope and envelope.format==1 and tostring(envelope.base_revision)==tostring(self.manifest.revision)and envelope.snapshot then candidates[#candidates+1]=envelope end
 end
 while self.a.read(timeline_path(last+1))do last=last+1 end
 for i=1,last do files[timeline_path(i)]=true end;self.timeline_last=last
 table.sort(candidates,function(a,b)return (a.serial or 0)>(b.serial or 0)end)
 for _,envelope in ipairs(candidates)do
  local loaded,value=pcall(function()
   local snapshot=clone(envelope.snapshot)
   if envelope.timeline~=nil then local obs;snapshot.combat_timeline,obs=self:timeline_load(envelope.timeline,snapshot.measurements or snapshot.experimental)
    if obs then assert(type(snapshot.experimental)=="table","Damaged recovery observations");snapshot.experimental.observations=obs end
   end
   snapshot.data_before=self:dataset_load(envelope.before);return snapshot
  end)
  if loaded then
   self.values.unfinished_run_v1=value
   if envelope.cache_revision then self.values.cache_revision_v1=clone(envelope.cache_revision)end
   self.checkpoint_serial=envelope.serial or 0;self.dirty.unfinished_run_v1=true;self.pending=true;self.journal_active=true
   self.cache={};self:release_details();return true
  end
 end
 return false
end
-- Only the baseline descriptor is cached, never mutable mission progress.
-- Reuse its encoded form until the baseline or catalog revision changes.
function S:recovery_encode(snapshot,before,serial,timeline)
 if self.encoded_before_ref~=before or self.encoded_before_revision~=self.manifest.revision then
  self.encoded_before_bytes=self:encode(before)
  self.encoded_before_ref=before;self.encoded_before_revision=self.manifest.revision
 end
 return '{"format":1,"serial":'..self:encode(serial)..',"base_revision":'..self:encode(self.manifest.revision)..',"snapshot":'..self:encode(snapshot)..',"before":'..self.encoded_before_bytes..(timeline and ',"timeline":'..self:encode(timeline)or '')..(self.values.cache_revision_v1 and ',"cache_revision":'..self:encode(self.values.cache_revision_v1)or '')..'}'
end
function S:journal_ready()
 local m=self.values.unfinished_run_v1;return m and m.data_before and self.manifest.entries.lifetime_records_v1 and true or false
end
-- Everything the envelope says is encoded in one frame; the baseline before it
-- and the chunk and file writes after it may spread over frames in a job.
function S:recovery_baseline(m)
 local before=self.recovery_baselines[m.data_before]
 if not before then
  for attempt=1,32 do
   self.generation=math.max(self.generation or 0,tonumber(self.manifest.revision)or 0)+1
   local built,value=self:try(self.dataset_build,self,m.data_before,"recovery-before",self.manifest.entries.lifetime_records_v1,string.format("%010d",self.generation))
   if built then before=value;break end
   self.unverified=nil
   if not tostring(value):find("Snapshot filename collision",1,true)then error(value)end
  end
  -- cached only once its files read back, or every later checkpoint would name one that is not there
  assert(before,"Cannot reserve recovery baseline");self:verify_pending();self.recovery_baselines[m.data_before]=before
 end
 return before
end
function S:checkpoint_journal()
 if not self:journal_ready()then return nil end
 local m=self.values.unfinished_run_v1
 local ok,err=self:try(function()
  local before=self:recovery_baseline(m)
  local snapshot={};for k,v in pairs(m)do if k~="data_before"then snapshot[k]=v end end
  local serial=(self.checkpoint_serial or 0)+1
  local timeline,timeline_state,write
  if type(m.combat_timeline)=="table"and type(m.combat_timeline.segments)=="table"then
   local rest;timeline,timeline_state,rest,write=self:timeline_journal(m.combat_timeline,type(m.measurements)=="table"and m.measurements or type(m.experimental)=="table"and m.experimental or nil)
   snapshot.combat_timeline=nil;if rest then if m.measurements then snapshot.measurements=rest else snapshot.experimental=rest end end
  end
  local bytes=self:recovery_encode(snapshot,before,serial,timeline)
  self:pause();if write then write();self:pause()end
  if self.a.journal_atomic then assert(self.a.journal_atomic("recovery/checkpoint-"..tostring(serial%2)..".json",bytes),"Cannot commit recovery checkpoint")
  else assert(self.a.atomic("recovery/checkpoint.json",bytes),"Cannot commit recovery checkpoint")end
  self.checkpoint_serial=serial;self.journal_active=true;self.timeline_state=timeline_state;self.timeline_retry=nil
 end)
 if not ok then self.unverified=nil;self.error=tostring(err);return false,self.error end
 self.error=nil;return true
end
-- The committed catalog is the transfer journal. A rename removes its source,
-- so startup can retry the same plan without recording individual moves.
-- The commit renamed the catalog before it to index.json.bak; that names files these moves take, so it is replaced first.
local function transfer(self,manifest)
 local pending,obsolete={},{}
 for _,move in ipairs(manifest.backup_moves or {})do if self.a.exists(move.from)then pending[#pending+1]=move end end
 for _,path in ipairs(manifest.backup_obsolete or {})do if self.a.exists(path)then obsolete[#obsolete+1]=path end end
 if not(pending[1]or obsolete[1])then return true end
 local bytes=self:encode(manifest)
 if self.a.read("index.json.bak")~=bytes and not(self.a.write("index.json.bak",bytes)and self.a.read("index.json.bak")==bytes)then return false end
 local done=true
 for _,move in ipairs(pending)do if not self.a.move(move.from,move.to)then done=false end end
 for _,path in ipairs(obsolete)do if not self.a.remove(path)then done=false end end
 return done
end
-- A move that fails, as for a file another program holds open, is tried again after the next save and at each launch,
-- and each catalog carries it until then. Its file is read from where it is, so saving and loading go on.
function S:finish_backup_moves(manifest)
 if not self.a.move then return true end
 local ok,done=pcall(transfer,self,manifest)
 if ok and done then
  self.backup_transfer_pending=nil;self.backup_sources=nil
  if manifest.backup_folders and self.a.remove_empty_folders then pcall(self.a.remove_empty_folders,manifest.backup_folders)end
  return true
 end
 self.backup_transfer_pending=true;self.backup_sources={}
 for _,move in ipairs(manifest.backup_moves or {})do self.backup_sources[move.to]=move.from end
 if self.tell and not self.transfer_told then self.transfer_told=true
  self.tell("Some saved files could not be moved into or out of their backup folder yet, as another program may have them open.\nThey are read from where they are, nothing was lost, and saving works.\nThe move is tried again after the next save and at the next launch.")
 end
 return false
end
function S:open()
 local bytes=self.a.read("index.json");local backup=self.a.read("index.json.bak")
 if not bytes and not backup then self.ready=true;return false end
 local ok,manifest,values
 for index,candidate in ipairs({bytes or false,backup or false})do if candidate then
  self.skipped,self.held,self.held_chunks,self.restored,self.unreported=nil,nil,nil,nil,nil;ok,manifest=pcall(self.decode,self,candidate)
  if ok then self:finish_backup_moves(manifest);self.cache={};ok,values=pcall(self.load_manifest,self,manifest)end
  if ok then self.manifest=manifest;self.values=values;self.cache={};self:release_details();self.ready=true
   local known={};for _,r in ipairs(manifest.missing or {})do known[r.file or r.reason]=true end
   for _,r in ipairs(self.skipped or {})do self.pending=true;if not known[r.file or r.reason]then self.unreported=self.unreported or {};self.unreported[r.file or r.reason]=true end end
   for key in pairs(self.restored or {})do self.dirty[key]=true;self.pending=true end
   self:open_checkpoint();if index==2 then self.recovered=true;self.pending=true else self.index_verified=true end;return true end
 end end
 error("Information Overload catalog could not be verified; existing files and settings were retained")
end
function S:get(key)return self.values[key]end
-- A reset drops what was held back for these keys, so an unreadable file of the old data never comes back into the new.
function S:forget(keys)
 self:settle();local gone={};for _,key in ipairs(keys)do gone[key]=true;if self.held then self.held[key]=nil end;if self.held_chunks and datasets[key]then self.held_chunks[datasets[key]]=nil end end
 local function keep(list)local out={};for _,r in ipairs(list or {})do if not gone[r.key]then out[#out+1]=r end end;return out[1]and out or nil end
 self.skipped=keep(self.skipped);self.manifest.missing=keep(self.manifest.missing);self.pending=true
end
-- Backups live in the catalog, newest last, so a reset or restore lands in the same atomic commit as the values it replaces.
function S:backups()return self.manifest.backups or {}end
-- What the catalog holds for these keys becomes a backup (none when info is nil); its missing match files go with it, so they come back only on a restore.
function S:stash(keys,info)
 self:settle();local b=clone(info or {});b.entries={};local gone={}
 for _,key in ipairs(keys)do gone[key]=true;if datasets[key]then assert(not self.dirty[key],"Save before a reset");b.entries[key]=clone(self.manifest.entries[key])end end
 for _,r in ipairs(self.manifest.missing or {})do if gone[r.key]and r.match then b.missing=b.missing or {};b.missing[#b.missing+1]=clone(r)end end
 local list=clone(self:backups());if info then list[#list+1]=b end
 self.undo={missing=self.manifest.missing,skipped=self.skipped,held=self.held and clone(self.held),held_chunks=self.held_chunks and clone(self.held_chunks)}
 self:forget(keys);self.staged_backups=list
end
function S:stage(list,missing)self:settle();self.staged_backups=list;self.staged_missing=missing;self.pending=true end
function S:unstage()
 local u=self.undo;if u then self.manifest.missing,self.skipped,self.held,self.held_chunks=u.missing,u.skipped,u.held,u.held_chunks end
 self.undo,self.staged_backups,self.staged_missing=nil,nil,nil
end
-- Loads like the launch does, without touching what the launch held back.
function S:backup_load(b)
 local skipped,held,prior,restored=self.skipped,self.held_chunks,self.prior_missing,self.restored
 self.skipped,self.held_chunks,self.prior_missing,self.restored=nil,nil,b.missing or {},nil
 local ok,values=pcall(function()local out={};for key,entry in pairs(b.entries or {})do if datasets[key]then out[key]=self:dataset_load(entry,key)end end;return out end)
 local lost=self.skipped or {};self.skipped,self.held_chunks,self.prior_missing,self.restored=skipped,held,prior,restored
 if not ok then error(values,0)end;return values,lost
end
-- The previous catalog's files are kept one commit longer, so a second commit with nothing new removes the backups' files at once.
function S:delete_backups()
 self:stage({});local ok,err=self:flush();if not ok then self:unstage();return false,err end
 self.prune=true;self.pending=true;self:flush();return true
end
local function loaded_path(store,path)
 return store.a.move and "Loaded Data/"..path or path
end
-- for a change only a full save need carry: a history save leaves it be rather than compare every match for it
local function late(self,key)local job=self.job;if job and job.save then job.save.late[key]=true end end
function S:touch(key)self.dirty[key]=true;self.pending=true;late(self,key)end
function S:set(key,value)self.values[key]=value;self.dirty[key]=true;self.pending=true;if key=="lifetime_records_v1"then self.history_clean=nil end;late(self,key)end
-- The folders a match's save and its mission checkpoints write into, by its patch and class, made in the background as the match starts.
local function class_folder(id)
 local labels={adamant="Arbitrator",broker="Hive Scum",cryptic="Skitarius",veteran="Veteran",zealot="Zealot",psyker="Psyker",ogryn="Ogryn"}
 return labels[id]or safe(id)
end
function S:prepare_run(context,key)
 if not self.a.prepare or type(context)~="table"or not context.patch then return end
 local kind=datasets[key]or "general";local patch=safe(context.patch)
 local paths={"index.json","recovery/","shared/",patch.."/"..(kind=="general"and "match_history/"or kind=="solo"and "solo/match_history/"or "psykhanium/logs/")}
 if kind~="psykhanium"then local base=patch.."/"..(kind=="general"and ""or kind.."/")
  for _,category in ipairs({"classes/"..(self.a.move and class_folder(context.class or "unknown")or safe(context.class or "unknown")),"streaks/overall","running_tallies/overall"})do paths[#paths+1]=base..category.."/";if kind=="general"then paths[#paths+1]=patch.."/recovery-before/"..category.."/"end end
 end
 for i,path in ipairs(paths)do if path~="recovery/"and path~="index.json"then paths[i]=loaded_path(self,path)end end
 pcall(self.a.prepare,paths)
end
-- A reset, restore or import can write into folders not made yet, so they are made by one mkdir in the background before
-- it writes, rather than one at a time as each file is written.
function S:prepare_folders()
 if not self.a.prepare then return end
 local paths,seen={},{}
 local function add(path)path=loaded_path(self,path);if not seen[path]then seen[path]=true;paths[#paths+1]=path end end
 add("shared/")
 for key,kind in pairs(datasets)do local data=self.dirty[key]and self.values[key]
  if type(data)=="table"then
   local _,chunks=S.partition(data)
   for patch,groups in pairs(chunks)do local prefix=safe(patch).."/"..(kind=="general"and ""or kind.."/")
    for category in pairs(groups)do add(prefix..(self.a.move and category:gsub("^classes/(.+)$",function(id)return "classes/"..class_folder(id)end)or category).."/")end
   end
   for _,run in ipairs(data.run_history or {})do add(safe(run.context and run.context.patch).."/"..(kind=="general"and "match_history/"or kind=="solo"and "solo/match_history/"or "psykhanium/logs/"))end
  end
 end
 pcall(self.a.prepare,paths,true)
end
-- A match added in place, without a set, still counts as new.
local function history_mark(v)local h=v and v.run_history;return h and #h..":"..tostring(v.run_sequence)or nil end
function S:inherit(old,new,policy)
 self:settle();self.inheritances[new]={old=old,new=new,policy=clone(policy)};for key in pairs(datasets)do self.dirty[key]=true end;self.pending=true
end
-- Spread over frames, an old file past this size is compared byte for byte with the new one instead of decoded in one frame,
-- and one that differs only in key order is written again.
S.compare_whole=64*1024
function S:descriptor(path,value,previous,whole)
 -- an older save's entry with no file of its own, as the per-friend summaries were, is written again rather than compared
 if previous and (previous.file or previous.transforms)then
  local step,ok,old=not whole and self:stepper()or nil
  if step and not previous.transforms then
   local bytes=self:bytes(previous.file);self:pause(true)
   if bytes and #bytes>self.compare_whole then
    local new=self:encode_sliced(value);if new==bytes then return clone(previous)end
    self:immutable(path,value,new);return {file=path}
   end
   if bytes then ok,old=pcall(self.decode,self,bytes)end
  -- read past the cache, which would hold every old match an Import compares until the save ends
  elseif previous.transforms then ok,old=pcall(self.resolve,self,previous)else ok,old=pcall(self.read,self,previous.file)end
  self:pause(true);if ok and equal(old,value,step)then return clone(previous)end;self:pause(true)
 end
 self:immutable(path,value,nil,whole);return {file=path}
end
function S:dataset_build(data,kind,old,revision)
 local shared,chunks=S.partition(data);local entry={kind=kind,patches={},history={},history_present=data.run_history~=nil};local step=self:stepper()
 entry.shared=self:descriptor(loaded_path(self,"shared/"..kind.."-"..revision..".json"),shared,old and old.shared);self:pause(true)
 for patch,groups in pairs(chunks)do entry.patches[patch]={};for category,value in pairs(groups)do
  local prior=old and old.patches and old.patches[patch]and old.patches[patch][category]
  local prefix=safe(patch).."/"..(kind=="general"and ""or kind.."/")
  local folder=self.a.move and category:gsub("^classes/(.+)$",function(id)return "classes/"..class_folder(id)end)or category
  local path=loaded_path(self,prefix..folder.."/records-"..revision..".json")
  local desc
  -- spread over frames, a big one is compared by its bytes, never decoded in one frame, and written again when they differ
  if prior and step and not prior.transforms then desc=self:descriptor(path,value,prior)
  elseif prior then local ok,previous=pcall(self.resolve,self,prior);self:pause(true);if ok and equal(previous,value,step)then desc=clone(prior)end end
  local inherit=self.inheritances[patch]
  if not desc and inherit and old and old.patches and old.patches[inherit.old]then
   local source=old.patches[inherit.old][category]
   if source then local ref=clone(source);ref.transforms=ref.transforms or {};ref.transforms[#ref.transforms+1]=clone(inherit)
    local ok,v=pcall(self.resolve,self,ref);if ok and equal(v,value)then desc=ref end
   end
  end
  entry.patches[patch][category]=desc or self:descriptor(path,value,nil)
  self:pause()
 end end
 for patch,groups in pairs(self.held_chunks and self.held_chunks[kind]or {})do for category,desc in pairs(groups)do
  entry.patches[patch]=entry.patches[patch]or {};entry.patches[patch][category]=entry.patches[patch][category]or clone(desc)
 end end
 self:history_build(entry,data,kind,old,revision)
 return entry
end
-- A saved match changed in memory is written again with the details it left in its file copied across as they are, so no step
-- decodes that file whole; only its damage parts are decoded, for the figures pages read. One whose file cannot be read, or no
-- longer holds a detail, writes nothing and keeps its entry, so the next launch leaves it out like any missing match.
function S:history_rewrite(run,ref,path)
 local bytes=self:bytes(ref.desc.file);self:pause(true)
 local spans=bytes and json_fields(bytes,function()self:pause(true)end)
 if not spans then return clone(ref.desc)end
 local resident,known,probe,parts={},{fields={}},{context=run.context},{}
 for k,v in pairs(run)do resident[k]=v;if detail_fields[k]then known.fields[k]=true;if k=="damage"or k=="team_damage"then probe[k]=v end end end
 for k in pairs(ref.fields or {})do if rawget(run,k)==nil then
  local span=spans[k];if not span then return clone(ref.desc)end
  local text=bytes:sub(span[1],span[2]);known.fields[k]=true;parts[#parts+1]=self.a.json.encode(k)..":"..text
  if k=="damage"or k=="team_damage"then local ok,v=pcall(self.decode,self,text);if not ok then return clone(ref.desc)end;probe[k]=v end
 end end
 bytes=nil;self:pause(true)
 local marks=resident.completion_markers
 if self.snapshots then self.snapshots[run]={summary=snapshot_of(resident,self:stepper()),end_screen=type(marks)=="table"and marks.end_screen or nil,known=known,probe=probe}end
 self:immutable(path,resident,self:encode_sliced(resident,parts));return {file=path},true
end
function S:history_build(entry,data,kind,old,revision)
 entry.history={};entry.history_present=data.run_history~=nil
 local old_history={};for _,desc in ipairs(old and old.history or {})do local id=desc.id;if id==nil then local ok,run=pcall(self.resolve,self,desc);id=ok and run.id end;old_history[tostring(id)]=desc end
 for i,run in ipairs(data.run_history or {})do
  local prefix=safe(run.context and run.context.patch).."/"..(kind=="general"and "match_history/"or kind=="solo"and "solo/match_history/"or "psykhanium/logs/")
  local id=safe(run.id or i);local previous=old_history[tostring(run.id)]
  local desc=self:history_descriptor(run);local ref=self.history_refs[run];local written=not desc
  if written and ref and ref.desc.file:sub(1,22)~="reconstruction_import/"then desc,written=self:history_rewrite(run,ref,loaded_path(self,prefix..id.."-"..revision..".json"))
  elseif written then
   -- an imported match whose file has gone writes nothing and keeps its entry, so the next launch leaves it out like any missing match
   if ref then if self.detail_file==ref.desc.file then self:release_details()end;if not pcall(self.history_detail,self,ref.desc)then desc=clone(ref.desc)end end
   written=not desc
   if written then local mt=getmetatable(run);local value=mt and mt.io_materialize and mt.io_materialize(run)or run
    -- taken before the file is packed, so a change made while a save spread over frames runs differs from it and is saved next time
    if self.snapshots then local marks=value.completion_markers;self.snapshots[run]={summary=snapshot_of(value,self:stepper()),end_screen=type(marks)=="table"and marks.end_screen or nil}end
    desc=self:descriptor(loaded_path(self,prefix..id.."-"..revision..".json"),value,(not ref or ref.desc.file:sub(1,22)=="reconstruction_import/")and previous or nil)
   end
  end
  local marks=run.completion_markers;local mark=type(marks)=="table"and marks.end_screen or nil
  desc.id=run.id;desc.patch=run.context and run.context.patch;desc.end_screen=not written and mark~=nil and not(ref and ref.end_screen==mark)and mark or nil
  entry.history[#entry.history+1]=desc;self:pause()
 end
end
local function rewrite_files(entry,paths)
 if type(entry)~="table"then return end
 if paths[entry.file]then entry.file=paths[entry.file]end
 for _,child in pairs(entry)do if type(child)=="table"then rewrite_files(child,paths)end end
end
function S:plan_backup_moves(manifest)
 if not self.a.move then return end
 manifest.backup_sequence=self.manifest.backup_sequence
 local paths,moves,folders,obsolete,ends={},{},{},{},{}
 -- what a transfer left undone goes on in this catalog, its files kept where they are and where they go
 if self.backup_transfer_pending then
  local listed={};referenced(manifest,listed)
  for _,move in ipairs(self.manifest.backup_moves or {})do if self.a.exists(move.from)then moves[#moves+1]=move;ends[move.from]=true;ends[move.to]=true end end
  for _,path in ipairs(self.manifest.backup_obsolete or {})do if not listed[path]and not ends[path]and not obsolete[path]and self.a.exists(path)then obsolete[path]=true;obsolete[#obsolete+1]=path end end
  for _,folder in ipairs(self.manifest.backup_folders or {})do folders[folder]=true end
 end
 if self.staged_backups then self:plan_new_moves(manifest,paths,moves,folders,obsolete,ends)end
 for _,path in ipairs(obsolete)do obsolete[path]=nil end
 if next(folders)then
  manifest.backup_folders={}
  for folder in pairs(folders)do manifest.backup_folders[#manifest.backup_folders+1]=folder end
  table.sort(manifest.backup_folders,function(a,b)return #a>#b or #a==#b and a<b end)
 end
 if moves[1]or obsolete[1]or manifest.backup_folders then manifest.backup_moves=moves;manifest.backup_obsolete=obsolete end
 -- every folder the moves go into is made by one mkdir in the background while the catalog is written
 if moves[1]and self.a.prepare then local to={};for i,move in ipairs(moves)do to[i]=move.to end;pcall(self.a.prepare,to,true)end
end
function S:plan_new_moves(manifest,paths,moves,folders,obsolete,ends)
 local active,carried,fresh={},#moves,false
 referenced(manifest.entries,active)
 local function move(from,to)
  if paths[from]or not self.a.exists(from)then return end
  assert(not self.a.exists(to),"Backup transfer destination already exists: "..to)
  paths[from]=to;moves[#moves+1]={from=from,to=to}
 end
 local backups=manifest.backups or {}
 local latest=backups[#backups]
 if #backups<#self:backups()then
  local remaining={};for _,backup in ipairs(backups)do if backup.folder then remaining[backup.folder]=true end end
  for _,backup in ipairs(self:backups())do
   if backup.folder and not remaining[backup.folder]then
    local root="Backup/"..backup.folder;folders[root]=true;fresh=true
    local files={};referenced(backup,files)
    for path in pairs(files)do
     local folder=path:match("^(.*)/[^/]+$")
     while folder and folder:sub(1,#root+1)==root.."/"do
      folders[folder]=true;folder=folder:match("^(.*)/[^/]+$")
     end
    end
   end
  end
 end
 if latest and #backups>#self:backups()then
  local id=(manifest.backup_sequence or 0)+1
  manifest.backup_sequence=id;latest.folder=id
  local files={};referenced(latest,files)
  for i=1,#backups-1 do referenced(backups[i],active)end
  for path in pairs(files)do
   if not active[path]then move(path,"Backup/"..id.."/"..(path:gsub("^Loaded Data/","")))end
  end
  rewrite_files(latest,paths)
 else
  local retained={};referenced(backups,retained)
  for path in pairs(active)do
   local relative=not retained[path]and path:match("^Backup/%d+/(.+)$")
   if relative then move(path,"Loaded Data/"..relative)end
  end
  rewrite_files(manifest.entries,paths);rewrite_files(manifest.missing,paths)
 end
 if #moves>carried or fresh then
  local keep={};referenced(manifest,keep)
  for _,path in ipairs(self.manifest.owned_files or {})do
   if not keep[path]and not paths[path]and not ends[path]and not obsolete[path]then obsolete[path]=true;obsolete[#obsolete+1]=path end
  end
 end
end
function S:build(revision,checkpoint_only,values,dirty)
 values,dirty=values or self.values,dirty or self.dirty;self.snapshots=setmetatable({},{__mode="k"})
 local manifest={format=1,revision=revision,entries={}}
 for key,value in pairs(values)do if value~=nil then
  local old=self.manifest.entries[key]
  if old and (not dirty[key]or checkpoint_only==true and key=="lifetime_records_v1")then manifest.entries[key]=clone(old)
  elseif checkpoint_only=="history"and key=="lifetime_records_v1"and old then
   -- Nothing set since the last history save leaves its catalog entry as it was, so the matches are not compared again.
   local entry=clone(old);local mark=history_mark(value);if not mark or self.history_clean~=mark then entry.cache_pending=true;self:history_build(entry,value,datasets[key],old,revision)end;manifest.entries[key]=entry
  elseif datasets[key]then manifest.entries[key]=self:dataset_build(value,datasets[key],old,revision)
  else
   local snapshot={};for field,item in pairs(value)do if field~="data_before"then snapshot[field]=item end end;local before=value.data_before
   local folder=(key=="unfinished_run_v1"or key=="solo_unfinished_v1")and "recovery/"or "shared/"
   local path=folder..safe(key).."-"..revision..".json"
   if key=="history_baseline_v1"or key=="friend_summaries_v1"then path=loaded_path(self,path)end
   -- an empty value, as friend summaries cleared for a rebuild, is marked empty, so no clear reads the old file to compare
   local empty=next(snapshot)==nil
   -- a mission's recovery can change under way, so it is encoded in one go
   local desc=empty and old and old.empty and clone(old)or self:descriptor(path,snapshot,not empty and old or nil,recovery_keys[key]);desc.empty=empty or nil
   if before then
    -- Mission-start rollback data is immutable. Cache only its file descriptor,
    -- weakly keyed by that mission's baseline, never another copy of its data.
    local cached=self.recovery_baselines[before]
    if cached then desc.before=clone(cached)else
     desc.before=self:dataset_build(before,"recovery-before",old and old.before or self.manifest.entries.lifetime_records_v1,revision)
     self.recovery_baselines[before]=clone(desc.before)
    end
   else desc.before=nil end
   manifest.entries[key]=desc
  end
  self:pause(true)
 end end
 for key in pairs(self.held or {})do local old=self.manifest.entries[key];if old and values[key]==nil and not dirty[key]then manifest.entries[key]=clone(old)end end
 -- A listed file drops off once the catalog references it again and it read cleanly this launch.
 local live,now,seen={},{},{};referenced(manifest.entries,live);for _,r in ipairs(self.skipped or {})do if r.file then now[r.file]=true end end
 for _,list in ipairs({self.manifest.missing or {},self.skipped or {},self.staged_missing or {}})do for _,r in ipairs(list)do local id=r.file or r.reason
  if not seen[id]and (not live[id]or now[id])then seen[id]=true;manifest.missing=manifest.missing or {};manifest.missing[#manifest.missing+1]=clone(r)end
 end end
 local backups=self.staged_backups or self:backups();if backups[1]then manifest.backups=clone(backups)end
 return manifest
end
-- A sliced checkpoint or save runs as a job about 2 ms a frame through step().
-- A pause marked save_only pauses a save and never a checkpoint.
function S:pause(save_only)
 local job=self.job;local co=coroutine.running()
 if job and co and job.cos[co]and(job.save or not save_only)and os.clock()-job.start>=job.budget then coroutine.yield()end
end
-- pcall for code that may pause: the game cannot yield across a pcall, so the
-- code runs in a child coroutine whose pauses are passed up to the job.
function S:try(f,...)
 local co=coroutine.create(f);local job=self.job;if job then job.cos[co]=true end
 local r={coroutine.resume(co,...)}
 while coroutine.status(co)=="suspended"do coroutine.yield();r={coroutine.resume(co)}end
 if job then job.cos[co]=nil end
 return unpack(r)
end
function S:step(budget)
 local job=self.job;if not job then return true end
 job.start=os.clock();job.budget=budget or self.slice_budget or 0.002
 local ok,result,err=coroutine.resume(job.co)
 if ok and coroutine.status(job.co)~="dead"then return nil end
 self.job=nil
 if not ok then self.error=tostring(result);return false,self.error end
 return result,err
end
function S:start(f)local co=coroutine.create(f);self.job={co=co,cos={[co]=true}};return self:step()end
-- A save spread over frames saves the values as they were when it began, each match list copied, so a match added or
-- taken away meanwhile waits for the next save.
local function frozen(values)
 local view={}
 for key,value in pairs(values)do
  if datasets[key]and type(value)=="table"and type(value.run_history)=="table"then
   local copy,runs={},{};for k,v in pairs(value)do copy[k]=v end;for i,run in ipairs(value.run_history)do runs[i]=run end;copy.run_history=runs;value=copy
  end
  view[key]=value
 end
 return view
end
-- a save that did not commit takes back the files it wrote, so a relaunch does not meet them under its own revision numbers
local function take_back(self,had,committing)
 self.unverified=nil;if self.a.abandon then pcall(self.a.abandon)end
 pcall(function()self.a.remove("index.json.tmp");local keep={};referenced(self.manifest,keep)
  -- once the catalog went to disk it may list them: keep what it lists, and everything when it is there but cannot be read
  if committing then for _,name in ipairs({"index.json","index.json.bak"})do local bytes=self.a.read(name)
   if bytes then local read,disk=pcall(self.decode,self,bytes);if read then referenced(disk,keep)end elseif name=="index.json"and(not self.a.exists or self.a.exists(name))then return end
  end end
  local gone={};for path in pairs(self.written or {})do if not had[path]and not keep[path]and path:sub(1,10)~="migration/"then self.a.remove(path);self.written[path]=nil;gone[path]=true end end
  for before,desc in pairs(self.recovery_baselines)do local refs={};referenced(desc,refs);for path in pairs(refs)do if gone[path]then self.recovery_baselines[before]=nil;break end end end
 end)
end
-- what was set while a sliced save ran is still to save after it
local function carry_late(self,state)for key in pairs(state.late)do self.dirty[key]=true;self.pending=true end end
local function save_body(self,checkpoint_only,state)
 local manifest,deferred
 if self.staged_backups then self:prepare_folders()end
 for attempt=1,32 do
  self.generation=math.max(self.generation or 0,tonumber(self.manifest.revision)or 0)+1
  local revision=string.format("%010d",self.generation)
  local built,value=self:try(self.build,self,revision,checkpoint_only,state.view,state.dirty)
  if built then manifest=value;break end
  if not tostring(value):find("Snapshot filename collision",1,true)then error(value)end
 end
 assert(manifest,"Cannot reserve a new data-file revision");deferred=state.deferred
 -- A journal this session wrote but never committed is stale once the catalog
 -- matches; without one, keep a journal that may only have failed to load.
 if equal(manifest.entries,self.manifest.entries)and equal(manifest.missing,self.manifest.missing)and equal(manifest.backups,self.manifest.backups)and not self.prune and not self.recovered and not self.journal_active then self.unverified=nil;if self.journal_written then self:clear_journal()end;self.pending=deferred or false;self.dirty=deferred and {lifetime_records_v1=true}or {};self.cache={};self:release_details();self.inheritances={};self.staged_backups=nil;self.staged_missing=nil;self.undo=nil;carry_late(self,state);return true end
 self:pause(true)
 self:plan_backup_moves(manifest)
 local keep={};referenced(manifest,keep);referenced(self.manifest,keep)
 for _,move in ipairs(manifest.backup_moves or {})do keep[move.from]=true;keep[move.to]=true end
 manifest.owned_files={};for path in pairs(keep)do manifest.owned_files[#manifest.owned_files+1]=path end;table.sort(manifest.owned_files)
 local bytes=self:encode(manifest);self:pause(true);self:room(#bytes)
 assert(self.a.write("index.json.tmp",bytes),"Cannot commit Information Overload catalog");self:to_verify("index.json.tmp",bytes);self:verify_pending()
 -- The catalog commits and memory follows it in one frame; only removing files nothing lists any more pauses after it.
 -- the catalog on disk is renamed to the backup only when it is known to be the one in memory, never after a launch from the backup
 local backup=not self.index_verified and(self.recovered or next(self.manifest.entries))and self:encode(self.manifest)or nil
 state.committing=true;self.index_verified=nil;assert(self.a.commit("index.json",bytes,backup),"Cannot commit Information Overload catalog")
 local disk=assert(self:read("index.json"));assert(equal(disk,manifest),"Committed catalog verification failed")
 if self.fresh_backup or not self.a.read("index.json.bak")then assert(self.a.write("index.json.bak",self:encode(manifest)),"Cannot preserve the catalog backup")end
 local previous=self.manifest;self.manifest=disk;self.index_verified=true;self.journal_active=nil;self.encoded_before_ref=nil;self.encoded_before_bytes=nil;self.encoded_before_revision=nil;local journal=drop_journal(self);self.pending=false;self.recovered=nil;self.fresh_backup=nil;self.inheritances={};self.staged_backups=nil;self.staged_missing=nil;self.undo=nil;self.prune=nil
 self.backup_sources={}
 for _,move in ipairs(disk.backup_moves or {})do self.backup_sources[move.to]=move.from end
 self.cache={};if checkpoint_only==true then self.dirty.lifetime_records_v1=nil;state.dirty.lifetime_records_v1=nil end;if checkpoint_only~=true or state.dirty.solo_records_v1 or state.dirty.psykhanium_logs_v1 then self:compact_history(state.view,state.dirty,state.late)end;self.dirty=deferred and {lifetime_records_v1=true}or {};self.pending=deferred or false;carry_late(self,state)
 self:finish_backup_moves(disk)
 for token in pairs(self.cache)do local file=token:match("^(.-)%z");if file and not keep[file]then self.cache[token]=nil end end
 -- the journal the catalog makes stale, then the files of the catalog before last
 for _,path in ipairs(journal)do self:pause(true);self.a.remove(path)end
 -- Keep current and previous catalog data, including inherited frozen snapshots.
 for _,path in ipairs(previous.owned_files or {})do if not keep[path]then self:pause(true);self.a.remove(path)end end
 local stale={};for path in pairs(self.written or {})do if path:sub(1,10)~="migration/"and not keep[path]then stale[#stale+1]=path end end
 for _,path in ipairs(stale)do self:pause(true);self.a.remove(path);self.written[path]=nil end
 return true
end
local function save_done(self,checkpoint_only,state,ok,result)
 self.snapshots=nil
 if not ok then take_back(self,state.had,state.committing);self.error=tostring(result);return false,self.error end
 self.error=nil;self.history_clean=checkpoint_only=="history"and not state.late.lifetime_records_v1 and history_mark(state.view.lifetime_records_v1)or nil;return true
end
-- Any other flush, and a reset, restore, import or new stats group, first finishes a checkpoint, or a save past its commit.
-- A save not yet committed is dropped instead: its files are taken back and what it held stays to save.
function S:settle()
 local job=self.job;if not job then return end
 if not job.save or job.save.committing then self:step(math.huge);return end
 self.job=nil;take_back(self,job.save.had,false);self.pending=true
end
-- A sliced flush returns nil while its job runs. A baseline that takes more than
-- this frame finishes as its own job and returns "baseline", so the caller takes
-- a fresh snapshot for the checkpoint instead of one from frames ago.
function S:flush(checkpoint_only,sliced)
 self:settle()
 if not self.ready then return true end
 if not self.pending then return true end
 -- the reason a failed save gives is this save's own
 self.a.failure=nil
 if checkpoint_only==true and sliced and self:journal_ready()then
  local m=self.values.unfinished_run_v1
  if not self.recovery_baselines[m.data_before]then
   local result,err=self:start(function()self:recovery_baseline(m);return "baseline"end)
   if result~="baseline"then return result,err end
  end
  return self:start(function()return self:checkpoint_journal()end)
 end
 if checkpoint_only==true then local result,err=self:checkpoint_journal();if result~=nil then return result,err end end
 local state={view=frozen(self.values),dirty={},had={},late={},deferred=checkpoint_only and self.dirty.lifetime_records_v1}
 for key in pairs(self.dirty)do state.dirty[key]=true end;for path in pairs(self.written or {})do state.had[path]=true end
 -- a reset, restore, import or new stats group saves in one go
 if sliced and checkpoint_only~=true and not(self.staged_backups or self.prune or next(self.inheritances))then
  -- its first slice runs with the frame's other saves, not on top of whatever asked for it
  local co=coroutine.create(function()return save_done(self,checkpoint_only,state,self:try(save_body,self,checkpoint_only,state))end)
  self.job={co=co,cos={[co]=true},save=state};return nil
 end
 return save_done(self,checkpoint_only,state,pcall(save_body,self,checkpoint_only,state))
end
-- A mission's recovery baseline is built over frames as the mission starts, once, so the checkpoint written in one go as it ends finds it
-- built even when the mission ends before its first checkpoint
function S:prepare_baseline(before)
 if self.job or not self.ready or type(before)~="table"or self.recovery_baselines[before]then return end
 self.baselines_tried=self.baselines_tried or setmetatable({},{__mode="k"});if self.baselines_tried[before]then return end;self.baselines_tried[before]=true
 return self:start(function()self:recovery_baseline({data_before=before});return true end)
end
local function clear_legacy(mod)
 for _,key in ipairs(legacy_keys)do mod:set(key,nil,false)end
 local dmf=get_mod and get_mod("DMF")
 if dmf and type(dmf.save_unsaved_settings_to_file)=="function"then dmf.save_unsaved_settings_to_file()end
end
function S:migrate(mod)
 local legacy={};for _,key in ipairs(legacy_keys)do local value=mod:get(key);if value~=nil then legacy[key]=clone(value)end end
 if not next(legacy)then return true end
 -- Never overwrite an already verified file database with stale settings leftovers.
 local has_records=self.manifest.entries.lifetime_records_v1 or self.manifest.entries.solo_records_v1 or self.manifest.entries.psykhanium_logs_v1
 if not has_records then
  for key in pairs(datasets)do if legacy[key]~=nil then validate_dataset(legacy[key])end end
  self:immutable("migration/legacy-settings.json",legacy);self:verify_pending()
  for key,value in pairs(legacy)do if key~="patch_merge_backup_v1"then self:set(key,value)end end
  if not next(self.values)then self:set("lifetime_records_v1",{schema=1,rows={}})end
  local saved,save_error=self:flush();assert(saved,save_error or self.error)
  self.cache={}
  local disk=self:load_manifest(assert(self:read("index.json")))
  for key,value in pairs(legacy)do if key~="patch_merge_backup_v1"then assert(equal(value,disk[key]),"Migration verification failed for "..key)end end
 else
  -- Files already passed full validation. Archive settings leftovers rather than
  -- replacing the active file database or repeatedly loading the settings blobs.
  for index=1,32 do local path="migration/settings-leftovers-"..index..".json"
   if not self.a.read(path)then self:immutable(path,legacy);self:verify_pending();break end
  end
 end
 clear_legacy(mod)
 self.migrated=true;return true
end
function S.game_adapter()
 assert(Mods and Mods.lua and Mods.lua.io and Mods.lua.os and cjson,"File storage is unavailable")
 local io,os=Mods.lua.io,Mods.lua.os;local app=assert(os.getenv("APPDATA"),"APPDATA is unavailable")
 assert(not app:find('["\r\n&|<>%%!]'),"Unsupported APPDATA path")
 local base=app:gsub("\\","/").."/Fatshark/Darktide/";local root=base.."InformationOverload/"
 local a={root=root,json=cjson,created={},directories={}}
 local function full(path)assert(not path:find("..",1,true)and not path:match("^[/\\]")and not path:find(":",1,true),"Invalid data path");return root..path end
 -- Folders are made and checked through kernel32 where the game's FFI reaches it, one level at a time: no mkdir window and no
 -- wait. Wine's mkdir makes no missing parent for a path with forward slashes, so under Proton no match folder was ever made.
 local win
 do local ffi=Mods.lua.ffi
  if ffi then
   pcall(ffi.cdef,"int CreateDirectoryA(const char *path, void *security);")
   pcall(ffi.cdef,"unsigned long GetFileAttributesA(const char *path);")
   pcall(ffi.cdef,"int RemoveDirectoryA(const char *path);")
   local ok,C=pcall(function()local C=ffi.C;return C.CreateDirectoryA and C.GetFileAttributesA and C.RemoveDirectoryA and C end)
   if ok and C then win=C end
  end
 end
 local function windows(path)return (path:gsub("/","\\"))end
 -- INVALID_FILE_ATTRIBUTES, read as unsigned or, where another mod declared it signed, as -1
 local function win_exists(path)local at=tonumber(win.GetFileAttributesA(windows(path)));return at~=nil and at~=0xFFFFFFFF and at~=-1 end
 local function win_make(folder)
  folder=folder:gsub("[/\\]+$","")
  if win_exists(folder)then return true end
  local parent=folder:match("^(.*)[/\\][^/\\]+$")
  if parent and parent:find("[/\\]")and not win_make(parent)then return false end
  win.CreateDirectoryA(windows(folder),nil)
  return win_exists(folder)
 end
 -- Without it, making a folder runs Windows' mkdir, which holds the game about 0.4 s. prepare starts it in the background ahead
 -- of a save, and a write into a folder still being made waits only for what is left of that.
 local making={}
 -- Opening a folder fails with code 13, far quicker than renaming it onto itself; a file that opens is there too.
 -- The rename still answers when io.open gives no code.
 local function exists(path)
  if win then return win_exists(path)end
  local f,_,code=io.open(path,"rb");if f then f:close();return true end
  if code==nil then local ok,_,c=os.rename(path,path);return ok==true or c==13 end
  return code==13
 end
 function a.exists(path)return exists(full(path))end
 -- with now and no io.popen, the one mkdir runs at once instead
 function a.prepare(paths,now)
  local missing,seen={},{}
  for _,path in ipairs(paths)do local folder=full(path):match("^(.*)/[^/]*$")
   if folder and not a.directories[folder]and not making[folder]and not seen[folder]then seen[folder]=true
    if exists(folder)then a.directories[folder]=true else missing[#missing+1]=folder end
   end
  end
  if win then for _,folder in ipairs(missing)do if win_make(folder)then a.directories[folder]=true end end;return end
  if not io.popen and not now then return end
  -- one mkdir for many folders, kept well inside cmd's 8191-character line
  local i=1
  while missing[i]do local parts,length={},0
   while missing[i]and(length==0 or length+#missing[i]<7000)do parts[#parts+1]=missing[i];length=length+#missing[i]+3;i=i+1 end
   local command='mkdir "'..windows(table.concat(parts,'" "'))..'" 2>NUL'
   if io.popen then local ok,pipe=pcall(io.popen,command,"r");if ok and pipe then for _,folder in ipairs(parts)do making[folder]=pipe end end
   else os.execute(command.." >NUL")end
  end
 end
 local removing={}
 local function directory(path)
  -- a folder is used only once the empty folders being removed are gone
  if removing[1]then for _,pipe in ipairs(removing)do pcall(pipe.close,pipe)end;removing={}end
  local folder=full(path):match("^(.*)/[^/]*$")
  if a.directories[folder]then return true end
  local pipe=making[folder]
  if pipe then for other,p in pairs(making)do if p==pipe then making[other]=nil end end;pcall(pipe.close,pipe)end
  if win then if not win_make(folder)then a.failure="could not make the folder "..(path:match("^(.*)/[^/]*$")or "of the save");return false end
  elseif not exists(folder)then os.execute('mkdir "'..windows(folder)..'" >NUL 2>NUL');if not exists(folder)then a.failure="could not make the folder "..(path:match("^(.*)/[^/]*$")or "of the save");return false end end
  a.directories[folder]=true;return true
 end
 -- rmdir without /s leaves folders with any remaining files alone. It runs in the background like mkdir.
 function a.remove_empty_folders(folders)
  local commands,command={},""
  for _,folder in ipairs(folders)do
   assert(folder:match("^Backup/%d+$")or folder:match("^Backup/%d+/[%w_./ -]+$"),"Invalid backup folder")
   a.directories[full(folder)]=nil
   if win then if a.exists(folder)then win.RemoveDirectoryA(windows(full(folder)))end
   elseif a.exists(folder)then
    local part='rmdir "'..folder:gsub("/","\\")..'" 2>NUL'
    if #command+#part>6000 then commands[#commands+1]=command;command=""end
    command=command==""and part or command.." & "..part
   end
  end
  if command~=""then commands[#commands+1]=command end
  for i,c in ipairs(commands)do
   c='cd /d "'..root:gsub("/","\\")..'" && ('..c..")"
   -- folders go after what is in them, so a further batch waits for the one before it
   if i>1 then for _,pipe in ipairs(removing)do pcall(pipe.close,pipe)end;removing={}end
   local ok,pipe=false,nil;if io.popen then ok,pipe=pcall(io.popen,c,"r")end
   if ok and pipe then removing[#removing+1]=pipe else os.execute(c)end
  end
 end
 function a.move(from,to)
  return directory(to)and os.rename(full(from),full(to))
 end
 function a.ensure_import_directory()return directory("reconstruction_import/")end
 function a.read(path)local f=io.open(full(path),"rb");if not f then return nil end;local bytes=f:read("*a");f:close();return bytes end
 function a.list(folder)
  assert(folder=="reconstruction_import/","Unsupported scan folder")
  local prefix=full(folder);local command='dir /b /s /a-d "'..prefix:gsub("/","\\")..'*.json" 2>NUL'
  local pipe=io.popen and io.popen(command,"r")
  local temporary
  if not pipe then
   temporary="shared/reconstruction-scan.txt";assert(directory(temporary),"Cannot prepare local folder scan")
   os.execute(command..' >"'..full(temporary)..'"');pipe=assert(io.open(full(temporary),"r"),"Local folder scanning is unavailable")
  end
  local out={};for line in pipe:lines()do local path=line:gsub("\\","/");if path:sub(1,#root):lower()==root:lower()then out[#out+1]=path:sub(#root+1)end end;pipe:close();if temporary then os.remove(full(temporary))end;return out
 end
 function a.write(path,bytes)
  if not directory(path)then return false end
  local f=io.open(full(path),"wb");if not f then a.failure="could not write "..path;return false end;local wrote=f:write(bytes);local closed=f:close();if wrote and closed then a.created[path]=true;return true end;os.remove(full(path));a.failure="could not finish writing "..path;return false
 end
 function a.remove(path)return os.remove(full(path))end
 -- A big file is written, read and compared a part at a time, pause() between parts. The open file stays in a.open until it
 -- closes, so a save given up part way closes it before removing the file.
 a.part=256*1024
 function a.abandon()local f=a.open;a.open=nil;if f then pcall(f.close,f)end end
 function a.write_parts(path,bytes,pause)
  if not directory(path)then return false end
  local f=io.open(full(path),"wb");if not f then a.failure="could not write "..path;return false end;a.open=f
  local wrote=true;for i=1,#bytes,a.part do wrote=f:write(bytes:sub(i,i+a.part-1));if not wrote then break end;pause()end
  a.open=nil;local closed=f:close();if wrote and closed then a.created[path]=true;return true end;os.remove(full(path));a.failure="could not finish writing "..path;return false
 end
 function a.read_parts(path,pause)
  local f=io.open(full(path),"rb");if not f then return nil end;a.open=f
  local parts={};while true do local s=f:read(a.part);if not s then break end;parts[#parts+1]=s;pause()end
  a.open=nil;f:close();return table.concat(parts)
 end
 function a.same(path,bytes,pause)
  local f=io.open(full(path),"rb");if not f then return false end;a.open=f
  local at,same=1,true;while true do local s=f:read(a.part);if not s then break end;if s~=bytes:sub(at,at+#s-1)then same=false;break end;at=at+#s;pause()end
  a.open=nil;f:close();return same and at==#bytes+1
 end
 -- Alternate two recovery slots: the other slot remains the last good commit.
 -- Each checkpoint overwrites the older slot in place, unread: a damaged one
 -- fails to decode on load and the other slot is used.
 function a.journal_atomic(path,bytes)return a.write(path,bytes)end
 -- path..".tmp" is already written and read back. The file it replaces becomes the .bak by a rename, or with previous
 -- the .bak is written from that instead, when the caller cannot vouch for the file on disk.
 function a.commit(path,bytes,previous)
  local live,bak=full(path),full(path..".bak");local original=a.read(path)
  if not original and exists(live)then return false end
  if original then
   if previous then if not a.write(path..".bak",previous)or a.read(path..".bak")~=previous then return false end;os.remove(live)
   else os.remove(bak);if not os.rename(live,bak)then a.write(path..".bak",original);return false end end
  end
  if not os.rename(full(path..".tmp"),live)then if original then a.write(path,original)end;return false end
  return a.read(path)==bytes
 end
 function a.atomic(path,bytes,verified_previous)
  if not a.write(path..".tmp",bytes)or a.read(path..".tmp")~=bytes then return false end
  return a.commit(path,bytes,verified_previous)
 end
 local function reader(folder)return function(path)
  assert(not path:find("..",1,true)and not path:find(":",1,true)and not path:match("^[/\\]"),"Invalid legacy path")
  local f=io.open(folder..path,"rb");if not f then return nil end
  local bytes=f:read("*a");f:close();return bytes
 end end
 -- Newest save folder wins and the others are left alone. information_overload/ is moved
 -- across whole; personal_records/ can still belong to the old mod, so it is only copied.
 function a.import_legacy()
  if a.read("index.json")or a.read("index.json.bak")then return false end
  for _,name in ipairs({"information_overload","personal_records"})do local read=reader(base..name.."/")
   if read("index.json")or read("index.json.bak")then
    if name=="information_overload"and os.rename(base..name,base.."InformationOverload")then return true end
    return S.copy_legacy(a,read)
   end
  end
  return false
 end
 return a
end
-- Copy a verified catalog and all referenced files, each under its own name only once whole; publish the new index last.
-- Legacy files are never removed or written. Failure leaves the source untouched.
-- A referenced file that is missing is skipped and listed in migration/skipped-legacy-files.json.
function S.copy_legacy(adapter,read_legacy)
 if adapter.read("index.json")or adapter.read("index.json.bak")then return false end
 local bytes,manifest,found
 for _,name in ipairs({"index.json","index.json.bak"})do local candidate=read_legacy(name)
  if candidate and not bytes then found=true;local ok,value=pcall(adapter.json.decode,candidate)
   if ok and type(value)=="table"and value.format==1 and type(value.entries)=="table"then bytes,manifest=candidate,value end
  end
 end
 if not found then return false end
 assert(bytes,"Unsupported legacy catalog")
 local references={}
 local function scan(v)
  if type(v)~="table"then return end
  if type(v.file)=="string"then references[v.file]=true end
  for _,x in pairs(v)do scan(x)end
 end
 scan(manifest)
 -- Preserve compatible recovery journals and the extra files their baseline references.
 for _,path in ipairs({"recovery/checkpoint-0.json","recovery/checkpoint-1.json","recovery/checkpoint.json","recovery/checkpoint.json.bak"})do
  local journal=read_legacy(path)
  if journal then
   local ok,envelope=pcall(adapter.json.decode,journal)
   if ok and type(envelope)=="table"and envelope.format==1 and envelope.base_revision==manifest.revision then references[path]=true;scan(envelope)end
  end
 end
 local skipped={}
 for path in pairs(references)do
  local content=not path:find("..",1,true)and not path:find(":",1,true)and not path:match("^[/\\]")and read_legacy(path)
  if content then
   local existing=adapter.read(path)
   assert(not existing or existing==content,"Conflicting destination file: "..path)
   if not existing then assert(adapter.atomic(path,content),"Legacy copy failed: "..path)end
   assert(adapter.read(path)==content,"Legacy copy verification failed: "..path)
  else skipped[#skipped+1]=path end
 end
 if skipped[1]then table.sort(skipped);adapter.skipped=skipped;adapter.write("migration/skipped-legacy-files.json",adapter.json.encode(skipped))end
 assert(adapter.atomic("index.json",bytes),"Legacy catalog publication failed")
 return true
end
function S.bind(mod,patch,adapter)
 local active_adapter=adapter
 local attempted
 local ok,store=pcall(function()active_adapter=active_adapter or S.game_adapter();if active_adapter.import_legacy then active_adapter.import_legacy()end;if active_adapter.ensure_import_directory then active_adapter.ensure_import_directory()end;local st=S.new(active_adapter,patch);attempted=st;st.tell=function(text)mod:echo("%s",text)end;st:open();st:migrate(mod);return st end)
 if not ok then
  local error_text=tostring(store)
  -- Fail closed: keep all existing files/settings and disable disk writes.
  store={values={},error=error_text,unavailable=true,history_refs={},get=function(self,key)return self.values[key]end,set=function(self,key,value)self.values[key]=value end,flush=function(self)return false,self.error end,inherit=function()end,release_details=function()end}
  mod:echo("Saving is off. Saved data could not be opened, so nothing will be saved until this is fixed. Your files were left as they are.\n%s",error_text)
 else
  local files={};for _,path in ipairs(active_adapter.skipped or {})do files[path]=true end;for id in pairs(store.unreported or {})do files[id]=true end
  local count=0;for _ in pairs(files)do count=count+1 end
  if count>0 then mod:echo("%d saved file(s) were missing or unreadable and were left out. Everything else loaded, and saving works.",count)end
 end
 mod.io_data_get=function(key)return store:get(key)end
 mod.io_data_set=function(key,value)return store:set(key,value)end
 mod.io_storage=store;return store
end
return S
