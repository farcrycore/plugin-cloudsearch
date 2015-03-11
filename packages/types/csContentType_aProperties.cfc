<cfcomponent output="false" extends="farcry.core.packages.types.types" displayname="CloudSearch Indexed Property" hint="Manages indexed properties for a content type" bFriendly="false" bObjectBroker="false">

	<cfproperty name="fieldName" type="string" required="true" 
		ftSeq="1" ftFieldset="Indexed Property" ftLabel="Field"
		ftType="string" 
		bLabel="true" ftValidation="required"
		ftHint="The name of the field being indexed.">

	<cfproperty name="fieldType" type="string" required="true" 
		ftSeq="2" ftFieldset="Indexed Property" ftLabel="Type"
		ftType="list" ftListData="getFieldTypes"
		bLabel="false" ftValidation="required"
		ftHint="The CloudSearch field type">

	<cfproperty name="weight" type="numeric" required="true" 
		ftSeq="3" ftFieldset="Indexed Property" ftLabel="Weight"
		ftType="integer" default="1" ftDefault="1"
		ftValidation="required" />

	<cfproperty name="bIndex" type="boolean" required="true" 
		ftSeq="4" ftFieldset="Indexed Property" ftLabel="Index" />

	<cfproperty name="bSort" type="boolean" required="true"
		ftSeq="5" ftFieldset="Indexed Property" ftLabel="Sortable" />

	<cfproperty name="bFacet" type="boolean" required="true"
		ftSeq="6" ftFieldset="Indexed Property" ftLabel="Facet" />


	<cffunction name="getFieldTypes" access="public" output="false" returntype="query">
		<cfset var q = application.fc.lib.cloudfront.getFieldTypes() />

		<cfquery dbtype="query" name="q">
			select code as value, label as name order by label
		</cfquery>

		<cfreturn q />
	</cffunction>

</cfcomponent>