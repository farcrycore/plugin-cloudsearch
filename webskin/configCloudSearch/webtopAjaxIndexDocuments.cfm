<cfsetting enablecfoutputonly="true">
<!--- @@viewstack: data --->
<!--- @@mimetype: json --->

<cfset stResult = {
	"errors" : [],
	"message" : "",
	"html" : ""
} />

<cftry>

	<cfparam name="url.domain" />

	<cfset stResult["fields"] = application.fc.lib.cloudsearch.indexDocuments(domain=url.domain) />

	<cfsavecontent variable="stResult.html"><cfoutput>
		Indexing fields:
		<ul>
			<cfloop array="#stResult.fields#" index="field">
				<li>#field#</li>
			</cfloop>
		</ul>
	</cfoutput></cfsavecontent>

	<cfcatch>
		<cfset stError = application.fc.lib.error.normalizeError(cfcatch) />
		<cfset application.fc.lib.error.logData(stError) />
		<cfset arrayappend(stResult.errors, stError) />
	</cfcatch>

</cftry>

<cfoutput>#serializeJSON(stResult)#</cfoutput>

<cfsetting enablecfoutputonly="false">