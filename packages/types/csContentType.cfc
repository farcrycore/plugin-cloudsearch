<cfcomponent output="false" extends="farcry.core.packages.types.types" displayname="CloudSearch Content Type" hint="Manages content type index information" bFriendly="false" bObjectBroker="true">
	
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

	<cfproperty name="resultImageField" type="nstring" required="false" default="" 
		ftSeq="6" ftFieldset="CloudSearch Content Type" ftLabel="Result Image" 
		ftType="list" ftDefault=""
		ftHint="The field that will be used for the search result teaser image.">

	<cfproperty name="lDocumentSizeFields" type="longchar" required="false" default="" 
		ftSeq="7" ftFieldset="CloudSearch Content Type" ftLabel="Document Size Fields" 
		ftType="list" 
		ftAllowMultiple="true"
		ftHint="The fields to use to calculate the document size">

	<cfproperty name="builtToDate" type="date" required="false" 
		ftSeq="9" ftFieldset="CloudSearch Content Type" ftLabel="Built to Date" 
		ftType="datetime"
		ftHint="For system use.  Updated by the system.  Used as a reference date of the last indexed item.  Used for batching when indexing items.  Default is blank (no date).">

	<cfproperty name="aProperties" type="array" 
		ftSeq="11" ftFieldset="CloudSearch Content Type" ftLabel="Properties" 
		ftWatch="contentType"
		ftHint="How the properties for this content type should be indexed.">


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
		<cfset qDupeCheck = application.fapi.getContentObjects(typename="solrProContentType",contentType_eq=trim(arguments.stFieldPost.value),objectid_eq=arguments.objectid) />
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
			<cfset queryAddRow(qListData) />
			<cfset querySetCell(qListData, "typename", type) />
			<cfset querySetCell(qListData, "displayname", "#application.stcoapi[type].displayname# (#type#)") />
		</cfloop>
		
		<cfquery dbtype="query" name="qListData">
			SELECT typename as value, displayname as name FROM qListData ORDER BY lower(displayname)
		</cfquery>
		
		<cfreturn qListData />
	</cffunction>
	
	<cffunction name="ftEditAObjects" access="public" output="false" returntype="string" hint="This is going to called from ft:object and will always be passed 'typename,stobj,stMetadata,fieldname'.">
		<cfargument name="typename" required="true" type="string" hint="The name of the type that this field is part of.">
		<cfargument name="stObject" required="true" type="struct" hint="The object of the record that this field is part of.">
		<cfargument name="stMetadata" required="true" type="struct" hint="This is the metadata that is either setup as part of the type.cfc or overridden when calling ft:object by using the stMetadata argument.">
		<cfargument name="fieldname" required="true" type="string" hint="This is the name that will be used for the form field. It includes the prefix that will be used by ft:processform.">
		<cfargument name="stPackage" required="true" type="struct" hint="Contains the metadata for the all fields for the current typename.">
				
		<cfset var htmlLabel = "" />
		<cfset var joinItems = "" />
		<cfset var i = "" />
		<cfset var returnHTML = "" />
		<cfset var thisobject = "" />
		<cfset var thiswebskin = "" />
		<cfset var thistypename = "" />
		<cfset var stWebskins = structnew() />
		<cfset var itemlist = "" />
		
		<cfimport taglib="/farcry/core/tags/webskin" prefix="skin" />
		<cfimport taglib="/farcry/core/tags/formtools" prefix="ft" />
		
		<skin:loadJS id="fc-jquery" />
		
		<cfset joinItems = arguments.stObject[arguments.stMetadata.name] />

		<cfsavecontent variable="returnHTML">
			<input type="hidden" name="#arguments.fieldname#" value="#jsstringformat(serializeJSON(arguments.stObject[arguments.stMetadata.name]))#" />

			<table class="table">
				<thead>
					<tr>
						<th>Field</th>
						<th>Type</th>
						<th>Weight</th>
						<th>Index</th>
						<th>Sortable</th>
					</tr>
				</thead>
				<tbody>
					<cfloop array="#joinItems#" index="thisobject">
						<skin:view stObject="#thisobject#" webskin="editRow" bIgnoreSecurity="true" valid="#len(arguments.stObject.contentType) and isdefined('application.stCOAPI.#arguments.stObject.contentType#.stProps.#thisobject.fieldName#')#" />
					</cfloop>
				</tbody>
			</table>

			<cfif len(arguments.stObject.contentType) and structKeyExists(application.stCOAPI,arguments.stObject.contentType)>
				<button class="btn">Add Field</button>
			<cfelse>
				<div class="alert alert-error">Please select a valid content type</div>
			</cfif>
		</cfsavecontent>

		<cfreturn returnHTML />
	</cffunction>

</cfcomponent>