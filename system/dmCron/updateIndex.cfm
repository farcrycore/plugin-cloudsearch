<cfsetting enablecfoutputonly="true" requesttimeout="10000">
<!--- @@displayname: Update index --->

<cflock name="update-cloudsearch-index" type="exclusive" timeout="1" throwontimeout="false">
	<cfparam name="url.reschedule" default="#application.fapi.getConfig("cloudsearch","bSelfQueuing")#" />
	<cfparam name="url.atatime" default="#application.fapi.getConfig("cloudsearch","batchSize")#" />
	
	<cfset count = 0 />

	<cfset csContentType = application.fapi.getContentType(typename="csContentType") />
	<cfset qTypes = application.fapi.getContentObjects(typename="csContentType",lProperties="objectid,contentType,builtToDate",orderby="builtToDate asc") />

	<cftry>
		<cfloop query="qTypes">
			<cfset stResult = csContentType.bulkImportIntoCloudSearch(objectid=qTypes.objectid, maxRows=url.atatime) />

			<cfif stResult.count>
				<cfset count = stResult.count />
				<cfoutput>Updated #stResult.count# #application.stCOAPI[qTypes.contentType].displayname# records in index<br></cfoutput>
				<cfbreak />
			</cfif>
		</cfloop>

		<cfcatch>
			<cfset stError = application.fc.lib.error.normalizeError(cfcatch) />
			<cfset application.fc.lib.error.logData(stError) />
			<cfoutput>Error: #stError.message#<br></cfoutput>
		</cfcatch>
	</cftry>

	<cfif not count>
		<cfoutput>No records updated in index<br></cfoutput>
	</cfif>

	<cfif url.reschedule and count>
		<cfset taskTime = dateadd('n',1,now()) />

		<cfschedule action="update"
			task="#application.applicationName#: Update index"
			url="http://#application.fapi.getConfig('environment','canonicalDomain')##application.fapi.fixURL()#"
			operation="HTTPRequest"
			startdate = "#dateFormat(taskTime,'dd/mmm/yyyy')#"
			starttime = "#timeFormat(taskTime,'hh:mm tt')#"
			interval="Once"
			paused="false"
		/>

		<cfoutput>Rescheduled task<br></cfoutput>
	</cfif>
</cflock>

<cfsetting enablecfoutputonly="false">