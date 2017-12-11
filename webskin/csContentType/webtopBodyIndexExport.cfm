<!--- 
/webtop/index.cfm?typename=csContentType&view=webtopPageModal&bodyView=webtopBodyIndexExport
 --->
<cfsetting enablecfoutputonly="true" requesttimeout="10000">
	

	<cfparam name="FORM.formAction" default="">
	<cfparam name="FORM.CONTENTTYPEs" default="">
	<cfparam name="FORM.jsonContentTypes" default="[]">
	

	<cftry>

		<cfset aContentTypes = []>
		<cfset qTypes = application.fapi.getContentObjects(typename="csContentType",lProperties="objectid,contentType,builtToDate",orderby="builtToDate asc") />

		<cfoutput>
			<h1>CloudSearch - Content Type Index Export</h1>
			<form method="post">
				<cfloop query="qTypes">
				<label><input type="checkbox" name="CONTENTTYPEs" value="#qTypes.CONTENTTYPE#"> #qTypes.CONTENTTYPE#</label>
				</cfloop>
				<input type="submit" value="Export" name="formAction">
			</form>
		</cfoutput>

		<cfif FORM.formAction == 'Export'>
			
			<cfloop query="qTypes">
				<cfset stContentType = application.fapi.getContentObject(qTypes.objectid,"csContentType") />
				
				<cfif listFindNoCase(FORM.CONTENTTYPEs, stContentType.CONTENTTYPE) != 0>

					<!--- timestamp --->
					<cfset stContentType.DATETIMELASTUPDATED = DateTimeFormat(stContentType.DATETIMELASTUPDATED, 'yyyy-mm-dd HH:NN:SS')>
					<cfset stContentType.BUILTTODATE         = DateTimeFormat(stContentType.BUILTTODATE, 'yyyy-mm-dd HH:NN:SS')>
					<cfset stContentType.DATETIMECREATED     = DateTimeFormat(stContentType.DATETIMECREATED, 'yyyy-mm-dd HH:NN:SS')>
					
					<cfset aContentTypes.append(stContentType)>
				</cfif>
			</cfloop>
		</cfif>

		<cfoutput>
 			<textarea name="jsonContentTypes" style="height:450px; width:600px";>#formatJson(serializeJSON(aContentTypes))#</textarea><br />
		</cfoutput>

		<cfcatch>
			<cfdump var="#cfcatch#" label="cfcatch" abort="true">
		</cfcatch>
	</cftry>

<cfscript>
// formatJson() :: formats and indents JSON string
function formatJson(val) {
	var retval = '';
	var str = val;
    var pos = 0;
    var strLen = str.len();
	var indentStr = chr(9);
    var newLine = chr(13);
	var char = '';

	for (var i=0; i<strLen; i++) {
		char = str.substring(i,i+1);
		
		if (char == '}' || char == ']') {
			retval = retval & newLine;
			pos = pos - 1;
			
			for (var j=0; j<pos; j++) {
				retval = retval & indentStr;
			}
		}
		
		retval = retval & char;	
		
		if (char == '{' || char == '[' || char == ',') {
			retval = retval & newLine;
			
			if (char == '{' || char == '[') {
				pos = pos + 1;
			}
			
			for (var k=0; k<pos; k++) {
				retval = retval & indentStr;
			}
		}
	}
	
	return retval;
}
</cfscript>
	
<cfsetting enablecfoutputonly="false">
