<cfsetting enablecfoutputonly="true" />
<!--- @@displayname: CloudSearch --->

<cfset stResult = application.fc.lib.cloudsearch.search(typename=stObj.typename,conditions=[{ "property"="objectid", "term"=stObj.objectid }]) />

<cfoutput><pre>#stResult.rawQuery#</pre></cfoutput>
<cfdump var="#stResult.items#">

<cfsetting enablecfoutputonly="false" />