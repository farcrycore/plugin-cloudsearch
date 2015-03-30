<cfcomponent output="false" extends="farcry.core.packages.types.types" displayname="CloudSearch Content Type" hint="Manages content type index information" bFriendly="false" bObjectBroker="false" bSystem="true" bRefObjects="false">
	
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
		ftHint="How the properties for this content type should be indexed."
		arrayProps="fieldName:string;fieldType:string;weight:integer;bIndex:boolean;bSort:boolean;bFacet:boolean">


	<cffunction name="AfterSave" access="public" output="false" returntype="struct" hint="Called from setData and createData and run after the object has been saved.">
		<cfargument name="stProperties" required="yes" type="struct" hint="A structure containing the contents of the properties that were saved to the object.">

		<cfset application.fc.lib.cloudsearch.resolveIndexFieldDifferences() />
		<cfset application.fc.lib.cloudsearch.updateTypeIndexFieldCache(typename=arguments.stProperties.typename) />

		<cfreturn super.aftersave(argumentCollection = arguments) />
	</cffunction>
	
	<cffunction name="onDelete" returntype="void" access="public" output="false" hint="Is called after the object has been removed from the database">
		<cfargument name="typename" type="string" required="true" hint="The type of the object" />
		<cfargument name="stObject" type="struct" required="true" hint="The object" />
		
		<cfset application.fc.lib.cloudsearch.resolveIndexFieldDifferences() />
		<cfset application.fc.lib.cloudsearch.updateTypeIndexFieldCache(typename=arguments.stProperties.typename) />

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
		<cfset qDupeCheck = application.fapi.getContentObjects(typename="csContentType",contentType_eq=trim(arguments.stFieldPost.value),objectid_eq=arguments.objectid) />
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
								<input type="hidden" name="#arguments.fieldname#bFacet#i#" value="#thisobject.bFacet#" />
							</td>
							<td>
								<input type="hidden" name="#arguments.fieldname#field#i#" value="#thisobject.fieldName#" />
								<cfloop query="qFields">
									<cfif qFields.field eq thisobject.fieldName><span title="#qFields.field#">#qFields.label#</span></cfif>
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
			<cfset qMetadata = application.stCOAPI[arguments.typename].qMetadata />

			<cfloop from="#arraylen(arguments.aCurrent)#" to="1" index="i" step="-1">
				<cfif structKeyExists(application.stCOAPI[arguments.typename].stProps,arguments.aCurrent[i].fieldName)>
					<cfset existingProperties = listappend(existingProperties,arguments.aCurrent[i].fieldName) />
				<cfelseif not arguments.aCurrent[i].bIndex>
					<cfset arrayDeleteAt(arguments.aCurrent,i) />
				</cfif>
			</cfloop>

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
		<cfset var stContent = {} />
		<cfset var strOut = createObject("java","java.lang.StringBuffer").init() />
		<cfset var builtToDate = "" />
		<cfset var stResult = {} />

		<cfif not structKeyExists(arguments,"stObject")>
			<cfset arguments.stObject = getData(objectid=arguments.objectid) />
		</cfif>

		<cfset oContent = application.fapi.getContentType(typename=arguments.stObject.contentType) />
		<cfset qContent = getRecordsToUpdate(typename=arguments.stObject.contentType,builtToDate=arguments.stObject.builtToDate,maxRows=arguments.maxRows) />
		<cfset builtToDate = arguments.stObject.builtToDate />

		<cfset strOut.append("[") />

		<cfloop query="qContent">
			<cfif qContent.operation eq "updated">
				<cfset stContent = getCloudsearchDocument(stObject=oContent.getData(objectid=qContent.objectid)) />
				
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

			<cfif strOut.length() * (qContent.currentrow / (qContent.currentrow+1)) gt arguments.requestSize or qContent.currentrow eq qContent.recordcount>
				<cfset builtToDate = qContent.datetimeLastUpdated />
				<cfset count = qContent.currentrow />
				<cfbreak />
			<cfelse>
				<cfset strOut.append(",") />
			</cfif>
		</cfloop>

		<cfset strOut.append("]") />

		<cfif count>
			<cfset stResult = application.fc.lib.cloudsearch.uploadDocuments(documents=strOut.toString()) />
			<cfset arguments.stObject.builtToDate = builtToDate />
			<cfset setData(stProperties=arguments.stObject) />
			<cflog file="cloudsearch" text="Updated #count# #arguments.stObject.contentType# record/s" />
		</cfif>

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
			<cftry>
				<cfset property = stFields[field].property />

				<!--- If there is a function in the type for this property, use that instead of the default --->
				<cfif structKeyExists(oType,"getCloudsearch#property#")>
					<cfinvoke component="#oType#" method="getCloudsearch#property#" returnvariable="item">
						<cfinvokeargument name="stObject" value="#arguments.stObject#" />
						<cfinvokeargument name="property" value="#property#" />
						<cfinvokeargument name="stIndexField" value="#stFields[field]#" />
					</cfinvoke>

					<cfset stResult[field] = item />
					<cfcontinue />
				</cfif>

				<cfswitch expression="#stFields[field].type#">
					<cfcase value="date">
						<cfset stResult[field] = application.fc.lib.cloudsearch.getRFC3339Date(arguments.stObject[property]) />
					</cfcase>
					<cfcase value="date-array">
						<cfset stResult[field] = [] />

						<cfif isSimpleValue(arguments.stObject[property])>
							<cfloop list="#arguments.stObject[property]#" index="item">
								<cfset arrayAppend(stResult[field], application.fc.lib.cloudsearch.getRFC3339Date(item)) />
							</cfloop>
						<cfelse>
							<cfloop array="#arguments.stObject[property]#" index="item">
								<cfset arrayAppend(stResult[field], application.fc.lib.cloudsearch.getRFC3339Date(item)) />
							</cfloop>
						</cfif>
					</cfcase>

					<cfcase value="double">
						<cfset stResult[field] = arguments.stObject[property] />
					</cfcase>
					<cfcase value="double-array">
						<cfif isSimpleValue(arguments.stObject[property])>
							<cfset stResult[field] = listToArray(arguments.stObject[property]) />
						<cfelse>
							<cfset stResult[field] = arguments.stObject[property] />
						</cfif>
					</cfcase>

					<cfcase value="int">
						<cfset stResult[field] = int(arguments.stObject[property]) />
					</cfcase>
					<cfcase value="int-array">
						<cfif isSimpleValue(arguments.stObject[property])>
							<cfset stResult[field] = listToArray(arguments.stObject[property]) />
						<cfelse>
							<cfset stResult[field] = arguments.stObject[property] />
						</cfif>
						<cfloop from="1" to="#arraylen(stResult[field])#" index="i">
							<cfset stResult[field][i] = int(stResult[field][i]) />
						</cfloop>
					</cfcase>

					<cfcase value="lat-lon">
						<cfset stResult[field] = arguments.stObject[property] />
					</cfcase>

					<cfcase value="literal">
						<cfset stResult[field] = arguments.stObject[property] />
					</cfcase>
					<cfcase value="literal-array">
						<cfif isSimpleValue(arguments.stObject[property])>
							<cfset stResult[field] = listToArray(arguments.stObject[property]) />
						<cfelse>
							<cfset stResult[field] = arguments.stObject[property] />
						</cfif>
					</cfcase>

					<cfcase value="text">
						<cfset stResult[field] = arguments.stObject[property] />
					</cfcase>
					<cfcase value="text-array">
						<cfif isSimpleValue(arguments.stObject[property])>
							<cfset stResult[field] = listToArray(arguments.stObject[property]) />
						<cfelse>
							<cfset stResult[field] = arguments.stObject[property] />
						</cfif>
					</cfcase>
				</cfswitch>

				<cfcatch>
				    <cfset exception = createObject("java", "java.lang.Exception").init("error setting #stFields[field].type# #field# to value #serializeJSON(arguments.stObject[property])# from #arguments.stObject.typename#:#arguments.stObject.objectid# - #cfcatch.message#") />
				    <cfset exception.initCause(cfcatch.getCause()) />
				    <cfset exception.setStackTrace(cfcatch.getStackTrace()) />
				    <cfthrow object="#exception#" />
				</cfcatch>
			</cftry>
		</cfloop>

		<cfreturn stResult />
	</cffunction>

</cfcomponent>