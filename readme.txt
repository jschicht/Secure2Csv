Introduction
This is a parser for the $Secure system file on NTFS. The $Secure file basically contains all security descriptors used on the volume. Information about this file is found in MFT record number 9. The actual security descriptors are stored within a named data stream, $SDS. The OS uses 2 indexes, $SDH and $SII, for easy lookup in $SDS. The $SDH and $SII indexes are found as named streams for either $INDEX_ROOT or $INDEX_ALLOCATION attribute. These streams (when $INDEX_ALLOCATION) are thus so-called INDX records. There may also be $Bitmap attributes found within $Secure that relates to $SDH and $SII, but this is not really relevant for the decoded security descriptors.


Details about security descriptors
All files and folders in $MFT are linked to a security descriptor, by a SecurityId which is unique per volume. Security descriptors contain information to control access to objects (files/folders when concerning NTFS). From Microsoft (https://technet.microsoft.com/en-us/library/cc781716(v=ws.10).aspx):

Security descriptors include information about who owns an object, who can access it and in what way, and what types of access are audited. Security descriptors, in turn, contain the access control list (ACL) of an object, which includes all of the security permissions that apply to that object. An object�s security descriptor can contain two types of ACLs:

� A discretionary access control list (DACL) that identifies the users and groups who are allowed or denied access
� A system access control list (SACL) that controls how access is audited

There's also numerous structures to handle. This is the top level one.
typedef struct _SECURITY_DESCRIPTOR {
  UCHAR  Revision;
  UCHAR  Sbz1;
  SECURITY_DESCRIPTOR_CONTROL  Control;
  PSID  Owner;
  PSID  Group;
  PACL  Sacl;
  PACL  Dacl;
} SECURITY_DESCRIPTOR, *PISECURITY_DESCRIPTOR;

In short, the Control field must contain the SE_SELF_RELATIVE bit mask. Owner and Group are pointers to SID structures. Sacl and Dacl are pointers to the respective data structures for system ACL and descretionary ACL.

Any given security descriptor can therefore contain several sets of Type, Flags, SID's and access masks, as any ACL (SACL/DACL) may be constructed of several ACE's. So each security descriptor has at least 2 SID's (owner and primary group) and 1 per ACE (a trustee identified by a SID).

In the output the exist 2 sets of the same type of variables, where the ones prefixed with S are for SACL and those prefixed with D are for DACL.


About output
All output will be prefixed with a timestamp, and written to same directory as program is launched from.
The csv contains all the decoded security descriptors found in $SDS. See section about the explanation of output variables.


Explanation of output variables:
Offset: The offset of the descriptor in $SDS.
SecurityDescriptorHash: Descriptor hash in big endian.
SecurityId: The Id that can be mapped from MFT record.
Control: Control access bit mask.
SidOwner: This SID specifies the owner of the object to which the security descriptor is associated.
SidGroup: This SID specifies the group of the object to which the security descriptor is associated.
--SACL
SAclRevision: The revision of the ACL.
SAceCount: The number of ACE records in the ACL.
SAceType: A bit mask for the ACE type.
SAceFlags: A bit mask for a set of ACE type-specific control flags. *
SAceMask: A bit mask specifying the suer rights allowed/disallowed by this ACE.
SAceObjectFlags: A bit flag that indicate whether the ObjectType and InheritedObjectType fields contain valid data.
SAceObjectType: A GUID that identifies a property set, property, extended right, or type of child object.
SAceInheritedObjectType: A GUID that identifies the type of child object that can inherit the ACE.
SAceSIDofTrustee: The SID of a trustee.
--DACL
DAclRevision: The revision of the ACL.
DAceCount: The number of ACE records in the ACL.
DAceType: A bit mask for the ACE type.
DAceFlags: A bit mask for a set of ACE type-specific control flags. *
DAceMask: A bit mask specifying the suer rights allowed/disallowed by this ACE.
SAceObjectFlags: A bit flag that indicate whether the ObjectType and InheritedObjectType fields contain valid data.	
DAceObjectType: A GUID that identifies a property set, property, extended right, or type of child object.
DAceInheritedObjectType: A GUID that identifies the type of child object that can inherit the ACE.
DAceSIDofTrustee: The SID of a trustee.

* Depending on the bitmask for the flag, the object type fields may or may not be in use.


Usage
The gui is quite intuitive. An $SDS file is mandatory. Supplying also $SII as input will speed up the processing due to the format of $SDS which contains 2 sets of all descriptors. There's an option to specify output directory.
It is possible to specify the default output variable separator, as well as the ACE separator which must be different than the other one (see explanation above for why there will be several ACE's).

Command line use
If no parameters are supplied, the GUI will by default launch. Valid switches are:

Switches:
/SDSFile:
Target $SDS file. Mandatory.
/SIIFile:
Target $SII file. Optional.
/OutputPath:
The output path to write all output to. Optional. Defaults to program directory.
/Separator:
The separator to use in the csv. Default is |
/AceSeparator:
The separator to distinguish ace's in the csv. Default is :

Examples:
Secure2Csv.exe /SDSFile:c:\temp\$Secure[ADS_$SDS] /OutputPath:c:\temp
Secure2Csv.exe /SDSFile:c:\temp\$Secure[ADS_$SDS] /SIIFile:c:\temp\$Secure_9_$INDEX_ALLOCATION_$SII.bin /OutputPath:c:\temp
Secure2Csv.exe /SDSFile:c:\temp\$Secure[ADS_$SDS] /OutputPath:c:\temp /Separator:% /AceSeparator:!


Slack data
There are various location in the $SDS file where slack data can be found. For this tool to extract slack, the $SII is needed on input along with $SDS. The slack is extracted to 3 different files, those ending with _sds_slack1.bin, _sds_slack2.bin and _sds_slack3.bin.

Slack1 is the data between entries found by using the valid and defined entry offsets and sizes.
Slack2 is the data found within an entry where the defined entry size is larger than what is actually used.
Slack3 is the data found beyond the last valid entry, aligned to sector size.

Slack1 and slack2 are smaller chunks merged together, whereas slack3 is more suitable for traditional carving due to offsets from the FS being preserved.


Note
The file $Secure[ADS_$SDS] and $Secure_9_$INDEX_ALLOCATION_$SII.bin are the two of default output when using RawCopy (https://github.com/jschicht/RawCopy) to extract mft ref 9 with a command such as "rawcopy.exe c:9 c:\temp -AllAttr"
ExtractAllAttributes (https://github.com/jschicht/ExtractAllAttributes) can also be used to extract mft ref 9, but will produce slightly different filenames in the output.

