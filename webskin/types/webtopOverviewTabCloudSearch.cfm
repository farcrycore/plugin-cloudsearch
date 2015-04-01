<cfsetting enablecfoutputonly="true" />
<!--- @@displayname: CloudSearch --->

<cfset stResult = application.fc.lib.cloudsearch.search(typename=stObj.typename,conditions=[{ "property"="objectid", "term"=stObj.objectid }]) />
<cfoutput>
	<h2>Object ID Search</h2>
	<pre>#stResult.rawQuery#</pre>
	<p>Records found: #stResult.items.recordcount#</p>
</cfoutput>

<cfset stResult = application.fc.lib.cloudsearch.search(conditions=[{ "text"=stObj.label }]) />
<cfoutput>
	<h2>Label Search</h2>
	<pre>#stResult.rawQuery#</pre>
	<table class="table table-striped">
		<thead>
			<tr>
				<th>Object ID</th>
				<th>Typename</th>
				<th>Label</th>
				<th></th>
			</tr>
		</thead>
		<tbody>
			<cfloop query="stResult.items">
				<cfset stObject = application.fapi.getContentObject(typename=stResult.items.typename,objectid=stResult.items.objectid) />

				<tr>
					<td>#stResult.items.objectid#</td>
					<td>#stResult.items.typename#</td>
					<td>#stObject.label#</td>
					<td><a title="#application.stCOAPI[stResult.items.typename].displayname# Overview" onclick="$fc.objectAdminAction('Media Overview', this.href, { onHidden : function(){} }); return false;" href="#application.url.webtop#/edittabOverview.cfm?typename=#stResult.items.typename#&method=edit&ref=iframe&objectid=#stResult.items.objectid#&dialogID=fcModal">Overview</a></td>
				</tr>
			</cfloop>
			<cfif stResult.items.recordcount eq 0>
				<tr>
					<td colspan="2">No items returned</td>
				</tr>
			</cfif>
		</tbody>
	</table>
</cfoutput>

<cfsetting enablecfoutputonly="false" />