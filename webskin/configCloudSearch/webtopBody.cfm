<cfsetting enablecfoutputonly="true">

<cfoutput>
	<h1>CloudSearch Status</h1>

	<h2>Configuration</h2>
	<table class="table table-striped">
		<cfloop list="domain,region,accessID,accessSecret" index="thisfield">
			<tr>
				<th>#application.stCOAPI.configCloudSearch.stProps[thisfield].metadata.ftLabel#</th>
				<td>
					<cfif len(application.fapi.getConfig("cloudsearch",thisfield,""))>
						<span class="text-green">Ok</span>
					<cfelse>
						<span class="text-red">Not ok</span>
					</cfif>
				</td>
			</tr>
		</cfloop>
	</table>
</cfoutput>

<cfif application.fc.lib.cloudsearch.isEnabled()>
	<cfset qDomains = application.fc.lib.cloudsearch.getDomains() />

	<cfoutput>
		<h2>Search Domains Found</h2>
		<table class="table table-striped">
			<thead>
				<th>Domain</th>
				<th>Created</th>
				<th>Processing Index</th>
				<th>Requires Index</th>
				<th>Deleted</th>
				<th>Instance Count</th>
				<th>Instance Type</th>
			</thead>
			<tbody>
				<cfloop query="qDomains">
					<tr>
						<td>#qDomains.domain#</td>
						<td>#yesnoformat(qDomains.created)#</td>
						<td>#yesnoformat(qDomains.processing)#</td>
						<td>#yesnoformat(qDomains.requires_index)#</td>
						<td>#yesnoformat(qDomains.deleted)#</td>
						<td>#qDomains.instance_count#</td>
						<td>#qDomains.instance_type#</td>
					</tr>
				</cfloop>
			</tbody>
		</table>
	</cfoutput>
</cfif>

<cfsetting enablecfoutputonly="false">