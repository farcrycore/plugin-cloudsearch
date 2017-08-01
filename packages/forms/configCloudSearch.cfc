<cfcomponent extends="farcry.core.packages.forms.forms" key="cloudsearch" displayname="CloudSearch" hint="AWS CloudSearch settings">

	<cfproperty name="domain" type="string" required="false"
		ftSeq="1" ftWizardStep="" ftFieldset="AWS" ftLabel="Domain Name">

	<cfproperty name="region" type="string" required="false"
		ftSeq="2" ftWizardStep="" ftFieldset="AWS" ftLabel="Region">

	<cfproperty name="accessID" type="string" required="false"
		ftSeq="3" ftWizardStep="" ftFieldset="AWS" ftLabel="Access ID">

	<cfproperty name="accessSecret" type="string" required="false"
		ftSeq="4" ftWizardStep="" ftFieldset="AWS" ftLabel="Access Secret">


	<cfproperty name="batchSize" type="integer" required="false" ftDefault="-1"
		ftSeq="11" ftWizardStep="" ftFieldset="Scheduled Task" ftLabel="Batch Size"
		ftHint="Number of documents to update in a single batch. Default (-1) is to update up to 5mb of data at a time, as recommended by AWS.">

	<cfproperty name="bSelfQueuing" type="boolean" required="false" ftDefault="true"
		ftSeq="12" ftWizardStep="" ftFieldset="Scheduled Task" ftLabel="Self Queuing"
		ftHint="Disable if you want to set an interval and end date on the scheduled task. By default it will queue itself as long as there are more records to update in the index, then stop.">


	<cfproperty name="redisHost" type="string" default="" ftDefault=""
				ftSeq="21" ftFieldset="Redis" ftLabel="Host"
				ftHint="The Redis server hostname" />

	<cfproperty name="redisPort" type="string" default="6379" ftDefault="6379"
				ftSeq="22" ftFieldset="Redis" ftLabel="Port"
				ftHint="The Redis server port" />

	<cfproperty name="redisLogSize" type="numeric" default="1000" ftDefault="1000"
				ftSeq="23" ftFieldset="Redis" ftLabel="Log Size"
				ftHint="The number of recent logs to keep" />

	<cffunction name="getSubsets" access="public" output="false" returntype="query">
		<cfset var qResult = querynew("value,label,order","varchar,varchar,integer") />
		<cfset var qContentTypes = application.fc.lib.cloudsearch.getAllContentTypes()>
		<cfset var k = "" />
		
		<cfset queryaddrow(qResult) />
		<cfset querysetcell(qResult,"value","") />
		<cfset querysetcell(qResult,"label","All") />
		<cfset querysetcell(qResult,"order",0) />
		
		
		
	<cfloop query="#qContentTypes#">
			<cfif application.stCOAPI[qContentTypes.contentType].class eq "type" and structkeyexists(application.stCOAPI[qContentTypes.contentType],"displayname") and (not structkeyexists(application.stCOAPI[qContentTypes.contentType],"bSystem") or not application.stCOAPI[qContentTypes.contentType].bSystem)>
				<cfset queryaddrow(qResult) />
				<cfset querysetcell(qResult,"value",qContentTypes.contentType) />
				<cfset querysetcell(qResult,"label","#application.stCOAPI[qContentTypes.contentType].displayname# (#qContentTypes.contentType#)") />
				<cfset querysetcell(qResult,"order",1) />
			</cfif>
		</cfloop>
		
		<cfquery dbtype="query" name="qResult">select * from qResult order by [order],[label]</cfquery>
		
		
		<cfreturn qResult />
	</cffunction>
</cfcomponent>