<cfcomponent output="false" extends="farcry.core.packages.types.types" displayname="CloudSearch Content Type" hint="Manages content type index information" bFriendly="false" bObjectBroker="false" bSystem="true" bRefObjects="true">
	
	<cfproperty name="contentType" type="nstring" required="true" 
		ftSeq="2" ftFieldset="CloudSearch Content Type" ftLabel="Content Type" 
		ftType="list" ftRenderType="dropdown" 
		ftListData="getContentTypes" ftValidation="required"
		ftHint="The content type being indexed.">

	<cfproperty name="builtToDate" type="date" required="false" 
		ftSeq="9" ftFieldset="CloudSearch Content Type" ftLabel="Built to Date" 
		ftType="datetime"
		ftHint="For system use.  Updated by the system.  Used as a reference date of the last indexed item.  Used for batching when indexing items.  Default is blank (no date).">

	<cfproperty name="aProperties" type="array" 
		ftSeq="11" ftFieldset="CloudSearch Content Type" ftLabel="Properties" 
		ftWatch="contentType"
		arrayProps="fieldName:string;fieldType:string;weight:integer;bIndex:boolean;bSort:boolean;bFacet:boolean"
		ftHint="Notes: <ul><li>a literal is a field that is always used for exact matches - as well as UUIDs and arrays, it is also appropriate to use literal for list and status properties</li><li>array field types can be used for array and list properties, which are converted automatically</li><li>int field types do not handle empty values (i.e. null) - those properties must be a valid integer</ul>">


	<cffunction name="AfterSave" access="public" output="false" returntype="struct" hint="Called from setData and createData and run after the object has been saved.">
		<cfargument name="stProperties" required="yes" type="struct" hint="A structure containing the contents of the properties that were saved to the object.">

		<cfset application.fc.lib.cloudsearch.resolveIndexFieldDifferences() />
		<cfset application.fc.lib.cloudsearch.updateTypeIndexFieldCache(typename=arguments.stProperties.typename) />
		<cfset application.fc.lib.cloudsearch.updateTypeIndexFieldCache() />

		<cfreturn super.aftersave(argumentCollection = arguments) />
	</cffunction>
	
	<cffunction name="onDelete" returntype="void" access="public" output="false" hint="Is called after the object has been removed from the database">
		<cfargument name="typename" type="string" required="true" hint="The type of the object" />
		<cfargument name="stObject" type="struct" required="true" hint="The object" />
		
		<cfset application.fc.lib.cloudsearch.resolveIndexFieldDifferences() />
		<cfset application.fc.lib.cloudsearch.updateTypeIndexFieldCache(typename=arguments.typename) />

		<cfset super.onDelete(argumentCollection = arguments) />
	</cffunction>
	
	<cffunction name="ftValidateContentType" access="public" output="true" returntype="struct" hint="This will return a struct with bSuccess and stError">
		<cfargument name="objectid" required="true" type="string" hint="The objectid of the object that this field is part of.">
		<cfargument name="typename" required="true" type="string" hint="The name of the type that this field is part of.">
		<cfargument name="stFieldPost" required="true" type="struct" hint="The fields that are relevent to this field type.">
		<cfargument name="stMetadata" required="true" type="struct" hint="This is the metadata that is either setup as part of the type.cfc or overridden when calling ft:object by using the stMetadata argument.">
		
		<cfset var stResult = structNew()>		
		<cfset var oField = createObject("component", "farcry.core.packages.formtools.field") />
		<cfset var qDupeCheck = "" />		
		
		<!--- required --->
		<cfif NOT len(stFieldPost.Value)>
			<cfreturn oField.failed(value=arguments.stFieldPost.value, message="This is a required field.") />
		</cfif>
		
		<!--- check for duplicates --->
		<cfset qDupeCheck = application.fapi.getContentObjects(typename="csContentType",contentType_eq=trim(arguments.stFieldPost.value),objectid_neq=arguments.objectid) />
		<cfif qDupeCheck.recordCount gt 0>
			<cfreturn oField.failed(value=arguments.stFieldPost.value, message="There is already a configuration created for this content type.") />
		</cfif>

		<cfreturn oField.passed(value=arguments.stFieldPost.Value) />
	</cffunction>
	
	<cffunction name="getContentTypes" access="public" hint="Get list of all searchable content types." output="false" returntype="query">
		<cfset var listdata = "" />
		<cfset var qListData = queryNew("typename,displayname") />
		<cfset var type = "" />

		<cfloop collection="#application.types#" item="type">
			<cfif not application.stCOAPI[type].bSystem>
				<cfset queryAddRow(qListData) />
				<cfset querySetCell(qListData, "typename", type) />
				<cfset querySetCell(qListData, "displayname", "#application.stcoapi[type].displayname# (#type#)") />
			</cfif>
		</cfloop>
		
		<cfquery dbtype="query" name="qListData">
			SELECT typename as value, displayname as name FROM qListData ORDER BY displayname
		</cfquery>
		
		<cfreturn qListData />
	</cffunction>
	
	<cffunction name="ftEditAProperties" access="public" output="false" returntype="string" hint="This is going to called from ft:object and will always be passed 'typename,stobj,stMetadata,fieldname'.">
		<cfargument name="typename" required="true" type="string" hint="The name of the type that this field is part of.">
		<cfargument name="stObject" required="true" type="struct" hint="The object of the record that this field is part of.">
		<cfargument name="stMetadata" required="true" type="struct" hint="This is the metadata that is either setup as part of the type.cfc or overridden when calling ft:object by using the stMetadata argument.">
		<cfargument name="fieldname" required="true" type="string" hint="This is the name that will be used for the form field. It includes the prefix that will be used by ft:processform.">
		
		<cfset var joinItems = "" />
		<cfset var i = "" />
		<cfset var j = 0 />
		<cfset var returnHTML = "" />
		<cfset var thisobject = "" />
		<cfset var qFields = querynew("empty") />
		<cfset var qTypes = application.fc.lib.cloudsearch.getFieldTypes() />
		<cfset var aCurrent = arguments.stMetadata.value />
		
		<cfif issimplevalue(aCurrent)>
			<cfif len(aCurrent)>
				<cfset aCurrent = deserializeJSON(aCurrent) />
			<cfelse>
				<cfset aCurrent = [] />
			</cfif>
		</cfif>

		<cfif len(arguments.stObject.contentType) and structKeyExists(application.stCOAPI,arguments.stObject.contentType)>
			<cfset qFields = getTypeFields(arguments.stObject.contentType, aCurrent) />
			<cfset updateProperties(arguments.stObject.contentType, aCurrent) />
		</cfif>

		<cfsavecontent variable="returnHTML"><cfoutput>
			<input type="hidden" name="#arguments.fieldname#" value="#application.fc.lib.esapi.encodeForHTMLAttribute(serializeJSON(aCurrent))#" />

			<table class="table">
				<thead>
					<tr>
						<th>Index</th>
						<th>Field</th>
						<th>Type <a target="_blank" href="http://docs.aws.amazon.com/cloudsearch/latest/developerguide/configuring-index-fields.html"><i class="fa fa-question-o"></i></a></th>
						<th>Weight</th>
						<th>Sortable</th>
						<th>Facetable</th>
						<th></th>
					</tr>
				</thead>
				<tbody>
					<cfif not arraylen(aCurrent) or not len(arguments.stObject.contentType) or not structKeyExists(application.stCOAPI,arguments.stObject.contentType)>
						<tr class="warning"><td colspan="6">Please select a valid content type</td></tr>
					</cfif>

					<cfloop from="1" to="#arraylen(aCurrent)#" index="i">
						<cfset thisobject = aCurrent[i] />

						<tr <cfif thisobject.bIndex>class="success"</cfif>>
							<td>
								<input type="checkbox" name="#arguments.fieldname#bIndex#i#" value="1" <cfif thisobject.bIndex>checked</cfif> onchange="$j(this).closest('tr').toggleClass('success');" />
								<input type="hidden" name="#arguments.fieldname#bIndex#i#" value="0" />
							</td>
							<td>
								<input type="hidden" name="#arguments.fieldname#field#i#" value="#thisobject.fieldName#" />
								<cfloop query="qFields">
									<cfif qFields.field eq thisobject.fieldName><span title="#qFields.field#">#qFields.label#<br><small>#application.fapi.getPropertyMetadata(typename=arguments.stObject.contentType, property=qFields.field, md="ftFieldset", default="")#</small></span></cfif>
								</cfloop>
							</td>
							<td>
								<select name="#arguments.fieldname#type#i#" style="width:auto;min-width:0;">
									<cfloop query="qTypes">
										<option value="#qTypes.code#" <cfif qTypes.code eq thisobject.fieldType>selected</cfif>>#qTypes.label#</option>
									</cfloop>
								</select>
							</td>
							<td>
								<select name="#arguments.fieldname#weight#i#" style="width:auto;min-width:0;">
									<cfloop from="1" to="10" index="j">
										<option value="#j#" <cfif j eq thisobject.weight>selected</cfif>>#j#</option>
									</cfloop>
								</select>
							</td>
							<td>
								<input type="checkbox" name="#arguments.fieldname#bSort#i#" value="1" <cfif thisobject.bSort>checked</cfif> />
								<input type="hidden" name="#arguments.fieldname#bSort#i#" value="0" />
							</td>
							<td>
								<input type="checkbox" name="#arguments.fieldname#bFacet#i#" value="1" <cfif thisobject.bFacet>checked</cfif> />
								<input type="hidden" name="#arguments.fieldname#bFacet#i#" value="0" />
							</td>
							<td>
								<a href="##" onclick="$j(this).closest('tr').remove(); return false;"><i class="fa fa-times"></i></a>
							</td>
						</tr>
					</cfloop>
				</tbody>
			</table>
		</cfoutput></cfsavecontent>

		<cfreturn returnHTML />
	</cffunction>

	<cffunction name="ftValidateAProperties" access="public" output="true" returntype="struct" hint="This will return a struct with bSuccess and stError">
		<cfargument name="objectid" required="true" type="string" hint="The objectid of the object that this field is part of.">
		<cfargument name="typename" required="true" type="string" hint="The name of the type that this field is part of.">
		<cfargument name="stFieldPost" required="true" type="struct" hint="The fields that are relevent to this field type.">
		<cfargument name="stMetadata" required="true" type="struct" hint="This is the metadata that is either setup as part of the type.cfc or overridden when calling ft:object by using the stMetadata argument.">
		
		<cfset var aCurrent = deserializeJSON(arguments.stFieldPost.value) />
		<cfset var i = 0 />
		<cfset var aNew = [] />

		<cfloop from="1" to="#arraylen(aCurrent)#" index="i">
			<cfif structKeyExists(arguments.stFieldPost.stSupporting,"field#i#") and listfirst(arguments.stFieldPost.stSupporting["bIndex#i#"]) eq "1">
				<cfset arrayAppend(aNew,{
					"data" = arguments.stFieldPost.stSupporting["field#i#"],
					"fieldName" = arguments.stFieldPost.stSupporting["field#i#"],
					"fieldType" = arguments.stFieldPost.stSupporting["type#i#"],
					"weight" = arguments.stFieldPost.stSupporting["weight#i#"],
					"bIndex" = listfirst(arguments.stFieldPost.stSupporting["bIndex#i#"]),
					"bSort" = listfirst(arguments.stFieldPost.stSupporting["bSort#i#"]),
					"bFacet" = listfirst(arguments.stFieldPost.stSupporting["bFacet#i#"])
				}) />
			</cfif>
		</cfloop>

		<cfreturn application.formtools.field.oFactory.passed(aNew) />
	</cffunction>

	<cffunction name="getTypeFields" access="public" output="false" returntype="query">
		<cfargument name="typename" type="string" required="true" />
		<cfargument name="aCurrent" type="array" required="true" />

		<cfset var qMetadata = application.stCOAPI[arguments.typename].qMetadata />
		<cfset var stField = {} />
		<cfset var oType = application.fapi.getContentType(arguments.typename) />
		<cfset var qResult = "" />

		<!--- Actual properties --->
		<cfquery dbtype="query" name="qMetadata">
			select 		propertyname as field, '' as label, ftType as type, ftSeq 
			from 		qMetadata
			where 		lower(propertyname) <> 'objectid'
			order by 	ftSeq, propertyname
		</cfquery>
		<cfloop query="qMetadata">
			<cfset querySetCell(qMetadata, "label", application.fapi.getPropertyMetadata(arguments.typename,qMetadata.field,"ftLabel",qMetadata.field), qMetadata.currentrow) />
			<cfset querySetCell(qMetadata, "type", application.fc.lib.cloudsearch.getDefaultFieldType(application.stCOAPI[arguments.typename].stProps[qMetadata.field].metadata), qMetadata.currentrow) />
		</cfloop>

		<!--- Generated properties --->
		<cfset qResult = getGeneratedProperties(arguments.typename) />
		<cfloop query="qResult">
			<cfif not listFindNoCase(valuelist(qMetadata.field),qResult.field)>
				<cfset queryAddRow(qMetadata) />
				<cfset querySetCell(qMetadata, "field", qResult.field) />
				<cfset querySetCell(qMetadata, "label", "#qResult.label#") />
				<cfset querySetCell(qMetadata, "type", qResult.type) />
				<cfset querySetCell(qMetadata, "ftSeq", arraymax(listToArray(valuelist(qMetadata.ftSeq)))+1) />
			</cfif>
		</cfloop>

		<!--- Missing properties --->
		<cfloop array="#arguments.aCurrent#" index="stField">
			<cfif not listFindNoCase(valuelist(qMetadata.field),stField.fieldName)>
				<cfset queryAddRow(qMetadata) />
				<cfset querySetCell(qMetadata,"field",stField.fieldName) />
				<cfset querySetCell(qMetadata,"label","#stField.fieldName# [INVALID]") />
				<cfset querySetCell(qMetadata,"type","string") />
				<cfset querySetCell(qMetadata,"ftSeq",arraymax(listToArray(valuelist(qMetadata.ftSeq)))+1) />
			</cfif>
		</cfloop>

		<cfreturn qMetadata />
	</cffunction>

	<cffunction name="updateProperties" access="public" output="false" returntype="void">
		<cfargument name="typename" type="string" required="true" />
		<cfargument name="aCurrent" type="array" required="true" />

		<cfset var existingProperties = "" />
		<cfset var i = 0 />
		<cfset var qFields = "" />
		<cfset var qMetadata = "" />

		<cfset var stField = {} />

		<cfif len(arguments.typename) and structKeyExists(application.stCOAPI,arguments.typename)>
			<cfset qMetadata = getGeneratedProperties(arguments.typename) />
			
			<cfloop from="#arraylen(arguments.aCurrent)#" to="1" index="i" step="-1">
				<cfif structKeyExists(application.stCOAPI[arguments.typename].stProps, arguments.aCurrent[i].fieldName) or listFindNoCase(valuelist(qMetadata.field), arguments.aCurrent[i].fieldName)>
					<cfset existingProperties = listappend(existingProperties,arguments.aCurrent[i].fieldName) />
				<cfelseif not arguments.aCurrent[i].bIndex>
					<cfset arrayDeleteAt(arguments.aCurrent,i) />
				</cfif>
			</cfloop>

			<!--- Generated properties --->
			<cfloop query="qMetadata">
				<cfif not listFindNoCase(existingProperties,qMetadata.field)>
					<cfset arrayappend(arguments.aCurrent, {
						"fieldName" = qMetadata.field,
						"fieldType" = qMetadata.type,
						"weight" = 1,
						"bIndex" = 0,
						"bSort" = 0,
						"bFacet" = 0
					}) />
				</cfif>
			</cfloop>

			<!--- Actual properties --->
			<cfset qMetadata = application.stCOAPI[arguments.typename].qMetadata />
			<cfloop query="qMetadata">
				<cfif not listFindNoCase(existingProperties,qMetadata.propertyname)>
					<cfset arrayappend(arguments.aCurrent, {
						"fieldName" = qMetadata.propertyname,
						"fieldType" = application.fc.lib.cloudsearch.getDefaultFieldType(application.stCOAPI[arguments.typename].stProps[qMetadata.propertyname].metadata),
						"weight" = 1,
						"bIndex" = 0,
						"bSort" = 0,
						"bFacet" = 0
					}) />
				</cfif>
			</cfloop>
		</cfif>

	</cffunction>

	<cffunction name="getIndexFields" access="public" output="false" returntype="query">
		<cfargument name="typename" required="false" type="string" />

		<cfset var qResult = "" />

			<cfswitch expression="#application.dbtype#">
				<cfcase value="mssql,mssql2005,mssql2012">
					<cfquery datasource="#application.dsn#" name="qResult">
						select 	p.fieldName as property, 
			            lower(p.fieldName) + '_'+ replace(p.fieldType,'-','_') as field, 
			            p.fieldType as 'type', p.weight, p.bSort as 'sort', p.bFacet as 'facet',
								'' as default_value, 0 as 'return', 1 as 'search', 0 as highlight, case when p.fieldType in ('text','text-array') then '_en_default_' else '' end as analysis_scheme
						from 	csContentType ct
								inner join
								csContentType_aProperties p
								on ct.objectid=p.parentid
						where 	p.bIndex=1
						<cfif structKeyExists(arguments,"typename")>
							and ct.contentType = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.typename#">
						</cfif>
					</cfquery>
				</cfcase>

				<cfdefaultcase>
					<cfquery datasource="#application.dsn#" name="qResult">
						select 	p.fieldName as property, concat(lower(p.fieldName),'_',replace(p.fieldType,'-','_')) as field, p.fieldType as `type`, p.weight, p.bSort as `sort`, p.bFacet as `facet`,
								'' as default_value, 0 as `return`, 1 as `search`, 0 as highlight, case when p.fieldType in ('text','text-array') then '_en_default_' else '' end as analysis_scheme
						from 	csContentType ct
								inner join
								csContentType_aProperties p
								on ct.objectid=p.parentid
						where 	p.bIndex=1
						<cfif structKeyExists(arguments,"typename")>
							and ct.contentType = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.typename#">
						</cfif>
					</cfquery>		
				</cfdefaultcase>
			</cfswitch>

		<cfif qResult.recordcount>
			<cfset queryAddRow(qResult) />
			<cfset querySetCell(qResult,"property","objectid") />
			<cfset querySetCell(qResult,"field","objectid_literal") />
			<cfset querySetCell(qResult,"type","literal") />
			<cfset querySetCell(qResult,"weight",1) />
			<cfset querySetCell(qResult,"default_value","") />
			<cfset querySetCell(qResult,"return",1) />
			<cfset querySetCell(qResult,"search",1) />
			<cfset querySetCell(qResult,"facet",0) />
			<cfset querySetCell(qResult,"sort",0) />
			<cfset querySetCell(qResult,"highlight",0) />
			<cfset querySetCell(qResult,"analysis_scheme","") />

			<cfset queryAddRow(qResult) />
			<cfset querySetCell(qResult,"property","typename") />
			<cfset querySetCell(qResult,"field","typename_literal") />
			<cfset querySetCell(qResult,"type","literal") />
			<cfset querySetCell(qResult,"weight",1) />
			<cfset querySetCell(qResult,"default_value","") />
			<cfset querySetCell(qResult,"return",1) />
			<cfset querySetCell(qResult,"search",1) />
			<cfset querySetCell(qResult,"facet",1) />
			<cfset querySetCell(qResult,"sort",0) />
			<cfset querySetCell(qResult,"highlight",0) />
			<cfset querySetCell(qResult,"analysis_scheme","") />
		</cfif>

		<cfreturn qResult />
	</cffunction>

	<cffunction name="getGeneratedProperties" access="public" output="false" returntype="query">
		<cfargument name="typename" type="string" required="true" />

		<cfset var qResult = querynew("field,label,type") />
		<cfset var prop = "" />
		<cfset var oType = application.fapi.getContentType(arguments.typename) />

		<!--- If there is a function in the type for this property, use that instead of the default --->
		<cfif structKeyExists(oType,"getCloudsearchGeneratedProperties")>
			<cfinvoke component="#oType#" method="getCloudsearchGeneratedProperties" returnvariable="qResult">
				<cfinvokeargument name="typename" value="#arguments.typename#" />
			</cfinvoke>
		<cfelse>
			<cfif not structKeyExists(application.stCOAPI[arguments.typename].stProps, "status")>
				<cfset queryAddRow(qResult) />
				<cfset querySetCell(qResult, "field", "status") />
				<cfset querySetCell(qResult, "label", "Status") />
				<cfset querySetCell(qResult, "type", "literal") />
			</cfif>

			<cfloop collection="#application.stCOAPI[arguments.typename].stProps#" item="prop">
				<cfif application.fapi.getPropertyMetadata(arguments.typename, prop, "type") eq "date">
					<cfset queryAddRow(qResult) />
					<cfset querySetCell(qResult, "field", prop & "_yyyy") />
					<cfset querySetCell(qResult, "label", application.fapi.getPropertyMetadata(arguments.typename, prop, "ftLabel", prop) & " (Year)") />
					<cfset querySetCell(qResult, "type", "literal") />

					<cfset queryAddRow(qResult) />
					<cfset querySetCell(qResult, "field", prop & "_yyyymmm") />
					<cfset querySetCell(qResult, "label", application.fapi.getPropertyMetadata(arguments.typename, prop, "ftLabel", prop) & " (Month)") />
					<cfset querySetCell(qResult, "type", "literal") />

					<cfset queryAddRow(qResult) />
					<cfset querySetCell(qResult, "field", prop & "_yyyymmmdd") />
					<cfset querySetCell(qResult, "label", application.fapi.getPropertyMetadata(arguments.typename, prop, "ftLabel", prop) & " (Day)") />
					<cfset querySetCell(qResult, "type", "literal") />
				</cfif>
			</cfloop>
		</cfif>

		<cfreturn qResult />
	</cffunction>

	<cffunction name="getRecordsToUpdate" access="public" output="false" returntype="query">
		<cfargument name="typename" type="string" required="true" />
		<cfargument name="builtToDate" type="string" required="false" />
		<cfargument name="maxRows" type="numeric" required="false" default="-1" />

		<cfset var qContent = "" />

		<cfquery datasource="#application.dsn#" name="qContent" maxrows="#arguments.maxrows#">
			select 		objectid, datetimeLastUpdated, '#arguments.typename#' as typename, 'updated' as operation
			from 		#application.dbowner##arguments.typename#
			<cfif application.fapi.showFarcryDate(arguments.builtToDate)>
				where 	datetimeLastUpdated > <cfqueryparam cfsqltype="cf_sql_timestamp" value="#arguments.builtToDate#">
			</cfif>

			UNION

			select 		archiveID as objectid, datetimeCreated as datetimeLastUpdated, '#arguments.typename#' as typename, 'deleted' as operation
			from 		#application.dbowner#dmArchive
			where 		objectTypename = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.typename#" />
						and bDeleted = <cfqueryparam cfsqltype="cf_sql_bit" value="1" />
						<cfif application.fapi.showFarcryDate(arguments.builtToDate)>
							and datetimeLastUpdated > <cfqueryparam cfsqltype="cf_sql_timestamp" value="#arguments.builtToDate#">
						</cfif>

			order by 	datetimeLastUpdated asc
		</cfquery>

		<cfreturn qContent />
	</cffunction>

	<cffunction name="bulkImportIntoCloudSearch" access="public" output="false" returntype="struct">
		<cfargument name="objectid" type="uuid" required="false" hint="The objectid of the csContentType record to import" />
		<cfargument name="stObject" type="struct" required="false" hint="The csContentType object to import" />
		<cfargument name="maxRows" type="numeric" required="false" default="-1" />
		<cfargument name="requestSize" type="numeric" required="false" default="5000000" />

		<cfset var qContent = "" />
		<cfset var oContent = "" />
		<cfset var stObject = "" />
		<cfset var stContentObject = "" />
		<cfset var stContent = {} />
		<cfset var strOut = createObject("java","java.lang.StringBuffer").init() />
		<cfset var builtToDate = "" />
		<cfset var stResult = {} />
		<cfset var count = 0 />

		<cfif not structKeyExists(arguments,"stObject")>
			<cfset arguments.stObject = getData(objectid=arguments.objectid) />
		</cfif>

		<cfset oContent = application.fapi.getContentType(typename=arguments.stObject.contentType) />
		<cfset qContent = getRecordsToUpdate(typename=arguments.stObject.contentType,builtToDate=arguments.stObject.builtToDate,maxRows=arguments.maxRows) />
		<cfset builtToDate = arguments.stObject.builtToDate />

		<cfset strOut.append("[") />

		<cfset var bFirstDocumentFound = false >
		<cfset var bAppend = false >

		<cfloop query="qContent">

			<cfset var operation = qContent.operation>
			<cfif qContent.operation eq "updated" and (structKeyExists(oContent, "isIndexable") AND NOT oContent.isIndexable(objectid=qContent.objectid))>
				<cfset operation = "deleted">
			</cfif>

			<cfif operation eq "updated">
				<cfset stContentObject = oContent.getData(objectid=qContent.objectid) />
				<cfset stContent = getCloudsearchDocument(stObject=stContentObject) />
				
				<cfif bAppend AND bFirstDocumentFound>
					<cfset strOut.append(",") />
					<cfset bAppend = false >
				</cfif>

				<cfset strOut.append('{"type":"add","id":"') />
				<cfset strOut.append(qContent.objectid) />
				<cfset strOut.append('","fields":') />
				<cfset strOut.append(serializeJSON(stContent)) />
				<cfset strOut.append('}') />
				<cfset bAppend = true >
				<cfset bFirstDocumentFound = true >
			<cfelseif operation eq "deleted">

				<cfif bAppend AND bFirstDocumentFound>
					<cfset strOut.append(",") />
					<cfset bAppend = false >
				</cfif>

				<cfset strOut.append('{"type":"delete","id":"') />
				<cfset strOut.append(qContent.objectid) />
				<cfset strOut.append('"}') />
				<cfset bAppend = true >
				<cfset bFirstDocumentFound = true >
			</cfif>

			<cfif bAppend>
				<cfset count++>
			</cfif>

			<cfif strOut.length() * ((qContent.currentrow+1) / qContent.currentrow) gt arguments.requestSize or qContent.currentrow eq qContent.recordcount>
				<cfset builtToDate = qContent.datetimeLastUpdated />
				<cfbreak />
			</cfif>
		</cfloop>

		<cfset strOut.append("]") />

		<cfif count>
			<cfset stResult = application.fc.lib.cloudsearch.uploadDocuments(documents=strOut.toString()) />
		</cfif>

		<cfset arguments.stObject.builtToDate = builtToDate />
		<cfset setData(stProperties=arguments.stObject) />
		<cflog file="cloudsearch" text="Updated #count# #arguments.stObject.contentType# record/s" />

		<cfset stResult["typename"] = arguments.stObject.contentType />
		<cfset stResult["count"] = count />
		<cfset stResult["builtToDate"] = builtToDate />

		<cfreturn stResult />
	</cffunction>

	<cffunction name="importIntoCloudSearch" access="public" output="false" returntype="struct">
		<cfargument name="objectid" type="uuid" required="false" hint="The objectid of the content to import" />
		<cfargument name="typename" type="string" required="false" hint="The typename of the content to import" />
		<cfargument name="stObject" type="struct" required="false" hint="The content object to import" />
		<cfargument name="operation" type="string" required="true" hint="updated or deleted" />

		<cfset var oContent = "" />
		<cfset var strOut = createObject("java","java.lang.StringBuffer").init() />
		<cfset var builtToDate = "" />
		<cfset var stResult = {} />

		<cfif not structKeyExists(arguments,"stObject")>
			<cfset arguments.stObject = application.fapi.getContentData(typename=arguments.typename,objectid=arguments.objectid) />
		</cfif>

		<cfset oContent = application.fapi.getContentType(typename=arguments.stObject.typename) />
		
		<cfset strOut.append("[") />

		<cfif arguments.operation eq "updated">
			<cfset stContent = getCloudsearchDocument(stObject=arguments.stObject) />
			
			<cfset strOut.append('{"type":"add","id":"') />
			<cfset strOut.append(arguments.stObject.objectid) />
			<cfset strOut.append('","fields":') />
			<cfset strOut.append(serializeJSON(stContent)) />
			<cfset strOut.append('}') />
			<cfset builtToDate = arguments.stObject.datetimeLastUpdated />
		<cfelseif arguments.operation eq "deleted">
			<cfset strOut.append('{"type":"delete","id":"') />
			<cfset strOut.append(arguments.stObject.objectid) />
			<cfset strOut.append('"}') />
			<cfset builtToDate = now() />
		</cfif>

		<cfset strOut.append("]") />

		<cfset stResult = application.fc.lib.cloudsearch.uploadDocuments(documents=strOut.toString()) />
		<cfquery datasource="#application.dsn#">
			update 	#application.dbowner#csContentType
			set 	builtToDate=<cfqueryparam cfsqltype="cf_sql_timestamp" value="#builtToDate#" />
			where 	contentType=<cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.stObject.typename#" />
		</cfquery>
		<cflog file="cloudsearch" text="Updated 1 #arguments.stObject.typename# record/s" />

		<cfset stResult["typename"] = arguments.stObject.typename />
		<cfset stResult["count"] = 1 />
		<cfset stResult["builtToDate"] = builtToDate />

		<cfreturn stResult />
	</cffunction>

	<cffunction name="getCloudsearchDocument" access="public" output="false" returntype="struct">
		<cfargument name="objectid" type="uuid" required="false" />
		<cfargument name="typename" type="string" required="false" />
		<cfargument name="stObject" type="struct" required="false" />

		<cfset var stFields = "" />
		<cfset var field = "" />
		<cfset var property = "" />
		<cfset var stResult = {} />
		<cfset var item = "" />
		<cfset var oType = "" />
		<cfset var i = 0 />

		<cfif not structKeyExists(arguments,"stObject")>
			<cfset arguments.stObject = application.fapi.getContentObject(typename=arguments.typename,objectid=arguments.objectid) />
		</cfif>

		<cfset oType = application.fapi.getContentType(arguments.stObject.typename) />

		<cfset stFields = application.fc.lib.cloudsearch.getTypeIndexFields(arguments.stObject.typename) />

		<cfloop collection="#stFields#" item="field">			
				<cfset property = stFields[field].property />		
				<!--- If there is a function in the type for this property, use that instead of the default --->
				<cfif structKeyExists(oType,"getCloudsearch#property#")>
					<cfinvoke component="#oType#" method="getCloudsearch#property#" returnvariable="item">
						<cfinvokeargument name="stObject" value="#arguments.stObject#" />
						<cfinvokeargument name="property" value="#property#" />
						<cfinvokeargument name="stIndexField" value="#stFields[field]#" />
					</cfinvoke>

					<cfset stResult[field] = item />
				<cfelseif refind("_(yyyy(mmm(dd)?)?)$", property)>
					<cfif application.fapi.showFarcryDate(arguments.stObject[rereplace(property, "_(yyyy(mmm(dd)?)?)$", "")])>
						<cfset stResult[field] = dateFormat(arguments.stObject[rereplace(property, "_(yyyy(mmm(dd)?)?)$", "")], listlast(property, "_")) />
					<cfelse>
						<cfset stResult[field] = "none" />
					</cfif>
				<cfelseif property eq "status" and not structKeyExists(application.stCOAPI[arguments.stObject.typename].stProps, "status")>
					<cfset stREsult[field] = "approved" />					
				<cfelseif structKeyExists(this, "process#rereplace(stFields[field].type, "[^\w]", "", "ALL")#")>
					<cfinvoke component="#this#" method="process#rereplace(stFields[field].type, "[^\w]", "", "ALL")#" returnvariable="item">
						<cfinvokeargument name="stObject" value="#arguments.stObject#" />
						<cfinvokeargument name="property" value="#property#" />
					</cfinvoke>

					<cfif len(item)>
						<cfset stResult[field] = item />
					</cfif>
				</cfif>

		</cfloop>

		<cfreturn stResult />
	</cffunction>

	<cffunction name="processDate" access="public" output="false" returntype="string">
		<cfargument name="stObject" type="struct" required="true" />
		<cfargument name="property" type="string" required="true" />

		<cfif isDate(arguments.stObject[arguments.property])>
			<cfreturn application.fc.lib.cloudsearch.getRFC3339Date(arguments.stObject[arguments.property]) />
		<cfelse>
			<cfreturn "" />
		</cfif>
	</cffunction>

	<cffunction name="processDateArray" access="public" output="false" returntype="string">
		<cfargument name="stObject" type="struct" required="true" />
		<cfargument name="property" type="string" required="true" />

		<cfset var aResult = [] />
		<cfset var value = arguments.stObject[arguments.property] />
		<cfset var item = "" />

		<cfif isSimpleValue(value)>
			<cfloop list="#value#" index="item" delimiters=",#chr(10)##chr(13)#">
				<cfset arrayAppend(aResult, application.fc.lib.cloudsearch.getRFC3339Date(item)) />
			</cfloop>
		<cfelseif arrayLen(value) and isstruct(value[1])>
			<cfloop array="#value#" index="item">
				<cfset arrayAppend(aResult, application.fc.lib.cloudsearch.getRFC3339Date(item.data)) />
			</cfloop>
		<cfelseif arrayLen(value)>
			<cfloop array="#value#" index="item">
				<cfset arrayAppend(aResult, application.fc.lib.cloudsearch.getRFC3339Date(item)) />
			</cfloop>
		</cfif>

		<cfreturn aResult />
	</cffunction>

	<cffunction name="processDouble" access="public" output="false" returntype="string">
		<cfargument name="stObject" type="struct" required="true" />
		<cfargument name="property" type="string" required="true" />

		<cfset var value = arguments.stObject[arguments.property] />

		<cfif len(value)>
			<cfreturn value />
		<cfelseif len(application.fapi.getPropertyMetadata(arguments.stObject.typename, arguments.property, "ftDefault", ""))>
			<cfreturn application.fapi.getPropertyMetadata(arguments.stObject.typename, arguments.property, "ftDefault") />
		<cfelseif len(application.fapi.getPropertyMetadata(arguments.stObject.typename, arguments.property, "default", ""))>
			<cfreturn application.fapi.getPropertyMetadata(arguments.stObject.typename, arguments.property, "default") />
		</cfif>
	</cffunction>

	<cffunction name="processDoubleArray" access="public" output="false" returntype="array">
		<cfargument name="stObject" type="struct" required="true" />
		<cfargument name="property" type="string" required="true" />

		<cfset var aResult = [] />
		<cfset var value = arguments.stObject[arguments.property] />
		<cfset var item = "" />

		<cfif isSimpleValue(value)>
			<cfset aResult = listToArray(value, ",#chr(10)##chr(13)#") />
		<cfelseif arrayLen(value) and isstruct(value[1])>
			<cfloop array="#value#" index="item">
				<cfset arrayAppend(aResult, item.data) />
			</cfloop>
		<cfelseif arrayLen(value)>
			<cfset aResult = value />
		</cfif>

		<cfreturn aResult />
	</cffunction>

	<cffunction name="processInt" access="public" output="false" returntype="string">
		<cfargument name="stObject" type="struct" required="true" />
		<cfargument name="property" type="string" required="true" />

		<cfset var value = arguments.stObject[arguments.property] />

		<cfif len(value)>
			<cfreturn int(value) />
		<cfelseif len(application.fapi.getPropertyMetadata(arguments.stObject.typename, arguments.property, "ftDefault", ""))>
			<cfreturn int(application.fapi.getPropertyMetadata(arguments.stObject.typename, property, "ftDefault")) />
		<cfelseif len(application.fapi.getPropertyMetadata(arguments.stObject.typename, arguments.property, "default", ""))>
			<cfreturn int(application.fapi.getPropertyMetadata(arguments.stObject.typename, arguments.property, "default")) />
		</cfif>
	</cffunction>

	<cffunction name="processIntArray" access="public" output="false" returntype="array">
		<cfargument name="stObject" type="struct" required="true" />
		<cfargument name="property" type="string" required="true" />

		<cfset var aResult = [] />
		<cfset var value = arguments.stObject[arguments.property] />
		<cfset var i = "" />
		<cfset var item = "" />

		<cfif isSimpleValue(value)>
			<cfset aResult = listToArray(value,",#chr(10)##chr(13)#") />
		<cfelseif arrayLen(value) and isstruct(value[1])>
			<cfloop array="#value#" index="item">
				<cfset arrayAppend(aResult, item.data) />
			</cfloop>
		<cfelseif arrayLen(value)>
			<cfset aResult = value />
		</cfif>
		
		<cfloop from="1" to="#arraylen(aResult)#" index="i">
			<cfset aResult[i] = int(aResult[i]) />
		</cfloop>

		<cfreturn aResult />
	</cffunction>

	<cffunction name="processLatLon" access="public" output="false" returntype="string">
		<cfargument name="stObject" type="struct" required="true" />
		<cfargument name="property" type="string" required="true" />

		<cfreturn arguments.stObject[arguments.property] />
	</cffunction>

	<cffunction name="processLiteral" access="public" output="false" returntype="string">
		<cfargument name="stObject" type="struct" required="true" />
		<cfargument name="property" type="string" required="true" />

		<cfreturn application.fc.lib.cloudsearch.sanitizeString(arguments.stObject[arguments.property]) />
	</cffunction>

	<cffunction name="processLiteralArray" access="public" output="false" returntype="array">
		<cfargument name="stObject" type="struct" required="true" />
		<cfargument name="property" type="string" required="true" />

		<cfset var aResult = [] />
		<cfset var value = arguments.stObject[arguments.property] />
		<cfset var item = "" />

		<cfif isSimpleValue(value)>
			<cfset aResult = listToArray(value,",#chr(10)##chr(13)#") />
		<cfelseif arrayLen(value) and isstruct(value[1])>
			<cfloop array="#value#" index="item">
				<cfset arrayAppend(aResult, item.data) />
			</cfloop>
		<cfelseif arrayLen(value)>
			<cfset aResult = value />
		</cfif>

		<cfreturn aResult />
	</cffunction>

	<cffunction name="processText" access="public" output="false" returntype="string">
		<cfargument name="stObject" type="struct" required="true" />
		<cfargument name="property" type="string" required="true" />

		<cfset var result = "" />

		<cfif structkeyexists(application.stCOAPI[arguments.stObject.typename].stProps[property].metadata, "ftRichtextConfig")>
			<cfset result = rereplace(arguments.stObject[property], "<[^>]+>", " ", "ALL") />
		<cfelse>
			<cfset result = arguments.stObject[property] />
		</cfif>

		<cfreturn application.fc.lib.cloudsearch.sanitizeString(result) />
	</cffunction>

	<cffunction name="processTextArray" access="public" output="false" returntype="array">
		<cfargument name="stObject" type="struct" required="true" />
		<cfargument name="property" type="string" required="true" />

		<cfset var aResult = [] />
		<cfset var value = arguments.stObject[arguments.property] />
		<cfset var item = "" />

		<cfif isSimpleValue(value)>
			<cfset aResult = listToArray(application.fc.lib.cloudsearch.sanitizeString(value),",#chr(10)##chr(13)#") />
		<cfelseif arrayLen(value) and isstruct(value[1])>
			<cfloop array="#value#" index="item">
				<cfset arrayAppend(aResult, application.fc.lib.cloudsearch.sanitizeString(item.data)) />
			</cfloop>
		<cfelseif arrayLen(value)>
			<cfloop array="#value#" index="item">
				<cfset arrayAppend(aResult, application.fc.lib.cloudsearch.sanitizeString(item)) />
			</cfloop>
		</cfif>

		<cfreturn aResult />
	</cffunction>

</cfcomponent>