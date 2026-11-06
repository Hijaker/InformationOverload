-- Derived data is disposable. Only a successful atomic catalog commit makes
-- its history revision/version/patch stamp current on disk.
local C={};C.__index=C
function C.new(saved,version,patch)
 local state=saved or {revision=0}
 return setmetatable({state=state,version=version,patch=patch},C)
end
function C:valid()
 local s=self.state;local c=s.cache
 return not s.pending and c and c.revision==s.revision and c.version==self.version and c.patch==self.patch and c.signature==s.signature
end
function C:prepare()
 if self.state.pending then return false end
 self.state.pending=(self.state.revision or 0)+1;return true
end
function C:commit(signature)
 local s=self.state
 if s.signature==signature then if s.pending then s.pending=nil;return true end;return false end
 s.revision=s.pending or (s.revision or 0)+1;s.pending=nil;s.signature=signature;s.cache=nil;return true
end
function C:stamp()
 local s=self.state;s.cache={revision=s.revision,version=self.version,patch=self.patch,signature=s.signature}
end
return C
