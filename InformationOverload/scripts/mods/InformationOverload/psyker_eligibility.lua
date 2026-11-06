local E={}
function E.crystalline(profile)
 local value=profile and profile.talents and profile.talents.psyker_alternative_peril_explosion
 if type(value)=="table" then value=value.tier end
 return value==true or type(value)=="number" and value>0
end
return E
