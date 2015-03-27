<cfsetting enablecfoutputonly="true">
<!--- @@viewstack: data --->
<!--- @@mimetype: json --->

<cfset stResult = {
	"errors" : [],
	"message" : "",
	"html" : ""
} />

<cftry>

	<cfset stResult["qResult"] = application.fc.lib.cloudsearch.resolveIndexFieldDifferences() />
	<cfset stResult["message"] = "All updates have been applied" />

	<cfsavecontent variable="stResult.html"><cfoutput>
		<cfloop query="stResult.qResult">
			<tr>
				<td>#stResult.qResult.field#</td>
				<td>#stResult.qResult.type#</td>
				<td>#stResult.qResult.default_value#</td>
				<td>#yesNoFormat(stResult.qResult.return)#</td>
				<td>#yesNoFormat(stResult.qResult.search)#</td>
				<td>#yesNoFormat(stResult.qResult.facet)#</td>
				<td>#yesNoFormat(stResult.qResult.sort)#</td>
				<td>#yesNoFormat(stResult.qResult.highlight)#</td>
				<td>#stResult.qResult.analysis_scheme#</td>
				<td>wait for update</td>
				<td><a class="cloudsearch-field-action" href="#application.fapi.getLink(type='configCloudSearch',view='webtopAjaxApply',urlParameters='field=#qDiffIndexFields.field#')#">refresh</a></td>
			</tr>
		</cfloop>
	</cfoutput></cfsavecontent>

	<cfcatch>
		<cfset stError = application.fc.lib.error.normalizeError(cfcatch) />
		<cfset application.fc.lib.error.logData(stError) />
		<cfset arrayappend(stResult.errors, stError) />
	</cfcatch>

</cftry>

<cfoutput>#serializeJSON(stResult)#</cfoutput>

<cfsetting enablecfoutputonly="false">