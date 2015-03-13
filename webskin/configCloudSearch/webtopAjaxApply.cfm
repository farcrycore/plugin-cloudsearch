<cfsetting enablecfoutputonly="true">
<!--- @@viewstack: data --->
<!--- @@mimetype: json --->

<cfset stResult = {
	"errors" : [],
	"message" : "",
	"html" : ""
} />

<cftry>

	<cfparam name="url.field" />

	<cfset qActions = application.fc.lib.cloudsearch.diffIndexFields(fields=url.field) />

	<cfif qActions.recordcount eq 0>
		<cfset qActions = application.fc.lib.cloudsearch.getIndexFields(fields=url.field) />
		<cfset stResult["html"] = "<tr><td>#qActions.field#</td><td>#qActions.type#</td><td>#qActions.default_value#</td><td>#yesNoFormat(qActions.return)#</td><td>#yesNoFormat(qActions.search)#</td><td>#yesNoFormat(qActions.facet)#</td><td>#yesNoFormat(qActions.sort)#</td><td>#yesNoFormat(qActions.highlight)#</td><td>#qActions.analysis_scheme#</td><td>done</td><td></td></tr>" />
	<cfelseif qActions.action eq "add">
		<cfset stResult["result"] = application.fc.lib.cloudsearch.updateIndexField(
			field = url.field, 
			type = qActions.type, 
			default_value = qActions.default_value, 
			return = qActions.return, 
			search = qActions.search, 
			facet = qActions.facet, 
			sort = qActions.sort, 
			highlight = qActions.highlight, 
			analysis_scheme = qActions.analysis_scheme
		) />
		<cfset stResult["message"] = "Index field addition is being processed by CloudSearch" />
		<cfset querySetCell(qActions,"action","wait for update") />
	<cfelseif qActions.action eq "update">
		<cfset stResult["result"] = application.fc.lib.cloudsearch.updateIndexField(
			field = url.field, 
			type = qActions.type, 
			default_value = qActions.default_value, 
			return = qActions.return, 
			search = qActions.search, 
			facet = qActions.facet, 
			sort = qActions.sort, 
			highlight = qActions.highlight, 
			analysis_scheme = qActions.analysis_scheme
		) />
		<cfset stResult["message"] = "Index field update is being processed by CloudSearch" />
		<cfset querySetCell(qActions,"action","wait for update") />
	<cfelseif qActions.action eq "delete">
		<cfset stResult["result"] = application.fc.lib.cloudsearch.deleteIndexField(field=url.field) />
		<cfset stResult["message"] = "Index field deletion is being processed by CloudSearch" />
		<cfset querySetCell(qActions,"action","wait for delete") />
	</cfif>

	<cfif not len(stResult.html)>
		<cfset stResult["html"] = "<tr><td>#qActions.field#</td><td>#qActions.type#</td><td>#qActions.default_value#</td><td>#yesNoFormat(qActions.return)#</td><td>#yesNoFormat(qActions.search)#</td><td>#yesNoFormat(qActions.facet)#</td><td>#yesNoFormat(qActions.sort)#</td><td>#yesNoFormat(qActions.highlight)#</td><td>#qActions.analysis_scheme#</td><td>#qActions.action#</td><td><a class='cloudsearch-field-action' href='#application.fapi.getLink(type='configCloudSearch',view='webtopAjaxApply',urlParameters='field=#url.field#')#'>refresh</a></td></tr>" />
	</cfif>

	<cfcatch>
		<cfset stError = application.fc.lib.error.normalizeError(cfcatch) />
		<cfset application.fc.lib.error.logData(stError) />
		<cfset arrayappend(stResult.errors, stError) />
	</cfcatch>

</cftry>

<cfoutput>#serializeJSON(stResult)#</cfoutput>

<cfsetting enablecfoutputonly="false">