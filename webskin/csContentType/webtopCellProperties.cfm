<cfsetting enablecfoutputonly="true">

<cfset lIndex = "" />
<cfset lSort = "" />
<cfset lFacet = "" />

<cfloop array="#stObj.aProperties#" index="stProp">
	<cfif stProp.bIndex>
		<cfset lIndex = listAppend(lIndex,stProp.fieldname) />
	</cfif>
	<cfif stProp.bSort>
		<cfset lSort = listAppend(lSort,stProp.fieldname) />
	</cfif>
	<cfif stProp.bFacet>
		<cfset lFacet = listAppend(lFacet,stProp.fieldname) />
	</cfif>
</cfloop>

<cfoutput>
	<cfif len(lIndex)>
		<strong>Index</strong>: #replace(lIndex,",",", ","ALL")#<br>
	</cfif>
	<cfif len(lSort)>
		<strong>Sortable</strong>: #replace(lSort,",",", ","ALL")#<br>
	</cfif>
	<cfif len(lFacet)>
		<strong>Facets</strong>: #replace(lFacet,",",", ","ALL")#<br>
	</cfif>
</cfoutput>

<cfsetting enablecfoutputonly="false">