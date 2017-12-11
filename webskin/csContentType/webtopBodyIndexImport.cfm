<!--- 
/webtop/index.cfm?typename=csContentType&view=webtopPageModal&bodyView=webtopBodyIndexImport
 --->
<cfsetting enablecfoutputonly="true" requesttimeout="10000">

	

	<cfparam name="FORM.formAction" default="">
	<cfparam name="FORM.CONTENTTYPEs" default="">
	<cfparam name="FORM.jsonContentTypes" default="[]">
	
	<cftry>
		<cfoutput><h1>CloudSearch - Content Type Index Import</h1></cfoutput>

		<cfif FORM.formAction == 'Import'>
		 	<cfif IsJSON(FORM.jsonContentTypes)>
				<cfset aContentTypes = deserializeJSON(FORM.jsonContentTypes)>
			
				<cfif IsArray(aContentTypes)>
					<cfloop array="#aContentTypes#" item="stContentType">
						
						<!--- look for record --->
						<cfset qTypes = application.fapi.getContentObjects(typename="csContentType",label_eq="#stContentType.label#") />
						<cfif qTypes.RecordCount EQ 1>
							
							<cfset stContentTypeOrig = application.fapi.getContentObject(qTypes.objectid,"csContentType") />	
							<cfset stContentTypeOrig.aProperties = stContentType.aProperties>
							<cfloop array="#stContentTypeOrig.aProperties#" index="i" item="stIndex">
								<cfset stContentTypeOrig.aProperties[i].PARENTID = stContentTypeOrig.objectid>
							</cfloop>
							<cfset stContentType = stContentTypeOrig>
						</cfif>

						
						<cfoutput>#stContentType.CONTENTTYPE# ... </cfoutput>
						<cfset stContentType.label = stContentType.CONTENTTYPE>
		
						<!--- timestamp --->
						<cfset stContentType.DATETIMELASTUPDATED = ParseDateTime(stContentType.DATETIMELASTUPDATED)>
						<cfset stContentType.DATETIMECREATED     = ParseDateTime(stContentType.DATETIMECREATED)>
						
						<cfif stContentType.BUILTTODATE != ''><cfset stContentType.BUILTTODATE         = ParseDateTime(stContentType.BUILTTODATE)></cfif>
						<!--- <cfset stContentType.BUILTTODATE         = ''> --->

						
						<cfset application.fapi.setData(stProperties=stContentType) />
		
						<cfoutput>imported</cfoutput>
					</cfloop>
				</cfif>
			</cfif>
		</cfif>

		<cfoutput>
			<form method="post">
				<textarea name="jsonContentTypes" style="height:450px; width:600px";></textarea><br />
				<input type="submit" value="Import" name="formAction">
			</form>
		</cfoutput>

		<cfcatch>
			<cfdump var="#cfcatch#" label="cfcatch" abort="true">
		</cfcatch>
	</cftry>
	
<cfsetting enablecfoutputonly="false">
