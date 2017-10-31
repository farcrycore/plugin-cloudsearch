<!--- 
http://yaffa-env-adnews.192.168.99.101.nip.io/webtop/index.cfm?typename=csContentType&view=webtopPageModal&bodyView=webtopBodyUploadAuto
 --->
<cfsetting enablecfoutputonly="true" requesttimeout="10000">

	<cfoutput><h1>AWS CloudSearch :: bulkImportIntoCloudSearch()</h1></cfoutput>

	<cfparam name="URL.skip"    default="">
	<cfparam name="URL.maxRows" default="50">
		
	<cfset qTypes = application.fapi.getContentObjects(typename="csContentType",lProperties="objectid,contentType,builtToDate",orderby="builtToDate asc") />
	<!--- <cfdump var="#qTypes#" label="qTypes #qTypes.recordcount#" expand="false" format="simple"> --->
	
	<cftry>
		<cfset more = false>
	
		<cfloop query="qTypes">
			<cfset stContentType = application.fapi.getContentObject(qTypes.objectid,"csContentType") />
			
			<cfif ListLen(URL.skip) == 0 OR ListFind(URL.skip, stContentType.CONTENTTYPE) == 0>
				<cfset stResult = bulkImportIntoCloudSearch(objectid=qTypes.objectid, maxRows=URL.maxRows) />
				
				<cfoutput><p>#stResult.typename#: #stResult.count#</p></cfoutput>
				<!--- <cfdump var="#stResult#" label=" #qTypes.contentType# 100"> --->
				<cfif stResult.count GT 0>
					<cfset more = true>
				<cfelse>
					<cfset URL.skip = ListAppend(URL.skip, stContentType.CONTENTTYPE)>
				</cfif>
			</cfif>
		</cfloop>

		<cfcatch>
			<cfdump var="#cfcatch#" label="cfcatch" abort="true">
		</cfcatch>
	</cftry>
	
	<cftry>
		<cfif more>
			<cfoutput>
				<cfoutput><h4>More to process ...</h4><p>#Now()#</p></cfoutput>
				
			
				
			     <script type="text/javascript">
		         <!--
		           window.location="/webtop/index.cfm?typename=csContentType&view=webtopPageModal&bodyView=webtopBodyUploadAuto&skip=#URL.skip#&maxRows=#URL.maxRows#"; 
		         //-->
		      </script>
			</cfoutput>
			<!--- <cflocation url="#CGI.request_url#" addtoken="false"> --->
		<cfelse>
			<cfoutput><h4>All Done</h4></cfoutput>
		</cfif>
		<cfcatch>
			<cfdump var="#cgi#" label="cgi" format="simple">
			<cfdump var="#cfcatch#" label="cfcatch" abort="true" format="simple">
		</cfcatch>
	</cftry>



<cfsetting enablecfoutputonly="false">