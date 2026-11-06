local D={}
function D.clean(name)
 if type(name)~="string"then return name end
 for _,symbol in ipairs({"ツ","ãƒ„","□","�"})do name=name:gsub(symbol,"")end
 -- ASCII spaces only: %s can take the last byte of a character such as à for one
 local result=name:gsub("[ \t\r\n\f\v]+$",""):gsub("^[ \t\r\n\f\v]+","");return result
end
return D
