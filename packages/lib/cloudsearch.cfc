component {
	
	public any function init(){
		this.fieldCache = {};
		this.domainEndpoints = {};
		this.invalidchars = createObject("java", "java.util.regex.Pattern").compile( javaCast( "string", "[^\x{0009}\x{000a}\x{000d}\x{0020}-\x{D7FF}\x{E000}-\x{FFFD}]" ) );

		return this;
	}

	public query function getAllContentTypes(string lObjectIDs=""){
		var stArgs = {
			"typename" = "csContentType",
			"lProperties" = "objectid,contentType,label",
			"orderBy" = "contentType"
		}

		if (listLen(arguments.lObjectIds)){
			stArgs["objectid_in"] = arguments.lObjectIds;
		}

		// TODO:  throws error
		// if (bIncludeNonSearchable eq false){
		//	stArgs["objectid_in"] = arguments.lObjectIds;
		//}
		
		return application.fapi.getContentObjects(argumentCollection=stArgs);
	}
	
	public query function getFieldTypes(){
		var q = querynew("code,label");

		queryAddRow(q);
		querySetCell(q,"code","date");
		querySetCell(q,"label","Date");

		queryAddRow(q);
		querySetCell(q,"code","date-array");
		querySetCell(q,"label","Date Array");

		queryAddRow(q);
		querySetCell(q,"code","double");
		querySetCell(q,"label","Double");

		queryAddRow(q);
		querySetCell(q,"code","double-array");
		querySetCell(q,"label","Double Array");

		queryAddRow(q);
		querySetCell(q,"code","int");
		querySetCell(q,"label","Integer");

		queryAddRow(q);
		querySetCell(q,"code","int-array");
		querySetCell(q,"label","Integer Array");

		queryAddRow(q);
		querySetCell(q,"code","latlon");
		querySetCell(q,"label","Lat, Long pair");

		queryAddRow(q);
		querySetCell(q,"code","literal");
		querySetCell(q,"label","Literal");

		queryAddRow(q);
		querySetCell(q,"code","literal-array");
		querySetCell(q,"label","Literal Array");

		queryAddRow(q);
		querySetCell(q,"code","text");
		querySetCell(q,"label","Text");

		queryAddRow(q);
		querySetCell(q,"code","text-array");
		querySetCell(q,"label","Text Array");

		return q;
	}

	public string function getDefaultFieldType(required struct stMeta){
		switch (stMeta.type){
			case "string": 
				switch (stMeta.ftType){
					case "list":
						if (stMeta.ftSelectMultiple)
							return "literal-array";
						else
							return "literal";
					case "category":
						return "literal-array";
				}

			case "varchar": case "longchar":
				return "text";

			case "numeric":
				return "double";

			case "integer":
				return "int";

			case "uuid":
				return "literal";

			case "array":
				return "literal-array";

			case "datetime": case "date":
				return "date";

			case "boolean":
				return "int";

			default:
				return "text";
		}
	}

	public boolean function isEnabled(){
		var domain = application.fapi.getConfig("cloudsearch","domain","");
		var regionname = application.fapi.getConfig("cloudsearch","region","");

		return len(domain) AND len(regionname);
	}

	public any function getClient(string type="config", string domain=""){
		var domain = application.fapi.getConfig("cloudsearch","domain","");
		var regionname = application.fapi.getConfig("cloudsearch","region","");
		var accessID = application.fapi.getConfig("cloudsearch","accessID","");
		var accessSecret = application.fapi.getConfig("cloudsearch","accessSecret","");

		var awsCredentials = "";
		var credentialsProvider = "";
		var region = "";
		var tmpClient = "";
		var endpoint = "";
		var useIAMRole = false;

		if (not isEnabled()){
			throw(message="The CloudSearch settings for this application have not been set up");
		}

		// Determine authentication method
		if (len(accessID) AND len(accessSecret)) {
			// Use explicit API key credentials
			writeLog(file="cloudsearch",text="Using explicit AWS credentials (access key)");
			awsCredentials = createobject("java","software.amazon.awssdk.auth.credentials.AwsBasicCredentials").create(accessID, accessSecret);
			credentialsProvider = createobject("java","software.amazon.awssdk.auth.credentials.StaticCredentialsProvider").create(awsCredentials);
		} else {
			// Use IAM role / default credentials chain
			writeLog(file="cloudsearch",text="Using IAM role / default credentials chain");
			credentialsProvider = createobject("java","software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider").create();
			useIAMRole = true;
		}

		if (arguments.type eq "config" and not structkeyexists(this, "client")){
			writeLog(file="cloudsearch",text="Starting CloudSearch config client (#useIAMRole ? 'IAM role' : 'API key'#)");

			// AWS SDK 2.x - Use Region.of() instead of Region.getRegion()
			region = createobject("java","software.amazon.awssdk.regions.Region").of(regionname);
			writeLog(file="cloudsearch",text="Setting region to [#region.toString()#]");

			// AWS SDK 2.x - Use CloudSearchClient builder
			tmpClient = createobject("java","software.amazon.awssdk.services.cloudsearch.CloudSearchClient").builder()
				.region(region)
				.credentialsProvider(credentialsProvider)
				.build();

			this.client = tmpClient;
		}
		if (arguments.type eq "domain" and not structkeyexists(this, "domainclient")){
			writeLog(file="cloudsearch",text="Starting CloudSearch domain client (#useIAMRole ? 'IAM role' : 'API key'#)");

			region = createobject("java","software.amazon.awssdk.regions.Region").of(regionname);
			endpoint = getDomainEndpoint(arguments.domain);
			
			// Ensure endpoint has https:// scheme
			if (not findNoCase("https://", endpoint) and not findNoCase("http://", endpoint)) {
				endpoint = "https://" & endpoint;
			}
			
			writeLog(file="cloudsearch",text="Setting endpoint to [#endpoint#]");

			// AWS SDK 2.x - Use CloudSearchDomainClient builder with custom endpoint
			var endpointOverride = createobject("java","java.net.URI").create(endpoint);
			tmpClient = createobject("java","software.amazon.awssdk.services.cloudsearchdomain.CloudSearchDomainClient").builder()
				.region(region)
				.credentialsProvider(credentialsProvider)
				.endpointOverride(endpointOverride)
				.build();

			this.domainclient = tmpClient;
		}

		if (arguments.type eq "config"){
			return this.client;
		}
		if (arguments.type eq "domain"){
			return this.domainclient;
		}
	}

	public struct function getReuploadAllDocumentsStatus() {
		if (structKeyExists(this, "reloadingStatus")) {
			return this.reloadingStatus;
		}

		return { "status":"none" };
	}

	public struct function reuploadAllDocuments(boolean bClearDocuments=true) {
		var domain = application.fapi.getConfig("cloudsearch","domain","");

		try {
			this.reloadingStatus = {
				"status" = "queued",
				"status_detail" = "Reupload queued",
				"domain" = domain,
				"clear": {
					"start": 0,
					"time": 0,
					"count": 0
				},
				"reupload": {
					"start": 0,
					"time": 0,
					"count": 0
				}
			};
			var stResult = {};

			// clear documents
			if (arguments.bClearDocuments) {
				this.reloadingStatus.status = "clearing";
				this.reloadingStatus.status_detail = "Clearing documents";
				this.reloadingStatus.clear.start = getTickCount();
				this.reloadingStatus.clear.count = clearDocuments(domain);
			}

			// reupload documents
			this.reloadingStatus.status = "reuploading";
			this.reloadingStatus.status_detail = "Getting types to reupload";
			this.reloadingStatus.reupload.start = getTickCount();
			this.reloadingStatus.clear.time = numberFormat((this.reloadingStatus.reupload.start - this.reloadingStatus.clear.start) / 1000, "0.0") & "s";

			var qCT = application.fapi.getContentObjects(typename="csContentType");
			var oCT = application.fapi.getContentType(typename="csContentType");
			var stCT = {};
			var k = "";

			for (var row in qCT) {
				stCT = oCT.getData(objectid=qCT.objectid);

				if (structKeyExists(application.stCoapi, stCT.contentType)) {
					this.reloadingStatus.status_detail = "Querying for #stCT.contentType# content to push";
					var qData = oCT.getRecordsToUpdate(typename=stCT.contentType, includeDeletions=false);
					
					if (qData.recordcount) {
						this.reloadingStatus.status_detail = "Reuploading #stCT.contentType#";
						
						var stResult = { nextRow = 1 };
						while (stResult.nextRow lte qData.recordcount) {
							stResult = oCT.bulkImportIntoCloudSearchByQuery(qData=qData, fromRow=stResult.nextRow, maxRows=10);
							this.reloadingStatus.reupload.count += stResult.count;
							this.reloadingStatus.status_detail = "Reuploading #stCT.contentType# (#this.reloadingStatus.reupload.count#/#qData.recordcount#)";
							this.reloadingStatus.reupload.time = numberFormat((getTickCount() - this.reloadingStatus.reupload.start) / 1000, "0.0") & "s";
						}
						
						stCT.builtToDate = qData.datetimeLastUpdated[qData.recordcount];
						oCT.setData(stProperties=stCT);
					}
				}
			}

			this.reloadingStatus.status = "done";
		}
		catch (err) {
			this.reloadingStatus.status = "error";
			this.reloadingStatus.status_detail = err.message;
			this.reloadingStatus.error_detail = err;
		}

		return this.reloadingStatus;
	}

	/* CloudSearch API Wrappers */
	public query function getDomains(){
		var csClient = getClient();
		var domain = application.fapi.getConfig("cloudsearch","domain","");
		var describeDomainsRequest = {};
		// AWS SDK 2.x - Use DescribeDomainsRequest builder

		if (len(domain)){
			var domainNamesList = createObject("java", "java.util.ArrayList").init();
			domainNamesList.add(domain);
			describeDomainsRequest = createobject("java","software.amazon.awssdk.services.cloudsearch.model.DescribeDomainsRequest").builder().domainNames(domainNamesList).build();
		} else {
			describeDomainsRequest = createobject("java","software.amazon.awssdk.services.cloudsearch.model.DescribeDomainsRequest").builder().build();
		}

		var describeDomainsResponse = csClient.describeDomains(describeDomainsRequest);
		var domainResult = {};
		var qResult = querynew("id,domain,created,processing,requires_index,deleted,instance_count,instance_type,endpoint", "varchar,varchar,bit,bit,bit,bit,integer,varchar,varchar");

		// AWS SDK 2.x - domainStatusList() instead of getDomainStatusList()
		for (domainResult in describeDomainsResponse.domainStatusList()){
			queryAddRow(qResult);
			querySetCell(qResult,"id",domainResult.domainId());
			querySetCell(qResult,"domain",domainResult.domainName());
			querySetCell(qResult,"created",domainResult.created());
			querySetCell(qResult,"processing",domainResult.processing());
			querySetCell(qResult,"requires_index",domainResult.requiresIndexDocuments());
			querySetCell(qResult,"deleted",domainResult.deleted());
			querySetCell(qResult,"instance_count",domainResult.searchInstanceCount());
			querySetCell(qResult,"instance_type",domainResult.searchInstanceType());
			querySetCell(qResult,"endpoint",domainResult.docService().endpoint());
		}

		return qResult;
	}

	public query function getIndexFields(string domain, string fields) {
		var csClient = getClient();
		var describeIndexFieldsRequestBuilder = createobject("java","software.amazon.awssdk.services.cloudsearch.model.DescribeIndexFieldsRequest").builder();
		var describeIndexFieldsResponse = {};
		var indexFieldsList = [];
		var indexFieldStatus = {};
		var indexField = {};
		var indexStatus = {};
		var qResult = querynew("field,type,default_value,return,search,facet,sort,highlight,analysis_scheme,pending_deletion,state","varchar,varchar,varchar,bit,bit,bit,bit,bit,varchar,bit,varchar");

		if (not structKeyExists(arguments,"domain") or not len(arguments.domain)){
			arguments.domain = application.fapi.getConfig("cloudsearch","domain","")
		}

		describeIndexFieldsRequestBuilder.domainName(arguments.domain);
		if (structKeyExists(arguments,"fields")){
			// AWS SDK 2.x - Use fieldNames() method with collection
			var fieldNamesList = createObject("java", "java.util.ArrayList").init();
			for (var fieldName in listtoarray(arguments.fields)) {
				fieldNamesList.add(fieldName);
			}
			describeIndexFieldsRequestBuilder.fieldNames(fieldNamesList);
		}

		var describeIndexFieldsRequest = describeIndexFieldsRequestBuilder.build();
		describeIndexFieldsResponse = csClient.describeIndexFields(describeIndexFieldsRequest);

		// Get the list of index fields - this is a Java List, not a CF array
    	indexFieldsList = describeIndexFieldsResponse.indexFields();
		// Iterate using Java iterator or size/get pattern
		for (var i = 0; i < indexFieldsList.size(); i++){
			indexFieldStatus = indexFieldsList.get(i);
			
			queryAddRow(qResult);

			indexField = indexFieldStatus.options();
			querySetCell(qResult,"field",indexField.indexFieldName());
			querySetCell(qResult,"type",indexField.indexFieldTypeAsString());
			insertIndexFieldOptions(qResult, qResult.recordcount, indexField);

			indexStatus = indexFieldStatus.status();
			querySetCell(qResult,"pending_deletion",indexStatus.pendingDeletion());
			querySetCell(qResult,"state",indexStatus.stateAsString());
		}

		return qResult;
	}

	public query function updateIndexField(string domain, required string field, required string type, required string default_value, required boolean return, required boolean search, required boolean facet, required boolean sort, required boolean highlight, required string analysis_scheme, query qResult){
		var csClient = getClient();
		var indexField = createIndexFieldObject(argumentCollection=arguments);
		var defineIndexFieldResponse = {};
		var indexFieldStatus = {};
		var indexStatus = {};

		if (not structKeyExists(arguments,"domain") or not len(arguments.domain)){
			arguments.domain = application.fapi.getConfig("cloudsearch","domain","");
		}

		if (not structKeyExists(arguments,"qResult")){
			arguments.qResult = createIndexQuery();
		}

		// AWS SDK 2.x - Use DefineIndexFieldRequest builder
		var defineIndexFieldRequest = createobject("java","software.amazon.awssdk.services.cloudsearch.model.DefineIndexFieldRequest").builder()
			.domainName(arguments.domain)
			.indexField(indexField)
			.build();

		defineIndexFieldResponse = csClient.defineIndexField(defineIndexFieldRequest);

		// create a single-row query for the update result
		indexFieldStatus = defineIndexFieldResponse.indexField();
		queryAddRow(arguments.qResult);

		indexField = indexFieldStatus.options();
		querySetCell(arguments.qResult,"field",indexField.indexFieldName());
		querySetCell(arguments.qResult,"type",indexField.indexFieldTypeAsString());
		insertIndexFieldOptions(arguments.qResult, 1, indexField);

		indexStatus = indexFieldStatus.status();
		querySetCell(arguments.qResult,"pending_deletion",indexStatus.pendingDeletion());
		querySetCell(arguments.qResult,"state",indexStatus.stateAsString());

		return arguments.qResult;
	}

	public query function deleteIndexField(string domain, required string field, query qResult){
		var csClient = getClient();
		var deleteIndexFieldResponse = {};
		var indexFieldStatus = {};
		var indexStatus = {};
		
		if (not structKeyExists(arguments,"domain") or not len(arguments.domain)){
			arguments.domain = application.fapi.getConfig("cloudsearch","domain","")
		}

		if (not structKeyExists(arguments,"qResult")){
			arguments.qResult = createIndexQuery();
		}

		// AWS SDK 2.x - Use DeleteIndexFieldRequest builder
		var deleteIndexFieldRequest = createobject("java","software.amazon.awssdk.services.cloudsearch.model.DeleteIndexFieldRequest").builder()
			.domainName(arguments.domain)
			.indexFieldName(arguments.field)
			.build();

		deleteIndexFieldResponse = csClient.deleteIndexField(deleteIndexFieldRequest);

		// create a single-row query for the update result
		indexFieldStatus = deleteIndexFieldResponse.indexField();
		queryAddRow(arguments.qResult);

		indexField = indexFieldStatus.options();
		querySetCell(arguments.qResult,"field",indexField.indexFieldName());
		querySetCell(arguments.qResult,"type",indexField.indexFieldTypeAsString());
		insertIndexFieldOptions(arguments.qResult, 1, indexField);

		indexStatus = indexFieldStatus.status();
		querySetCell(arguments.qResult,"pending_deletion",indexStatus.pendingDeletion());
		querySetCell(arguments.qResult,"state",indexStatus.stateAsString());

		return arguments.qResult;
	}

	public numeric function clearDocuments(string domain){
		var pageSize = 10000;
		var result = { recordcount=1 };
		var strOut = "";
		var row = {};
		var total = 0;

		while (result.recordcount) {
			strOut = createObject("java","java.lang.StringBuffer").init();
			result = search(domain=arguments.domain, maxrows=pageSize);

			if (result.items.recordcount) {
				strOut.append("[");

				for (row in result.items) {
					if (result.items.currentrow gt 1) {
						strOut.append(",");
					}

					strOut.append('{"type":"delete","id":"');
					strOut.append(row.objectid);
					strOut.append('"}');
				}

				strOut.append("]");

				uploadDocuments(domain=arguments.domain, documents=strOut.toString());

				total += result.items.recordcount;
			}
		}

		return total;
	}

	public array function indexDocuments(string domain){
		var csClient = getClient();
		var indexDocumentsResponse = {};
		var aResult = [];
		var field = "";

		if (not structKeyExists(arguments,"domain") or not len(arguments.domain)){
			arguments.domain = application.fapi.getConfig("cloudsearch","domain","")
		}

		// AWS SDK 2.x - Use IndexDocumentsRequest builder
		var indexDocumentsRequest = createobject("java","software.amazon.awssdk.services.cloudsearch.model.IndexDocumentsRequest").builder()
			.domainName(arguments.domain)
			.build();

		indexDocumentsResponse = csClient.indexDocuments(indexDocumentsRequest);

		// AWS SDK 2.x - fieldNames() instead of getFieldNames()
		for (field in indexDocumentsResponse.fieldNames()){
			arrayAppend(aResult,field)
		}

		return aResult;
	}

	public struct function uploadDocuments(string domain, required string documents){
		var csdClient = "";
		var uploadDocumentsResponse = {};
		var inputStream = "";
		var aWarnings = [];
		var warning = {};
		var id = application.fapi.getUUID();
		var documentFile = "";

		if (not structKeyExists(arguments,"domain") or not len(arguments.domain)){
			arguments.domain = application.fapi.getConfig("cloudsearch","domain","")
		}
		
		// strip invalid charactures
		arguments.documents = RemoveExtraInvalidChars(arguments.documents);

		// create temporary file for streaming into the SDK
		application.fc.lib.cdn.ioWriteFile(location="temp",file="/cloudsearch/documents-#id#.json",data=arguments.documents);
		documentFile = application.fc.lib.cdn.ioGetFileLocation(location="temp",file="/cloudsearch/documents-#id#.json",bRetrieve=true).path;
		inputStream = createobject("java","java.io.FileInputStream").init(documentFile);

		csdClient = getClient("domain", arguments.domain);

		// AWS SDK 2.x - Use UploadDocumentsRequest builder with RequestBody
		var requestBody = createobject("java","software.amazon.awssdk.core.sync.RequestBody").fromInputStream(inputStream, getFileInfo(documentFile).size);
		var uploadDocumentsRequest = createobject("java","software.amazon.awssdk.services.cloudsearchdomain.model.UploadDocumentsRequest").builder()
			.contentType("application/json")
			.build();

		try {
			uploadDocumentsResponse = csdClient.uploadDocuments(uploadDocumentsRequest, requestBody);
		}
		catch (java.lang.IllegalStateException e) {
			// Connection pool has been shut down — reset the cached client, re-open the stream, and retry once
			writeLog(file="cloudsearch", text="Domain client connection pool shut down — resetting and retrying uploadDocuments");
			structDelete(this, "domainclient");
			csdClient = getClient("domain", arguments.domain);
			inputStream.close();
			inputStream = createobject("java","java.io.FileInputStream").init(documentFile);
			requestBody = createobject("java","software.amazon.awssdk.core.sync.RequestBody").fromInputStream(inputStream, getFileInfo(documentFile).size);
			uploadDocumentsResponse = csdClient.uploadDocuments(uploadDocumentsRequest, requestBody);
		}
		catch (software.amazon.awssdk.services.cloudsearchdomain.model.DocumentServiceException e) {
			if (len(arguments.documents) lt 500000)
				throw(message=e.message, detail='{"domain":"#arguments.domain#", "documents":#arguments.documents#}');
			else
				throw(message=e.message, detail='{"domain":"#arguments.domain#", "documents":"#left(arguments.documents,500000)#"}');
		}

		// remove temporary file
		application.fc.lib.cdn.ioDeleteFile(location="temp",file="/cloudsearch/documents-#id#.json");

		// AWS SDK 2.x - Use method names without get prefix
		for (warning in uploadDocumentsResponse.warnings()){
			arrayAppend(aWarnings,warning.message());
		}

		return {
			"adds" = uploadDocumentsResponse.adds(),
			"deletes" = uploadDocumentsResponse.deletes(),
			"status" = uploadDocumentsResponse.status(),
			"warnings" = aWarnings
		};
	}

	public struct function search(string domain, string typename, string rawQuery, string queryParser="simple", string rawFilter, string rawFacets, array conditions, array filters, struct facets={}, numeric maxrows=10, numeric page=1, boolean log=true, string sort="_score desc") {
		var csdClient = "";
		var searchResponse = {};
		var hits = {};
		var hit = {};
		var buckets = {};
		var bucket = {};
		var stIndexFields = {};
		var aQuery = [];
		var aSubQuery = [];
		var key = "";
		var keyS = "";
		var prop = "";
		var op = "";
		var stResult = {};
		var st = {};
		var facetResult = {};

		if (arguments.log){
			arguments.log = false;
			addSearchLog(args=duplicate(arguments));
		}

		if (not structKeyExists(arguments,"domain") or not len(arguments.domain)){
			arguments.domain = application.fapi.getConfig("cloudsearch","domain","")
		}

		csdClient = getClient("domain", arguments.domain);

		// collect index field information
		if (structKeyExists(arguments,"typename") and len(arguments.typename)){
			// filter by content type
			if (listlen(arguments.typename)){
				for (key in listtoarray(arguments.typename)){
					structAppend(stIndexFields, getTypeIndexFields(key));
				}
			}
			else {
				stIndexFields = getTypeIndexFields(arguments.typename);
			}
		}
		else {
			stIndexFields = getTypeIndexFields();
		}

		// create query
		if (not structKeyExists(arguments,"rawQuery")){
			if (not structKeyExists(arguments,"conditions")){
				arguments.conditions = [];
			}

			st = getSearchQueryFromArray(stIndexFields=stIndexFields, conditions=arguments.conditions, bBoost=true);
			arguments.rawQuery = st.query;
			arguments.queryParser = st.parser;

			if (arraylen(arguments.conditions) gt 1){
				arguments.rawQuery = "(and " & chr(10) & arguments.rawQuery & chr(10) & ")";
			}

			if (arguments.rawQuery eq "") {
				arguments.rawQuery = "matchall";
			}
		}

		// create filter
		if (not structKeyExists(arguments,"rawFilter")){
			if (not structKeyExists(arguments,"filters")){
				arguments.filters = [];
			}

			if (structKeyExists(arguments,"typename") and len(arguments.typename)){
				// filter by content type
				if (listlen(arguments.typename)){
					arrayPrepend(arguments.filters, { "or"=[] });

					for (key in listtoarray(arguments.typename)){
						arrayAppend(arguments.filters[1]["or"],{ "property"="typename", "term"=key });
					}
				}
				else {
					arrayPrepend(arguments.filters, { "property"="typename", "term"=arguments.typename });
				}
			}

			if (arraylen(arguments.filters)){
				arguments.rawFilter = getSearchQueryFromArray(stIndexFields=stIndexFields, conditions=arguments.filters, bBoost=false).query;

				if (arraylen(arguments.filters) gt 1){
					arguments.rawFilter = "(and " & chr(10) & arguments.rawFilter & chr(10) & ")";
				}
			}
			else {
				arguments.rawFilter = "";
			}
		}

		// create facet config
		if (not structKeyExists(arguments,"rawFacets")){
			if (not structKeyExists(arguments,"facets")){
				arguments.facets = {};
			}

			st = {};
			for (key in arguments.facets) {
				for (keyS in stIndexFields) {
					if (stIndexFields[keyS].property eq key) {
						st[stIndexFields[keyS].field] = arguments.facets[key];
					}
				}
			}

			if (structCount(st)){
				arguments.rawFacets = serializeJSON(st);
			}
			else {
				arguments.rawFacets = "";
			}
		}

		// AWS SDK 2.x - Use SearchRequest builder
		var searchRequestBuilder = createobject("java","software.amazon.awssdk.services.cloudsearchdomain.model.SearchRequest").builder()
			.queryParser(arguments.queryParser)
			.query(arguments.rawQuery)
			.start(javacast("long", arguments.maxrows * (arguments.page - 1)))
			.size(javacast("long", arguments.maxrows))
			.sort(arguments.sort);

		if (len(arguments.rawFilter)){
			searchRequestBuilder.filterQuery(arguments.rawFilter);
		}
		if (len(arguments.rawFacets)){
			searchRequestBuilder.facet(arguments.rawFacets);
		}

		var searchRequest = searchRequestBuilder.build();

		try {
			searchResponse = csdClient.search(searchRequest);
		}
		catch (java.lang.IllegalStateException e) {
			// Connection pool has been shut down — reset the cached client and retry once
			writeLog(file="cloudsearch", text="Domain client connection pool shut down — resetting and retrying search");
			structDelete(this, "domainclient");
			csdClient = getClient("domain", arguments.domain);
			searchResponse = csdClient.search(searchRequest);
		}
		catch (software.amazon.awssdk.services.cloudsearchdomain.model.SearchException e) {
			throw(message=e.message, detail=serializeJSON(duplicate(arguments)));
		}
		hits = searchResponse.hits();
		facetResult = searchResponse.facets();

		// AWS SDK 2.x - Use method names without get prefix
		stResult["time"] = searchResponse.status().timems();
		stResult["cursor"] = hits.cursor();
		stResult["items"] = querynew("objectid,typename,highlights");
		stResult["stFacets"] = {};
		if (structKeyExists(arguments,"conditions")){
			stResult["conditions"] = arguments.conditions;
		}
		stResult["rawQuery"] = arguments.rawQuery;
		stResult["queryParser"] = arguments.queryParser;
		if (structKeyExists(arguments,"filters")){
			stResult["filters"] = arguments.filters;
		}
		stResult["rawFilter"] = arguments.rawFilter;
		if (structKeyExists(arguments,"facets")){
			stResult["facets"] = arguments.facets;
		}
		stResult["rawFacets"] = arguments.rawFacets;
		stResult["recordcount"] = hits.found();
		stResult["sort"] = arguments.sort;
		stResult["page"] = arguments.page;
		stResult["maxrows"] = arguments.maxrows;
		stResult["startRow"] = (stResult.page - 1) * stResult.maxrows + 1;
		stResult["endRow"] = min(stResult.page * stResult.maxrows, stResult.recordcount);

		for (hit in hits.hit()){
			queryAddRow(stResult.items);
			querySetCell(stResult.items,"objectid",hit.id());
			querySetCell(stResult.items,"typename",hit.fields().get("typename_literal")[1]);
			querySetCell(stResult.items,"highlights",serializeJSON(duplicate(hit.highlights())));
		}

		for (key in facetResult.keySet()){
			buckets = facetResult.get(key).buckets();
			stResult["stFacets"][stIndexFields[key].property] = [];

			for (bucket in buckets){
				arrayappend(stResult["stFacets"][stIndexFields[key].property], { "value"=bucket.value(), "count"=bucket.count() });
			}
		}

		return stResult;
	}


	public string function sanitizeString(required string input) {
		var matcher = this.invalidchars.matcher( javaCast( "string", arguments.input ) );

		return matcher.replaceAll( javaCast( "string", "" ) );
	}

	/* CloudSearch Utility functions */
	private query function createIndexQuery(){
		return querynew("field,type,default_value,return,search,facet,sort,highlight,analysis_scheme,pending_deletion,state","varchar,varchar,varchar,bit,bit,bit,bit,bit,varchar,bit,varchar");
	}

	private any function insertIndexFieldOptions(required query q, required numeric row, required indexField){
		var type = arguments.indexField.indexFieldTypeAsString();
		var indexFieldOptions = {};

		switch (type) {
			case "date":
				indexFieldOptions = arguments.indexField.dateOptions();
				break;
			case "date-array":
				indexFieldOptions = arguments.indexField.dateArrayOptions();
				break;
			case "double":
				indexFieldOptions = arguments.indexField.doubleOptions();
				break;
			case "double-array":
				indexFieldOptions = arguments.indexField.doubleArrayOptions();
				break;
			case "int":
				indexFieldOptions = arguments.indexField.intOptions();
				break;
			case "int-array":
				indexFieldOptions = arguments.indexField.intArrayOptions();
				break;
			case "lat-lon":
				indexFieldOptions = arguments.indexField.latLonOptions();
				break;
			case "literal":
				indexFieldOptions = arguments.indexField.literalOptions();
				break;
			case "literal-array":
				indexFieldOptions = arguments.indexField.literalArrayOptions();
				break;
			case "text":
				indexFieldOptions = arguments.indexField.textOptions();
				break;
			case "text-array":
				indexFieldOptions = arguments.indexField.textArrayOptions();
				break;
		}

		querySetCell(arguments.q, "default_value", indexFieldOptions.defaultValue(), arguments.row);
		querySetCell(arguments.q, "return", indexFieldOptions.returnEnabled(), arguments.row);
		querySetCell(arguments.q, "search", 1, arguments.row);
		querySetCell(arguments.q, "facet", 0, arguments.row);
		querySetCell(arguments.q, "sort", 0, arguments.row);
		querySetCell(arguments.q, "highlight", 0, arguments.row);
		querySetCell(arguments.q, "analysis_scheme", "", arguments.row);

		if (not listfindnocase("text,text-array",type)){
			querySetCell(arguments.q, "search", indexFieldOptions.searchEnabled(), arguments.row);
			querySetCell(arguments.q, "facet", indexFieldOptions.facetEnabled(), arguments.row);
		}

		if (listfindnocase("date,double,int,lat-lon,literal,text",type)){
			querySetCell(arguments.q, "sort", indexFieldOptions.sortEnabled(), arguments.row);
		}

		if (listfindnocase("text,text-array",type)){
			querySetCell(arguments.q, "highlight", indexFieldOptions.highlightEnabled(), arguments.row);
			querySetCell(arguments.q, "analysis_scheme", indexFieldOptions.analysisScheme(), arguments.row);
		}
	}

	private any function createIndexFieldObject(required string field, required string type, required string default_value, required boolean return, required boolean search, required boolean facet, required boolean sort, required boolean highlight, required string analysis_scheme){
		// AWS SDK 2.x - Use IndexField builder
		var indexFieldBuilder = createobject("java","software.amazon.awssdk.services.cloudsearch.model.IndexField").builder()
			.indexFieldName(arguments.field);
		
		// AWS SDK 2.x - IndexFieldType enum expects exact string values from API
		// Convert "lat-lon" to "latlon" if needed, otherwise use as-is
		var typeValue = arguments.type;
		if (typeValue == "lat-lon") {
			typeValue = "latlon";
		}
    
    	var indexFieldType = createobject("java","software.amazon.awssdk.services.cloudsearch.model.IndexFieldType").fromValue(typeValue);
		indexFieldBuilder.indexFieldType(indexFieldType);

		var indexFieldOptions = {};

		switch (arguments.type){
			case "date":
				var dateOptionsBuilder = createobject("java","software.amazon.awssdk.services.cloudsearch.model.DateOptions").builder();
				if (len(arguments.default_value)){
					dateOptionsBuilder.defaultValue(arguments.default_value);
				}
				dateOptionsBuilder.returnEnabled(javacast("boolean",arguments.return));
				dateOptionsBuilder.sortEnabled(javacast("boolean",arguments.sort));
				indexFieldBuilder.dateOptions(dateOptionsBuilder.build());
				break;
			case "date-array":
				var dateArrayOptionsBuilder = createobject("java","software.amazon.awssdk.services.cloudsearch.model.DateArrayOptions").builder();
				if (len(arguments.default_value)){
					dateArrayOptionsBuilder.defaultValue(arguments.default_value);
				}
				dateArrayOptionsBuilder.returnEnabled(javacast("boolean",arguments.return));
				dateArrayOptionsBuilder.searchEnabled(javacast("boolean",arguments.search));
				dateArrayOptionsBuilder.facetEnabled(javacast("boolean",arguments.facet));
				indexFieldBuilder.dateArrayOptions(dateArrayOptionsBuilder.build());
				break;
			case "double":
				var doubleOptionsBuilder = createobject("java","software.amazon.awssdk.services.cloudsearch.model.DoubleOptions").builder();
				if (len(arguments.default_value)){
					doubleOptionsBuilder.defaultValue(javacast("double",arguments.default_value));
				}
				doubleOptionsBuilder.returnEnabled(javacast("boolean",arguments.return));
				doubleOptionsBuilder.searchEnabled(javacast("boolean",arguments.search));
				doubleOptionsBuilder.facetEnabled(javacast("boolean",arguments.facet));
				doubleOptionsBuilder.sortEnabled(javacast("boolean",arguments.sort));
				indexFieldBuilder.doubleOptions(doubleOptionsBuilder.build());
				break;
			case "double-array":
				var doubleArrayOptionsBuilder = createobject("java","software.amazon.awssdk.services.cloudsearch.model.DoubleArrayOptions").builder();
				if (len(arguments.default_value)){
					doubleArrayOptionsBuilder.defaultValue(javacast("double",arguments.default_value));
				}
				doubleArrayOptionsBuilder.returnEnabled(javacast("boolean",arguments.return));
				doubleArrayOptionsBuilder.searchEnabled(javacast("boolean",arguments.search));
				doubleArrayOptionsBuilder.facetEnabled(javacast("boolean",arguments.facet));
				indexFieldBuilder.doubleArrayOptions(doubleArrayOptionsBuilder.build());
				break;
			case "int":
				var intOptionsBuilder = createobject("java","software.amazon.awssdk.services.cloudsearch.model.IntOptions").builder();
				if (len(arguments.default_value)){
					intOptionsBuilder.defaultValue(javacast("int",arguments.default_value));
				}
				intOptionsBuilder.returnEnabled(javacast("boolean",arguments.return));
				intOptionsBuilder.searchEnabled(javacast("boolean",arguments.search));
				intOptionsBuilder.facetEnabled(javacast("boolean",arguments.facet));
				intOptionsBuilder.sortEnabled(javacast("boolean",arguments.sort));
				indexFieldBuilder.intOptions(intOptionsBuilder.build());
				break;
			case "int-array":
				var intArrayOptionsBuilder = createobject("java","software.amazon.awssdk.services.cloudsearch.model.IntArrayOptions").builder();
				if (len(arguments.default_value)){
					intArrayOptionsBuilder.defaultValue(javacast("int",arguments.default_value));
				}
				intArrayOptionsBuilder.returnEnabled(javacast("boolean",arguments.return));
				intArrayOptionsBuilder.searchEnabled(javacast("boolean",arguments.search));
				intArrayOptionsBuilder.facetEnabled(javacast("boolean",arguments.facet));
				indexFieldBuilder.intArrayOptions(intArrayOptionsBuilder.build());
				break;
			case "latlon": case "lat-lon":
				var latLonOptionsBuilder = createobject("java","software.amazon.awssdk.services.cloudsearch.model.LatLonOptions").builder();
				if (len(arguments.default_value)){
					latLonOptionsBuilder.defaultValue(arguments.default_value);
				}
				latLonOptionsBuilder.returnEnabled(javacast("boolean",arguments.return));
				latLonOptionsBuilder.searchEnabled(javacast("boolean",arguments.search));
				latLonOptionsBuilder.facetEnabled(javacast("boolean",arguments.facet));
				latLonOptionsBuilder.sortEnabled(javacast("boolean",arguments.sort));
				indexFieldBuilder.latLonOptions(latLonOptionsBuilder.build());
				break;
			case "literal":
				var literalOptionsBuilder = createobject("java","software.amazon.awssdk.services.cloudsearch.model.LiteralOptions").builder();
				if (len(arguments.default_value)){
					literalOptionsBuilder.defaultValue(arguments.default_value);
				}
				literalOptionsBuilder.returnEnabled(javacast("boolean",arguments.return));
				literalOptionsBuilder.searchEnabled(javacast("boolean",arguments.search));
				literalOptionsBuilder.facetEnabled(javacast("boolean",arguments.facet));
				literalOptionsBuilder.sortEnabled(javacast("boolean",arguments.sort));
				indexFieldBuilder.literalOptions(literalOptionsBuilder.build());
				break;
			case "literal-array":
				var literalArrayOptionsBuilder = createobject("java","software.amazon.awssdk.services.cloudsearch.model.LiteralArrayOptions").builder();
				if (len(arguments.default_value)){
					literalArrayOptionsBuilder.defaultValue(arguments.default_value);
				}
				literalArrayOptionsBuilder.returnEnabled(javacast("boolean",arguments.return));
				literalArrayOptionsBuilder.searchEnabled(javacast("boolean",arguments.search));
				literalArrayOptionsBuilder.facetEnabled(javacast("boolean",arguments.facet));
				indexFieldBuilder.literalArrayOptions(literalArrayOptionsBuilder.build());
				break;
			case "text":
				var textOptionsBuilder = createobject("java","software.amazon.awssdk.services.cloudsearch.model.TextOptions").builder();
				if (len(arguments.default_value)){
					textOptionsBuilder.defaultValue(arguments.default_value);
				}
				textOptionsBuilder.returnEnabled(javacast("boolean",arguments.return));
				textOptionsBuilder.sortEnabled(javacast("boolean",arguments.sort));
				textOptionsBuilder.highlightEnabled(javacast("boolean",arguments.highlight));
				if (len(arguments.analysis_scheme)){
					textOptionsBuilder.analysisScheme(arguments.analysis_scheme);
				}
				indexFieldBuilder.textOptions(textOptionsBuilder.build());
				break;
			case "text-array":
				var textArrayOptionsBuilder = createobject("java","software.amazon.awssdk.services.cloudsearch.model.TextArrayOptions").builder();
				if (len(arguments.default_value)){
					textArrayOptionsBuilder.defaultValue(arguments.default_value);
				}
				textArrayOptionsBuilder.returnEnabled(javacast("boolean",arguments.return));
				textArrayOptionsBuilder.highlightEnabled(javacast("boolean",arguments.highlight));
				if (len(arguments.analysis_scheme)){
					textArrayOptionsBuilder.analysisScheme(arguments.analysis_scheme);
				}
				indexFieldBuilder.textArrayOptions(textArrayOptionsBuilder.build());
				break;
		}

		return indexFieldBuilder.build();
	}

	public string function getRFC3339Date(required date d){
		var asUTC = dateConvert("local2utc", arguments.d);

		return dateformat(asUTC,"yyyy-mm-dd") & "T" & timeformat(asUTC,"HH:mm:ss") & "Z";
	}

	public struct function getSearchQueryFromArray(required struct stIndexFields, required array conditions, boolean bBoost=true, numeric indent=1){
		var item = {};
		var arrOut = [];

		for (item in arguments.conditions){
			if (isSimpleValue(item)){
				arrayAppend(arrOut,repeatstring(" ",arguments.indent) & item);
			}
			else if (structKeyExists(item,"property")){
				item["stIndexFields"] = arguments.stIndexFields;
				arrayAppend(arrOut,getFieldQuery(argumentCollection=item, bBoost=arguments.bBoost, indent=arguments.indent));
				structDelete(item,"stIndexFields");
			}
			else if (structKeyExists(item,"text")) {
				arrayAppend(arrOut,getTextSearchQuery(stIndexFields=arguments.stIndexFields, text=item.text, bBoost=arguments.bBoost, indent=arguments.indent));
			}
			else if (structKeyExists(item,"prefix")) {
				arrayAppend(arrOut,getPrefixSearchQuery(stIndexFields=arguments.stIndexFields, prefix=item.prefix, bBoost=arguments.bBoost, indent=arguments.indent));
			}
			else if (structKeyExists(item,"and")) {
				if (arraylen(item["and"]) gt 1){
					arrayAppend(arrOut,repeatstring(" ",arguments.indent) & "(and " & chr(10) & getSearchQueryFromArray(stIndexFields=arguments.stIndexFields, conditions=item["and"], bBoost=arguments.bBoost, indent=indent+1).query & chr(10) & repeatstring(" ",arguments.indent) & ")");
				}
				else {
					arrayAppend(arrOut,getSearchQueryFromArray(stIndexFields=arguments.stIndexFields, conditions=item["and"], bBoost=arguments.bBoost, indent=indent+1).query);
				}
			}
			else if (structKeyExists(item,"or")) {
				if (arraylen(item["or"]) gt 1){
					arrayAppend(arrOut,repeatstring(" ",arguments.indent) & "(or " & chr(10) & getSearchQueryFromArray(stIndexFields=arguments.stIndexFields, conditions=item["or"], bBoost=arguments.bBoost, indent=indent+1).query & chr(10) & repeatstring(" ",arguments.indent) & ")");
				}
				else {
					arrayAppend(arrOut,getSearchQueryFromArray(stIndexFields=arguments.stIndexFields, conditions=item["or"], bBoost=arguments.bBoost, indent=indent+1).query);
				}
			}
			else if (structKeyExists(item,"not")) {
				arrayAppend(arrOut,repeatstring(" ",arguments.indent) & "(not " & chr(10) & getSearchQueryFromArray(stIndexFields=arguments.stIndexFields, conditions=item["not"], bBoost=arguments.bBoost, indent=indent+1).query & chr(10) & repeatstring(" ",arguments.indent) & ")");
			}
		}

		return {
			"query" = arrayToList(arrOut, chr(10)),
			"parser" = "structured"
		};
	}

	private string function getTextValue(required string text){
		return "'" & replacelist(trim(rereplace(arguments.text,"\s+"," ","ALL")),"', ","\',' '") & "'";
	}

	private string function getRangeValue(required struct stIndexField){
		var str = "";
		var value = "";

		// lower bound
		if (structKeyExists(arguments,"gt")){
			str = str & "{";
			value = arguments["gt"];
		}
		else if (structKeyExists(arguments,"gte")){
			str = str & "[";
			value = arguments["gte"];
		}
		else {
			str = str & "{";
		}
		if (structKeyExists(arguments,"gt") or structKeyExists(arguments,"gte")){
			switch (arguments.stIndexField.type){
				case "int": case "int-array": case "double": case "double-array":
					str = str & value;
					break;
				case "text": case "text-array": case "literal": case "literal-array":
					str = str & "'#replace(value,"'","\'")#'";
					break;
				case "date": case "date-array":
					str = str & "'#getRFC3339Date(value)#'";
					break;
			}
		}

		str = str & ",";

		// upper bound
		if (structKeyExists(arguments,"lt")){
			value = arguments["lt"];
		}
		else if (structKeyExists(arguments,"lte")){
			value = arguments["lte"];
		}
		if (structKeyExists(arguments,"lt") or structKeyExists(arguments,"lte")){
			switch (arguments.stIndexField.type){
				case "int": case "int-array": case "double": case "double-array":
					str = str & value;
					break;
				case "text": case "text-array": case "literal": case "literal-array":
					str = str & "'#replace(value,"'","\'")#'";
					break;
				case "date": case "date-array":
					str = str & "'#getRFC3339Date(value)#'";
					break;
			}
		}
		if (structKeyExists(arguments,"lt")){
			str = str & "}";
		}
		else if (structKeyExists(arguments,"lte")){
			str = str & "]";
		}
		else {
			str = str & "}";
		}

		return str;
	}

	private string function getTextSearchQuery(required struct stIndexFields, required string text, boolean bBoost=true, numeric indent=1){
		var aSubQuery = [];
		var key = "";
		var textStr = getTextValue(arguments.text);
		var boost = "";

		for (key in arguments.stIndexFields){
			if (listfindnocase("text,text-array,literal,literal-array",arguments.stIndexFields[key].type)) {
				if (arguments.bBoost){
					boost = " boost=#arguments.stIndexFields[key].weight#";
				}

				arrayAppend(aSubQuery,repeatstring(" ",arguments.indent+1) & "(or field='#arguments.stIndexFields[key].field#'#boost# #textStr#)");
			}
		}

		return repeatstring(" ",arguments.indent) & "(or " & chr(10) & arraytolist(aSubQuery,chr(10)) & repeatstring(" ",arguments.indent) & ")";
	}

	private string function getPrefixSearchQuery(required struct stIndexFields, required string prefix, boolean bBoost=true, numeric indent=1){
		var aSubQuery = [];
		var key = "";
		var terms = listToArray(arguments.prefix, " ");
		var term = "";
		var boost = "";

		for (key in arguments.stIndexFields){
			if (listfindnocase("text,text-array,literal,literal-array",arguments.stIndexFields[key].type)) {
				if (arguments.bBoost){
					boost = " boost=#arguments.stIndexFields[key].weight#";
				}

				for (term in terms) {
					arrayAppend(aSubQuery,repeatstring(" ",arguments.indent+1) & "(prefix field='#arguments.stIndexFields[key].field#'#boost# #getTextValue(term)#)");
				}
			}
		}

		return repeatstring(" ",arguments.indent) & "(or " & chr(10) & arraytolist(aSubQuery,chr(10)) & repeatstring(" ",arguments.indent) & ")";
	}

	private string function getFieldQuery(required struct stIndexFields, required string property, boolean bBoost=true, string indent=1){
		var key = "";
		var aSubQuery = [];
		var str = "";
		var value = "";
		var boost = "";

		if (structKeyExists(arguments,"text")){
			value = getTextValue(arguments.text);
			for (key in arguments.stIndexFields){
				if (arguments.stIndexFields[key].property eq arguments.property and listfindnocase("text,text-array",arguments.stIndexFields[key].type)) {
					if (arguments.bBoost){
						boost = " boost=#arguments.stIndexFields[key].weight#";
					}
					
					arrayAppend(aSubQuery,repeatstring(" ",arguments.indent) & "(or field='#arguments.stIndexFields[key].field#'#boost# #value#)");
				}
			}
		}
		else if (structKeyExists(arguments,"term")){
			for (key in arguments.stIndexFields){
				if (arguments.stIndexFields[key].property eq arguments.property) {
					if (arguments.bBoost){
						boost = " boost=#arguments.stIndexFields[key].weight#";
					}

					switch (arguments.stIndexFields[key].type){
						case "int": case "int-array": case "double": case "double-array":
							value = arguments.term;
							break;
						case "text": case "text-array": case "literal": case "literal-array":
							value = "'#replace(arguments.term,"'","\'")#'";
							break;
						case "date": case "date-array":
							value = "'#getRFC3339Date(arguments.term)#'";
							break;
					}

					arrayAppend(aSubQuery,repeatstring(" ",arguments.indent) & "(term field='#arguments.stIndexFields[key].field#'#boost# #value#)");
				}
			}
		}
		else if (structKeyExists(arguments,"range")){
			for (key in arguments.stIndexFields){
				if (arguments.stIndexFields[key].property eq arguments.property) {
					if (arguments.bBoost){
						boost = " boost=#arguments.stIndexFields[key].weight#";
					}
					
					str = getRangeValue(stIndexField=arguments.stIndexFields[key],argumentCollection=arguments.range);

					arrayAppend(aSubQuery,repeatstring(" ",arguments.indent) & "(range field='#arguments.stIndexFields[key].field#'#boost# #str#)");
				}
			}
		}
		else if (structKeyExists(arguments,"dateafter")){
			for (key in arguments.stIndexFields){
				if (arguments.stIndexFields[key].property eq arguments.property) {
					if (arguments.bBoost){
						boost = " boost=#arguments.stIndexFields[key].weight#";
					}
					
					str = "{,'#getRFC3339Date(arguments.dateafter)#']";
					arrayAppend(aSubQuery,repeatstring(" ",arguments.indent) & "(range field='#arguments.stIndexFields[key].field#'#boost# #str#)");
				}
			}

		}

		if (arrayLen(aSubQuery) gt 1){
			return repeatstring(" ",arguments.indent) & "(or " & chr(10) & arrayToList(aSubQuery,chr(10)) & chr(10) & repeatstring(" ",arguments.indent) & ")";
		}
		else if (arraylen(aSubQuery)) {
			return aSubQuery[1];
		}
		else {
			throw(message="No query generated from arguments", detail=serializeJSON(arguments));
		}
	}


	/* CloudSearch Meta Functions */
	public query function resolveIndexFieldDifferences(string domain, query qDifferences){
		var qResult = createIndexQuery();
		var stDiff = {};

		if (not structKeyExists(arguments,"domain") or not len(arguments.domain)){
			arguments.domain = application.fapi.getConfig("cloudsearch","domain","")
		}

		if (not structKeyExists(arguments,"qDifferences")){
			arguments.qDifferences = diffIndexFields(domain=arguments.domain);
		}

		for (stDiff in arguments.qDifferences){
			switch (stDiff.action){
				case "add":
					updateIndexField(
						domain = arguments.domain,
						field = stDiff.field, 
						type = stDiff.type, 
						default_value = stDiff.default_value, 
						return = stDiff.return, 
						search = stDiff.search, 
						facet = stDiff.facet, 
						sort = stDiff.sort, 
						highlight = stDiff.highlight, 
						analysis_scheme = stDiff.analysis_scheme, 
						qResult = qResult
					);
					break;
				case "update":
					updateIndexField(
						domain = arguments.domain,
						field = stDiff.field, 
						type = stDiff.type, 
						default_value = stDiff.default_value, 
						return = stDiff.return, 
						search = stDiff.search, 
						facet = stDiff.facet, 
						sort = stDiff.sort, 
						highlight = stDiff.highlight, 
						analysis_scheme = stDiff.analysis_scheme, 
						qResult = qResult
					);
					break;
				case "delete":
					deleteIndexField(
						domain = arguments.domain,
						field = stDiff.field, 
						qResult = qResult
					);
					break;
			}
		}

		return qResult;
	}

	public query function diffIndexFields(string domain, query qOldFields, query qNewFields, string fields=""){
		var stOld = {};
		var stNew = {};
		var stField = {};
		var field = "";
		var qResult = querynew("field,type,default_value,return,search,facet,sort,highlight,analysis_scheme,action","varchar,varchar,varchar,bit,bit,bit,bit,bit,varchar,varchar");

		if (not structKeyExists(arguments,"domain") or not len(arguments.domain)){
			arguments.domain = application.fapi.getConfig("cloudsearch","domain","")
		}

		/* Default to AWS config for old, and FarCry config for new */
		if (not structKeyExists(arguments,"qOldFields")){
			arguments.qOldFields = getIndexFields(domain=arguments.domain);
		}
		if (not structKeyExists(arguments,"qNewFields")){
			arguments.qNewFields = application.fapi.getContentType("csContentType").getIndexFields();
		}

		/* Convert queries to structs for easier comparison */
		for (stField in arguments.qOldFields){
			stOld[stField.field] = duplicate(stField);
		}
		for (stField in arguments.qNewFields){
			stNew[stField.field] = duplicate(stField);
		}

		for (field in stOld){
			if (not structKeyExists(stNew,field) and (arguments.fields == "" or listfindnocase(arguments.fields,field))){
				queryAddRow(qResult);

				if (stOld[field].pending_deletion){
					/* Item is being removed as we speak */
					querySetCell(qResult,"action","wait for delete");
				}
				else {
					/* Item was removed */
					querySetCell(qResult,"action","delete");
				}
				querySetCell(qResult,"field",field);
				querySetCell(qResult,"type",stOld[field].type);
				querySetCell(qResult,"default_value",stOld[field].default_value);
				querySetCell(qResult,"return",stOld[field].return);
				querySetCell(qResult,"search",stOld[field].search);
				querySetCell(qResult,"facet",stOld[field].facet);
				querySetCell(qResult,"sort",stOld[field].sort);
				querySetCell(qResult,"highlight",stOld[field].highlight);
				querySetCell(qResult,"analysis_scheme",stOld[field].analysis_scheme);
			}
		}
		
		for (field in stNew){
			if ((not structKeyExists(stOld,field) or stOld[field].pending_deletion) and (arguments.fields == "" or listfindnocase(arguments.fields,field))){
				/* Item was added */
				queryAddRow(qResult);
				querySetCell(qResult,"field",field);
				querySetCell(qResult,"type",stNew[field].type);
				querySetCell(qResult,"default_value",stNew[field].default_value);
				querySetCell(qResult,"return",stNew[field].return);
				querySetCell(qResult,"search",stNew[field].search);
				querySetCell(qResult,"facet",stNew[field].facet);
				querySetCell(qResult,"sort",stNew[field].sort);
				querySetCell(qResult,"highlight",stNew[field].highlight);
				querySetCell(qResult,"analysis_scheme",stNew[field].analysis_scheme);
				querySetCell(qResult,"action","add");
			}
			else if (structKeyExists(stOld,field)
				and (
					stOld[field].default_value != stNew[field].default_value 
					or stOld[field].return != stNew[field].return 
					or stOld[field].search != stNew[field].search 
					or stOld[field].facet != stNew[field].facet 
					or stOld[field].sort != stNew[field].sort
					or stOld[field].highlight != stNew[field].highlight
					or stOld[field].analysis_scheme != stNew[field].analysis_scheme) 
				and (
					arguments.fields == "" 
					or listfindnocase(arguments.fields,field)
				)) {
				/* Item was changed */
				queryAddRow(qResult);
				querySetCell(qResult,"field",field);
				querySetCell(qResult,"type",stNew[field].type);
				querySetCell(qResult,"default_value",stNew[field].default_value);
				querySetCell(qResult,"return",stNew[field].return);
				querySetCell(qResult,"search",stNew[field].search);
				querySetCell(qResult,"facet",stNew[field].facet);
				querySetCell(qResult,"sort",stNew[field].sort);
				querySetCell(qResult,"highlight",stNew[field].highlight);
				querySetCell(qResult,"analysis_scheme",stNew[field].analysis_scheme);
				querySetCell(qResult,"action","update");

			}
		}

		return qResult;
	}

	public struct function getTypeIndexFields(string typename="all", boolean bUseCache=true){
		if (not structKeyExists(this.fieldCache,arguments.typename) or not arguments.bUseCache){
			updateTypeIndexFieldCache(arguments.typename);
		}

		return this.fieldCache[arguments.typename];
	}

	public void function updateTypeIndexFieldCache(string typename="all"){
		var qIndexFields = "";
		var stContentType = {};
		var stField = {};

		this.fieldCache[arguments.typename] = {};

		if (arguments.typename eq "all"){
			qIndexFields = application.fapi.getContentType(typename="csContentType").getIndexFields();
		}
		else {
			qIndexFields = application.fapi.getContentType(typename="csContentType").getIndexFields(arguments.typename);
		}

		for (stField in qIndexFields){
			this.fieldCache[arguments.typename][qIndexFields.field] = {
				"field" = qIndexFields.field,
				"property" = qIndexFields.property,
				"type" = stField.type,
				"weight" = stField.weight
			}
		}
	}

	public string function getDomainEndpoint(required string domain, boolean bUseCache=true){
		var qDomains = "";
		var stDomain = {};
		var configEndpoint = application.fapi.getConfig("cloudsearch","domainEndpoint","");

		// Cross-account: describeDomains is account-scoped and won't see the domain,
		// so prefer a configured endpoint when present.
		if (len(configEndpoint)){
			return configEndpoint;
		}

		if (not structKeyExists(this.domainEndpoints,arguments.bUseCache)){
			qDomains = getDomains();
			this.domainEndpoints = {};

			for (stDomain in qDomains){
				this.domainEndpoints[stDomain.domain] = stDomain.endpoint;
			}
		}

		if (structKeyExists(this.domainEndpoints,arguments.domain)){
			return this.domainEndpoints[arguments.domain];
		}
		else {
			throw(message="Invalid domain [#arguments.domain#]");
		}
	}

	/* Logging */
	public any function getRedis(){
		var host = application.fapi.getConfig("cloudsearch","redisHost","");
		var port = application.fapi.getConfig("cloudsearch","redisPort");
		var newclient = "";

		if (len(host) and (not structKeyExists(application.fc.lib, "redisClients") or not structkeyexists(application.fc.lib.redisClients,"#host#:#port#"))){
			param name="application.fc.lib.redisClients" default="#{}#";
			newclient = createobject("component","farcry.plugins.cloudsearch.packages.custom.cfredis");
			newclient.init(host, port);
			application.fc.lib.redisClients["#host#:#port#"] = newclient;
		}

		if (structKeyExists(application.fc.lib,"redisClients") and structKeyExists(application.fc.lib.redisClients,"#host#:#port#")){
			return application.fc.lib.redisClients["#host#:#port#"];
		}
		else {
			return false;
		}
	}

	private void function addSearchLog(required struct args){
		var redis = getRedis();
		var logsize = 0;

		if (not issimplevalue(redis)){
			logsize = application.fapi.getConfig("cloudsearch","redisLogSize");
			redis.rpush("#application.applicationname#:searchlog", '#application.fapi.dateToRFC822(now(), "+1000")#;' & serializeJSON(arguments.args));
			redis._ltrim("#application.applicationname#:searchlog", -logsize, -1);
		}
	}

	public array function getSearchLog(){
		var redis = getRedis();
		var logsize = 0;
		var aLogs = [];
		var aLogs2 = [];
		var i = 0;

		if (not issimplevalue(redis)){
			logsize = application.fapi.getConfig("cloudsearch","redisLogSize");
			aLogs = redis.lrange("#application.applicationname#:searchlog",0,logsize);
		}

		for (i=1; i<=arraylen(aLogs); i++){
			arrayprepend(aLogs2, {
				"timestamp" = application.fapi.RFC822ToDate(listfirst(aLogs[i],";")),
				"args" = deserializeJSON(listrest(aLogs[i],";"))
			});
		}

		return aLogs2;
	}


	private string function XMLHighSafe(required string text) {
		// https://devtidbits.com/2008/03/11/remove-or-clean-high-extended-ascii-characters-in-coldfusion-for-xml-safeness/
		var i = 0;
		var tmp = '';
		while(ReFind('[^\x00-\x7F]',text,i,false))
		{
		    i = ReFind('[^\x00-\x7F]',text,i,false); // discover high chr and save it's numeric string position.
		    tmp = '&##x#FormatBaseN(Asc(Mid(text,i,1)),16)#;'; // obtain the high chr and convert it to a hex numeric chr.
		    text = Insert(tmp,text,i); // insert the new hex numeric chr into the string.
		    text = RemoveChars(text,i,1); // delete the redundant high chr from string.
		    i = i+Len(tmp); // adjust the loop scan for the new chr placement, then continue the loop.
		}
		return text;
	}
	
	private string function XMLHighSafeRemove(required string text) {
		// https://devtidbits.com/2008/03/11/remove-or-clean-high-extended-ascii-characters-in-coldfusion-for-xml-safeness/
		var i = 0;
		var tmp = '';
		while(ReFind('[^\x00-\x7F]',text,i,false))
		{
		    i = ReFind('[^\x00-\x7F]',text,i,false); // discover high chr and save it's numeric string position.
		    tmp = '';
		    // tmp = '&##x#FormatBaseN(Asc(Mid(text,i,1)),16)#;'; // obtain the high chr and convert it to a hex numeric chr.
		    text = Insert(tmp,text,i); // insert the new hex numeric chr into the string.
		    text = RemoveChars(text,i,1); // delete the redundant high chr from string.
		    i = i+Len(tmp); // adjust the loop scan for the new chr placement, then continue the loop.
		}
		return text;
	}

	private string function RemoveExtraInvalidChars(required string text) {
		if (find('\u000b', ARGUMENTS.text)) {
			writeLog(file="cloudsearch",text="\u000b - stripped out");
			text = replace(ARGUMENTS.text,'\u000b','', 'all');
		}
		return text;
	}

}