
CREATE TABLE secure(
   Offset						VARCHAR(18)
  ,SecurityDescriptorHash		VARCHAR(10)
  ,SecurityId					INTEGER 
  ,Control						MEDIUMTEXT 
  ,SidOwner						VARCHAR(128)
  ,SidGroup						VARCHAR(128)
  ,SAclRevision					INTEGER
  ,SAceCount					INTEGER
  ,SAceType						MEDIUMTEXT
  ,SAceFlags					MEDIUMTEXT
  ,SAceMask						MEDIUMTEXT
  ,SAceObjectFlags				MEDIUMTEXT
  ,SAceObjectType				MEDIUMTEXT
  ,SAceInheritedObjectType		MEDIUMTEXT 
  ,SAceSIDofTrustee				MEDIUMTEXT 
  ,DAclRevision					INTEGER 
  ,DAceCount					INTEGER
  ,DAceType						MEDIUMTEXT 
  ,DAceFlags					MEDIUMTEXT 
  ,DAceMask						MEDIUMTEXT 
  ,DAceObjectFlags				MEDIUMTEXT 
  ,DAceObjectType				MEDIUMTEXT 
  ,DAceInheritedObjectType		MEDIUMTEXT
  ,DAceSIDofTrustee				MEDIUMTEXT 
);