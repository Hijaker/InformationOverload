-- Information Overload: the Speedrunning page, the fastest clear on each map.
local mod=get_mod("information_overload")
local base="InformationOverload/scripts/mods/InformationOverload/"
local D=mod:io_dofile(base.."io_view_definitions")
local K=mod:io_dofile(base.."io_data_career")
local Overview=mod:io_dofile(base.."io_overview")
local H=mod:io_dofile(base.."history_presentation")
return function(view,cv,popup)
 local tracker=view:_tracker();local model=view.model
 if not tracker or not model or model.empty then K.empty(view,cv);return end
 view:_scope(cv,popup,model,true)
 local zones=K.speed(tracker,view.scope)
 local pick=view.io_speed_map;local chosen;local opts={{value="all",label="All Maps"}}
 for _,z in ipairs(zones)do opts[#opts+1]={h=z.label};for _,m in ipairs(z.maps)do opts[#opts+1]={value=m.key,label=m.name,ind=1,n=m.time};if m.key==pick then chosen=m end end end
 if not chosen then view.io_speed_map=nil end
 local label=chosen and chosen.name or "All Maps"
 K.dropdown(view,cv,popup,"io_smap",D.right-280,D.row2,280,"Map:",label,chosen and chosen.key or "all",opts,function(v)view.io_speed_map=v~="all"and v or nil end)
 view.io_crumbs={{"Speedrunning",chosen and function()view.io_speed_map=nil end or nil},{label}}
 if #zones==0 then view:_card(cv,D.left,D.sheet,D.width,92,"No Clear Times Recorded Yet");return end
 view:_sheet(cv,D.sheet)
 if chosen then local run=chosen.run
  K.card(view,cv,D.left,D.sheet,D.col,chosen.name,Overview.diff_label(run.context),K.speed_rows(run),K.open_run(view,run.id))
 else
  local rows={}
  for _,z in ipairs(zones)do rows[#rows+1]={grp=z.label}
   for _,m in ipairs(z.maps)do local key=m.key;rows[#rows+1]={m.name,m.time,m.run.started_at and H.timestamp(m.run.started_at)or K.dash,fn=function()view.io_speed_map=key end}end
  end
  K.table(view,cv,D.left,D.sheet,D.width,{{"Map"},{"Fastest",884},{"Set On",D.right-10,"dim"}},rows)
 end
 view:_sheet_end(cv)
end
