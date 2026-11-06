-- Information Overload: the Deaths page, what downed or killed you.
local mod=get_mod("information_overload")
local D=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/io_view_definitions")
local K=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/io_data_career")
local DASH=K.dash
local COLS={{"Group"},{"Downs",850},{"Deaths",1033},{"Total",D.right-10}}
local function pair(n,p,tail)if type(n)~="number"then return DASH end;return tostring(n)..(p and " · "..p or "")..(tail or "")end
return function(view,cv,popup)
 local tracker=view:_tracker();local model=view.model
 if not tracker or not model or model.empty then K.empty(view,cv);return end
 view:_scope(cv,popup,model,nil,true)
 local m=K.deaths(tracker,view.scope)
 local det=view.io_death_det or "all";local cur
 for _,o in ipairs(m.opts)do if o.value==det then cur=o end end
 if not cur then det="all";cur=m.opts[1];view.io_death_det=nil end
 local show=view.io_death_view or "grouped"
 K.seg(view,cv,D.left,D.row2,"Show:",{{"grouped","Grouped"},{"individual","Individual"}},show,function(v)view.io_death_view=v end)
 K.dropdown(view,cv,popup,"io_ddet",D.right-280,D.row2,280,"Detail:",cur.label,det,m.opts,function(v)view.io_death_det=v~="all"and v or nil;view.io_death_up=nil end)
 -- an enemy opened from a group's list steps back up to that group
 local up;if det:sub(1,2)=="e:"then for _,o in ipairs(m.opts)do if o.value==view.io_death_up then up=o end end end
 local trail={{"Deaths",det~="all"and function()view.io_death_det=nil;view.io_death_up=nil end or nil}}
 if up then trail[2]={up.label,function()view.io_death_det=up.value;view.io_death_up=nil end}end
 trail[#trail+1]={cur.label};view.io_crumbs=trail
 if #m.enemies==0 and m.all.total==0 then view:_card(cv,D.left,D.sheet,D.width,92,"No Downs Or Deaths Recorded Yet");return end
 view:_sheet(cv,D.sheet);local y=D.sheet;local a=m.all
 if det=="all"then
  local l=m.lethal
  local lrows=l and {{head=l.parts},{"Downs",pair(l.downs,K.share(l.downs,a.downs))},{"Deaths",pair(l.deaths,K.share(l.deaths,a.deaths))},{"Total",pair(l.total,K.share(l.total,a.total))}}
   or {{"Downs",DASH},{"Deaths",DASH},{"Total",DASH}}
  local per=function(n)return m.games>0 and pair(n,(string.format("%.1f",n/m.games):gsub("%.0$",""))," Per Game")or pair(n)end
  local h1=K.card(view,cv,D.left,y,D.col,"Most Lethal Enemy",nil,lrows)
  local h2=K.card(view,cv,D.col2,y,D.col,"Deaths And Downs",nil,{{"Total Deaths And Downs",per(a.total)},{"Downs",per(a.downs)},{"Deaths",per(a.deaths)}})
  y=y+math.max(h1,h2)+14
 end
 local function cells(v)return {v.downs,v.deaths,v.total}end
 local rows={}
 if det:sub(1,2)=="e:"then local e
  for _,x in ipairs(m.enemies)do if "e:"..x.key==det then e=x end end
  if e then local v=e.v;local parts={};for _,p in ipairs(e.parts)do parts[#parts+1]=p end
   K.card(view,cv,D.left,y,D.col,e.label,table.concat(parts," / "),{{"Downs",pair(v.downs.n,v.downs.p," Of Yours")},{"Deaths",pair(v.deaths.n,v.deaths.p," Of Yours")},{"Total",pair(v.total.n,v.total.p," Of Yours")}})
  end
  view:_sheet_end(cv);return
 elseif show=="grouped"and det=="all"then
  for _,g in ipairs(m.groups)do local c=cells(g.v);rows[#rows+1]={g.parts,c[1],c[2],c[3]}
   for _,s in ipairs(g.subs or {})do local sc=cells(s.v);rows[#rows+1]={s.parts,sc[1],sc[2],sc[3],ind=true}end
  end
  K.table(view,cv,D.left,y,D.width,COLS,rows)
 else
  local last
  for _,e in ipairs(m.enemies)do
   local keep=det=="all"or det=="g:"..e.group or det=="s:"..e.group.."|"..tostring(e.sub)
   if keep then local head=table.concat(e.parts," / ");if head~=last then rows[#rows+1]={grp=e.parts};last=head end
    local key=e.key;local c=cells(e.v);rows[#rows+1]={e.label,c[1],c[2],c[3],fn=function()view.io_death_up=det~="all"and det or nil;view.io_death_det="e:"..key end}
   end
  end
  K.table(view,cv,D.left,y,D.width,{{"Enemy"},COLS[2],COLS[3],COLS[4]},rows)
 end
 view:_sheet_end(cv)
end
