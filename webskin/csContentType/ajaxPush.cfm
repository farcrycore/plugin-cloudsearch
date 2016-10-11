<cfsetting enablecfoutputonly="true">
<!--- @@viewbinding: type --->
<!--- @@fuAlias: push --->

<cftry>
	<cfset st = application.fc.lib.cloudsearch.getTypeIndexFields(url.pushtype) />

	<!--- update index --->
	<cfif not structIsEmpty(st)>
		<cfset stProps = application.fapi.getContentObject(typename=url.pushtype, objectid=url.pushid) />
		<cfset importIntoCloudSearch(stObject=stProps, operation="updated") />
		<cfset application.fapi.stream(content={ "success":true, "message":"Pushed document to CloudSearch" }, type="json") />
	<cfelse>
		<cfset application.fapi.stream(content={ "success":true, "message":"Content type is not indexed" }, type="json") />
	</cfif>

	<cfcatch>
		<cfset stErr = application.fc.lib.error.normalizeError(cfcatch) />
		<cfset application.fc.lib.error.logData(stErr) />
		<cfif session.mode.debug>
			<cfset application.fapi.stream(content={ "success":false, "message":stErr.message, "detail":stErr }, type="json") />
		<cfelse>
			<cfset application.fapi.stream(content={ "success":false, "message":stErr.message }, type="json") />
		</cfif>
	</cfcatch>
</cftry>

<cfsetting enablecfoutputonly="false">