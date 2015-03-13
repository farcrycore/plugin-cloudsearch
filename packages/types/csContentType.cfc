<cfcomponent output="false" extends="farcry.core.packages.types.types" displayname="CloudSearch Content Type" hint="Manages content type index information" bFriendly="false" bObjectBroker="true" bSystem="true">
	
	<cfproperty name="title" type="nstring" required="true" 
		ftSeq="1" ftFieldset="CloudSearch Content Type" ftLabel="Title" 
		ftType="string" 
		bLabel="true" ftValidation="required"
		ftHint="The name of this content type.  This will appear on the search form and will allow users to search a specific content type.">

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
		
		<cfreturn super.aftersave(argumentCollection = arguments) />
	</cffunction>
	
	<cffunction name="onDelete" returntype="void" access="public" output="false" hint="Is called after the object has been removed from the database">
		<cfargument name="typename" type="string" required="true" hint="The type of the object" />
		<cfargument name="stObject" type="struct" required="true" hint="The object" />
		

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
		<cfargument name="fields" required="false" type="string" />

		<cfset var qResult = "" />

		<cfquery datasource="#application.dsn#" name="qResult">
			select 	concat(lower(fieldName),'_',replace(fieldType,'-','_')) as field, fieldType as `type`, weight, bSort as `sort`, bFacet as `facet`,
					'' as default_value, 0 as `return`, 1 as `search`, 0 as highlight, '' as analysis_scheme
			from 	csContentType_aProperties
			where 	bIndex=1
		</cfquery>

		<cfset queryAddRow(qResult) />
		<cfset querySetCell(qResult,"field","objectid_literal") />
		<cfset querySetCell(qResult,"type","literal") />
		<cfset querySetCell(qResult,"default_value","") />
		<cfset querySetCell(qResult,"return",1) />
		<cfset querySetCell(qResult,"search",1) />
		<cfset querySetCell(qResult,"facet",0) />
		<cfset querySetCell(qResult,"sort",0) />
		<cfset querySetCell(qResult,"highlight",0) />
		<cfset querySetCell(qResult,"analysis_scheme","") />

		<cfset queryAddRow(qResult) />
		<cfset querySetCell(qResult,"field","typename_literal") />
		<cfset querySetCell(qResult,"type","literal") />
		<cfset querySetCell(qResult,"default_value","") />
		<cfset querySetCell(qResult,"return",1) />
		<cfset querySetCell(qResult,"search",1) />
		<cfset querySetCell(qResult,"facet",1) />
		<cfset querySetCell(qResult,"sort",0) />
		<cfset querySetCell(qResult,"highlight",0) />
		<cfset querySetCell(qResult,"analysis_scheme","") />

		<cfreturn qResult />
	</cffunction>

</cfcomponent>