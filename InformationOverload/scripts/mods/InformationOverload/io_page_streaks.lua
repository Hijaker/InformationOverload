-- Information Overload: the Streaks page, for all classes or one.
local mod=get_mod("information_overload")
local D=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/io_view_definitions")
local K=mod:io_dofile("InformationOverload/scripts/mods/InformationOverload/io_data_career")
return function(view,cv,popup)
 local tracker=view:_tracker();local model=view.model
 if not tracker or not model or model.empty then K.empty(view,cv);return end
 view:_scope(cv,popup,model,nil,true);local s=view.scope
 local cls=view.io_streak_cls or "all";local name="All Classes";local found=cls=="all";local opts={{value="all",label="All Classes"}}
 for _,c in ipairs(K.played(tracker,s.patch,s.mode))do opts[#opts+1]={value=c.id,label=c.name};if c.id==cls then found=true;name=c.name end end
 if not found then cls="all";view.io_streak_cls=nil end
 K.dropdown(view,cv,popup,"io_scls",D.right-280,D.row2,280,"Class:",name,cls,opts,function(v)view.io_streak_cls=v end)
 view.io_crumbs={{"Streaks",cls~="all"and function()view.io_streak_cls=nil end or nil},{name}}
 local mine,team=K.streaks(tracker,s.patch,s.mode,cls~="all"and cls or nil)
 view:_sheet(cv,D.sheet);K.streak_table(view,cv,D.sheet,mine,team);view:_sheet_end(cv)
end
