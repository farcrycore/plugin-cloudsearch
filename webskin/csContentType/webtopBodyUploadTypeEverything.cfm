<!--- 
http://yaffa-env-adnews.192.168.99.101.nip.io
http://admin.yaffa-env-dsp.192.168.99.100.nip.io
/webtop/index.cfm?typename=csContentType&view=webtopPageModal&bodyView=webtopBodyUploadTypeEverything&CONTENTTYPE=dspArticle
 --->
<cfsetting enablecfoutputonly="true" requesttimeout="10000">

	

	<cfparam name="URL.skip"        default="">
	<cfparam name="URL.maxRows"     default="100">
	<cfparam name="URL.CONTENTTYPE" default="dspArticle">
	<cfparam name="URL.start"       default="true">
	
	<cfset requestSize = "5000000" />
	
	<cfoutput><h1>Index all '#URL.CONTENTTYPE#' records</h1></cfoutput>
		
	<cfparam name="APPLICATION.webtopBodyUploadTypeEverything" default="#StructNew()#">
	
	<cftry>
		
		<cfset strOut = createObject("java","java.lang.StringBuffer").init() />
		<cfset oContent = application.fapi.getContentType(typename=URL.CONTENTTYPE) />
		<cfset count = 0 />
		
		<cfif URL.start>
			<cfset APPLICATION.webtopBodyUploadTypeEverything[URL.CONTENTTYPE] = ValueList(application.fapi.getContentObjects(typename="#URL.CONTENTTYPE#",lProperties="objectid",orderby="DATETIMECREATED desc").objectID) />
		</cfif>
		
		<cfset recordCount = ListLen(APPLICATION.webtopBodyUploadTypeEverything[URL.CONTENTTYPE])>
		<cfset more =  recordCount GT 0>
	
		<cfif more>
			<cfif recordCount GT URL.maxRows>
				<cfset recordCount = URL.maxRows>
			</cfif>
			
			<cfset contentIDs = "">
			<cfloop from="1" to="#recordCount#" index="c">
				<cfset contentID = ListGetAt(APPLICATION.webtopBodyUploadTypeEverything[URL.CONTENTTYPE], c)>
				<cfset contentIDs =  ListAppend(contentIDs, contentID)>
			</cfloop>
			
			<cfset qContent = getRecordsToUpdate(URL.CONTENTTYPE, contentIDs)>
			
			<cfset strOut.append("[") />
			<cfloop query="qContent">
				<!--- remove from application scope --->
				<cfset APPLICATION.webtopBodyUploadTypeEverything[URL.CONTENTTYPE] = ListDeleteAt(APPLICATION.webtopBodyUploadTypeEverything[URL.CONTENTTYPE], 1)>

				<cfif qContent.operation eq "updated" and (not structKeyExists(oContent, "isIndexable") or oContent.isIndexable(stObject=stObject))>
					<cfset stObject = oContent.getData(objectid=qContent.objectid) />
					<cfset stContent = getCloudsearchDocument(stObject=stObject) />
					
					<cfset strOut.append('{"type":"add","id":"') />
					<cfset strOut.append(qContent.objectid) />
					<cfset strOut.append('","fields":') />
					<cfset strOut.append(serializeJSON(stContent)) />
					<cfset strOut.append('}') />
				<cfelseif qContent.operation eq "deleted">
					<cfset strOut.append('{"type":"delete","id":"') />
					<cfset strOut.append(qContent.objectid) />
					<cfset strOut.append('"}') />
				</cfif>
	
				<cfif strOut.length() * ((qContent.currentrow+1) / qContent.currentrow) gt requestSize or qContent.currentrow eq qContent.recordcount>
					<cfset count = qContent.currentrow />
					<cfbreak />
				<cfelse>
					<cfset strOut.append(",") />
				</cfif>

			</cfloop>
			<cfset strOut.append("]") />
					
			<cfif count>
				<cfset stResult = application.fc.lib.cloudsearch.uploadDocuments(documents=strOut.toString()) />
				<cfdump var="#stResult#" label="Status" expand="Yes" abort="No"  />
				<cflog file="cloudsearch" text="webtopBodyUploadTypeEverything(#URL.contentType#): Updated #count# record/s" />
			</cfif>
	
			<cfset recordCount = ListLen(APPLICATION.webtopBodyUploadTypeEverything[URL.CONTENTTYPE])>
			<cfset more =  recordCount GT 0>
			<cfif more>
				<cfoutput>
					<h4>#ListLen(APPLICATION.webtopBodyUploadTypeEverything[URL.CONTENTTYPE])# more to process ...</h4><p>#Now()#</p>

				     <script type="text/javascript">
			         <!--
			           window.location="/webtop/index.cfm?typename=csContentType&view=webtopPageModal&bodyView=webtopBodyUploadTypeEverything&CONTENTTYPE=#URL.contentType#&start=false&maxRows=#URL.maxRows#"; 
			         //-->
			      </script>
				</cfoutput>
				
			<cfelse>
				<cfoutput><h4>All Done</h4></cfoutput>
			</cfif>
	
		<cfelse>
			<cfoutput><p>nothing to process</p></cfoutput>
		</cfif>
		<cfcatch>
			<cfdump var="#recordCount#" label="AJM recordCount" expand="Yes" abort="No"  />
			<cfdump var="#ListLen(APPLICATION.webtopBodyUploadTypeEverything[URL.CONTENTTYPE])#" label="AJM ListLen(APPLICATION.webtopBodyUploadTypeEverything[URL.CONTENTTYPE])" expand="Yes" abort="No"  />
			<cfdump var="#cfcatch#" label="cfcatch" abort="true">
		</cfcatch>
	</cftry>
	

	
<cfsetting enablecfoutputonly="false">

	<cffunction name="getRecordsToUpdate" access="public" output="false" returntype="query">
		<cfargument name="typename" type="string" required="true" />
		<cfargument name="objectids" type="string" required="true" />
		<cfargument name="maxRows" type="numeric" required="false" default="-1" />

		<cfset var qContent = "" />

		<cfquery datasource="#application.dsn#" name="qContent" maxrows="#arguments.maxrows#">
			select 		objectid, datetimeLastUpdated, '#arguments.typename#' as typename, 'updated' as operation
			from 		#application.dbowner##arguments.typename#
			
				where 	objectid in (<cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.objectids#" list="true">)
			

			UNION

			select 		archiveID as objectid, datetimeCreated as datetimeLastUpdated, '#arguments.typename#' as typename, 'deleted' as operation
			from 		#application.dbowner#dmArchive
			where 		objectTypename = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.typename#" />
						and bDeleted = <cfqueryparam cfsqltype="cf_sql_bit" value="1" />
			and 	objectid in (<cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.objectids#" list="true">)

			order by 	datetimeLastUpdated asc
		</cfquery>
		<cfreturn qContent />
	</cffunction>
	