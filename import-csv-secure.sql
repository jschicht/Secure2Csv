LOAD DATA INFILE "__PathToCsv__"
INTO TABLE secure
CHARACTER SET 'latin1'
COLUMNS TERMINATED BY '|'
OPTIONALLY ENCLOSED BY '"'
ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(`Offset`, `SecurityDescriptorHash`, @SecurityId, `Control`, `SidOwner`, SidGroup, @SAclRevision, @SAceCount, SAceType, `SAceFlags`, SAceMask, SAceObjectFlags, SAceObjectType, SAceInheritedObjectType, SAceSIDofTrustee, @DAclRevision, @DAceCount, DAceType, DAceFlags, DAceMask, DAceObjectFlags, DAceObjectType, DAceInheritedObjectType, DAceSIDofTrustee)
SET 
SecurityId = nullif(@SecurityId,''),
SAclRevision = nullif(@SAclRevision,''),
SAceCount = nullif(@SAceCount,''),
DAclRevision = nullif(@DAclRevision,''),
DAceCount = nullif(@DAceCount,'')
;