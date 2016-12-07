component {
	
	public any function init(){
		this.fieldCache = {};
		this.domainEndpoints = {};
		this.invalidchars = createObject("java", "java.util.regex.Pattern").compile( javaCast( "string", "/[^\u0009\u000a\u000d\u0020-\uD7FF\uE000-\uFFFD]/" ) ) />

		return this;
	}

	public query function getAllContentTypes(string lObjectIDs=""){
		var stArgs = {
			"typename" = "csContentType",
			"lProperties" = "objectid,contentType,title",
			"orderBy" = "title"
		}

		if (listLen(arguments.lObjectIds)){
			stArgs["objectid_in"] = arguments.lObjectIds;
		}

		if (bIncludeNonSearchable eq false){
			stArgs["objectid_in"] = arguments.lObjectIds;
		}
		
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
		var accessID = application.fapi.getConfig("cloudsearch","accessID","");
		var accessSecret = application.fapi.getConfig("cloudsearch","accessSecret","");

		return len(domain) AND len(regionname) AND len(accessID) AND len(accessSecret);
	}

	public any function getClient(string type="config", string domain=""){
		var domain = application.fapi.getConfig("cloudsearch","domain","");
		var regionname = application.fapi.getConfig("cloudsearch","region","");
		var accessID = application.fapi.getConfig("cloudsearch","accessID","");
		var accessSecret = application.fapi.getConfig("cloudsearch","accessSecret","");

		var credentials = "";
		var regions = "";
		var region = "";
		var tmpClient = "";
		var endpoint = "";

		if (not isEnabled()){
			throw(message="The CloudSearch settings for this application have not been set up");
		}

		if (arguments.type eq "config" and not structkeyexists(this, "client")){
			writeLog(file="cloudsearch",text="Starting CloudSearch config client");

			credentials = createobject("java","com.amazonaws.auth.BasicAWSCredentials").init(accessID,accessSecret);
			tmpClient = createobject("java","com.amazonaws.services.cloudsearchv2.AmazonCloudSearchClient").init(credentials);

			regions = createobject("java","com.amazonaws.regions.Regions");
			region = createobject("java","com.amazonaws.regions.Region");
			writeLog(file="cloudsearch",text="Setting region to [#region.getRegion(regions.fromName(regionname)).getName()#]");
			tmpClient.setRegion(region.getRegion(regions.fromName(regionname)));

			this.client = tmpClient;
		}
		if (arguments.type eq "domain" and not structkeyexists(this, "domainclient")){
			writeLog(file="cloudsearch",text="Starting CloudSearch domain client");

			credentials = createobject("java","com.amazonaws.auth.BasicAWSCredentials").init(accessID,accessSecret);
			tmpClient = createobject("java","com.amazonaws.services.cloudsearchdomain.AmazonCloudSearchDomainClient").init(credentials);

			endpoint = getDomainEndpoint(arguments.domain);
			writeLog(file="cloudsearch",text="Setting endpoint to [#endpoint#]");
			tmpClient.setEndpoint(endpoint);

			this.domainclient = tmpClient;
		}

		if (arguments.type eq "config"){
			return this.client;
		}
		if (arguments.type eq "domain"){
			return this.domainclient;
		}
	}

	/* CloudSearch API Wrappers */
	public query function getDomains(){
		var csClient = getClient();
		var describeDomainsResult = csClient.describeDomains();
		var domainResult = {};
		var qResult = querynew("id,domain,created,processing,requires_index,deleted,instance_count,instance_type,endpoint", "varchar,varchar,bit,bit,bit,bit,integer,varchar,varchar");

		for (domainResult in describeDomainsResult.getDomainStatusList()){
			queryAddRow(qResult);
			querySetCell(qResult,"id",domainResult.getDomainId());
			querySetCell(qResult,"domain",domainResult.getDomainName());
			querySetCell(qResult,"created",domainResult.getCreated());
			querySetCell(qResult,"processing",domainResult.getProcessing());
			querySetCell(qResult,"requires_index",domainResult.getRequiresIndexDocuments());
			querySetCell(qResult,"deleted",domainResult.getDeleted());
			querySetCell(qResult,"instance_count",domainResult.getSearchInstanceCount());
			querySetCell(qResult,"instance_type",domainResult.getSearchInstanceType());
			querySetCell(qResult,"endpoint",domainResult.getDocService().getEndpoint());
		}

		return qResult;
	}

	public query function getIndexFields(string domain, string fields) {
		var csClient = getClient();
		var describeIndexFieldsRequest = createobject("java","com.amazonaws.services.cloudsearchv2.model.DescribeIndexFieldsRequest").init();
		var describeIndexFieldsResponse = {};
		var indexFieldStatus = {};
		var indexField = {};
		var indexStatus = {};
		var qResult = querynew("field,type,default_value,return,search,facet,sort,highlight,analysis_scheme,pending_deletion,state","varchar,varchar,varchar,bit,bit,bit,bit,bit,varchar,bit,varchar");

		if (not structKeyExists(arguments,"domain") or not len(arguments.domain)){
			arguments.domain = application.fapi.getConfig("cloudsearch","domain","")
		}

		describeIndexFieldsRequest.setDomainName(arguments.domain);
		if (structKeyExists(arguments,"fields")){
			describeIndexFieldsRequest.setFieldNames(javaCast("string[]",listtoarray(arguments.fields)));
		}

		describeIndexFieldsResponse = csClient.describeIndexFields(describeIndexFieldsRequest);

		for (indexFieldStatus in describeIndexFieldsResponse.getIndexFields()){
			queryAddRow(qResult);

			indexField = indexFieldStatus.getOptions();
			querySetCell(qResult,"field",indexField.getIndexFieldName());
			querySetCell(qResult,"type",indexField.getIndexFieldType());
			insertIndexFieldOptions(qResult, qResult.recordcount, indexField);

			indexStatus = indexFieldStatus.getStatus();
			querySetCell(qResult,"pending_deletion",indexStatus.getPendingDeletion());
			querySetCell(qResult,"state",indexStatus.getState());
		}

		return qResult;
	}

	public query function updateIndexField(string domain, required string field, required string type, required string default_value, required boolean return, required boolean search, required boolean facet, required boolean sort, required boolean highlight, required string analysis_scheme, query qResult){
		var csClient = getClient();
		var defineIndexFieldRequest = createobject("java","com.amazonaws.services.cloudsearchv2.model.DefineIndexFieldRequest").init();
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

		defineIndexFieldRequest.setDomainName(arguments.domain);
		defineIndexFieldRequest.setIndexField(indexField);

		defineIndexFieldResponse = csClient.defineIndexField(defineIndexFieldRequest);

		// create a single-row query for the update result
		indexFieldStatus = defineIndexFieldResponse.getIndexField();
		queryAddRow(arguments.qResult);

		indexField = indexFieldStatus.getOptions();
		querySetCell(arguments.qResult,"field",indexField.getIndexFieldName());
		querySetCell(arguments.qResult,"type",indexField.getIndexFieldType());
		insertIndexFieldOptions(arguments.qResult, 1, indexField);

		indexStatus = indexFieldStatus.getStatus();
		querySetCell(arguments.qResult,"pending_deletion",indexStatus.getPendingDeletion());
		querySetCell(arguments.qResult,"state",indexStatus.getState());

		return arguments.qResult;
	}

	public query function deleteIndexField(string domain, required string field, query qResult){
		var csClient = getClient();
		var deleteIndexFieldRequest = createobject("java","com.amazonaws.services.cloudsearchv2.model.DeleteIndexFieldRequest").init();
		var deleteIndexFieldResponse = {};
		var indexFieldStatus = {};
		var indexStatus = {};
		
		if (not structKeyExists(arguments,"domain") or not len(arguments.domain)){
			arguments.domain = application.fapi.getConfig("cloudsearch","domain","")
		}

		if (not structKeyExists(arguments,"qResult")){
			arguments.qResult = createIndexQuery();
		}

		deleteIndexFieldRequest.setDomainName(arguments.domain);
		deleteIndexFieldRequest.setIndexFieldName(arguments.field);

		deleteIndexFieldResponse = csClient.deleteIndexField(deleteIndexFieldRequest);

		// create a single-row query for the update result
		indexFieldStatus = deleteIndexFieldResponse.getIndexField();
		queryAddRow(arguments.qResult);

		indexField = indexFieldStatus.getOptions();
		querySetCell(arguments.qResult,"field",indexField.getIndexFieldName());
		querySetCell(arguments.qResult,"type",indexField.getIndexFieldType());
		insertIndexFieldOptions(arguments.qResult, 1, indexField);

		indexStatus = indexFieldStatus.getStatus();
		querySetCell(arguments.qResult,"pending_deletion",indexStatus.getPendingDeletion());
		querySetCell(arguments.qResult,"state",indexStatus.getState());

		return arguments.qResult;
	}

	public array function indexDocuments(string domain){
		var csClient = getClient();
		var indexDocumentsRequest = createobject("java","com.amazonaws.services.cloudsearchv2.model.IndexDocumentsRequest").init();
		var indexDocumentsResponse = {};
		var aResult = [];
		var field = "";

		if (not structKeyExists(arguments,"domain") or not len(arguments.domain)){
			arguments.domain = application.fapi.getConfig("cloudsearch","domain","")
		}

		indexDocumentsRequest.setDomainName(arguments.domain);

		indexDocumentsResponse = csClient.indexDocuments(indexDocumentsRequest);

		for (field in indexDocumentsResponse.getFieldNames()){
			arrayAppend(aResult,field)
		}

		return aResult;
	}

	public struct function uploadDocuments(string domain, required string documents){
		var csdClient = "";
		var uploadDocumentsRequest = createobject("java","com.amazonaws.services.cloudsearchdomain.model.UploadDocumentsRequest").init();
		var uploadDocumentsResponse = {};
		var contentType = createobject("java","com.amazonaws.services.cloudsearchdomain.model.ContentType").fromValue("application/json")
		var inputStream = "";
		var aWarnings = [];
		var warning = {};
		var id = application.fapi.getUUID();
		var documentFile = "";
		var matcher = this.invalidchars.matcher( javaCast( "string", arguments.documents ) );

		if (not structKeyExists(arguments,"domain") or not len(arguments.domain)){
			arguments.domain = application.fapi.getConfig("cloudsearch","domain","")
		}

		// clean documents JSON
		arguments.documents = matcher.replaceAll( javaCast( "string", "" ) );

		// create temporary file for streaming into the SDK
		application.fc.lib.cdn.ioWriteFile(location="temp",file="/cloudsearch/documents-#id#.json",data=arguments.documents);
		documentFile = application.fc.lib.cdn.ioGetFileLocation(location="temp",file="/cloudsearch/documents-#id#.json",bRetrieve=true).path;
		inputStream = createobject("java","java.io.FileInputStream").init(documentFile);
			
		csdClient = getClient("domain", arguments.domain);

		uploadDocumentsRequest.setDocuments(inputStream);
		uploadDocumentsRequest.setContentLength(getFileInfo(documentFile).size);
		uploadDocumentsRequest.setContentType(contentType);

		uploadDocumentsResponse = csdClient.uploadDocuments(uploadDocumentsRequest);

		// remove temporary file
		application.fc.lib.cdn.ioDeleteFile(location="temp",file="/cloudsearch/documents-#id#.json");

		for (warning in uploadDocumentsResponse.getWarnings()){
			arrayAppend(aWarnings,warning.getMessage());
		}

		return {
			"adds" = uploadDocumentsResponse.getAdds(),
			"deletes" = uploadDocumentsResponse.getDeletes(),
			"status" = uploadDocumentsResponse.getStatus(),
			"warnings" = aWarnings
		};
	}

	public struct function search(string domain, string typename, string rawQuery, string queryParser="simple", string rawFilter, string rawFacets, array conditions, array filters, struct facets={}, numeric maxrows=10, numeric page=1, boolean log=true, string sort="_score desc") {
		var csdClient = "";
		var searchRequest = createobject("java","com.amazonaws.services.cloudsearchdomain.model.SearchRequest").init();
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

		searchRequest.setQueryParser(arguments.queryParser);
		searchRequest.setQuery(arguments.rawQuery);
		if (len(arguments.rawFilter)){
			searchRequest.setFilterQuery(arguments.rawFilter);
		}
		if (len(arguments.rawFacets)){
			searchRequest.setFacet(arguments.rawFacets);
		}
		searchRequest.setStart(arguments.maxrows * (arguments.page - 1));
		searchRequest.setSize(arguments.maxrows);
		searchRequest.setSort(arguments.sort);

		try {
			searchResponse = csdClient.search(searchRequest);
		}
		catch (com.amazonaws.services.cloudsearchdomain.model.SearchException e) {
			throw(message=e.message, detail=serializeJSON(duplicate(arguments)));
		}
		hits = searchResponse.getHits();
		facetResult = searchResponse.getFacets();

		stResult["time"] = searchResponse.getStatus().getTimems();
		stResult["cursor"] = hits.getCursor();
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
		stResult["recordcount"] = hits.getFound();
		stResult["page"] = arguments.page;
		stResult["maxrows"] = arguments.maxrows;

		for (hit in hits.getHit()){
			queryAddRow(stResult.items);
			querySetCell(stResult.items,"objectid",hit.getId());
			querySetCell(stResult.items,"typename",hit.getFields()["typename_literal"][1]);
			querySetCell(stResult.items,"highlights",serializeJSON(duplicate(hit.getHighlights())));
		}

		for (key in facetResult){
			buckets = facetResult[key].getBuckets();
			stResult["stFacets"][stIndexFields[key].property] = [];

			for (bucket in buckets){
				arrayappend(stResult["stFacets"][stIndexFields[key].property], { "value"=bucket.getValue(), "count"=bucket.getCount() });
			}
		}

		return stResult;
	}


	/* CloudSearch Utility functions */
	private query function createIndexQuery(){
		return querynew("field,type,default_value,return,search,facet,sort,highlight,analysis_scheme,pending_deletion,state","varchar,varchar,varchar,bit,bit,bit,bit,bit,varchar,bit,varchar");
	}

	private any function insertIndexFieldOptions(required query q, required numeric row, required indexField){
		var type = arguments.indexField.getIndexFieldType();
		var indexFieldOptions = {};

		switch (type) {
			case "date":
				indexFieldOptions = arguments.indexField.getDateOptions();
				break;
			case "date-array":
				indexFieldOptions = arguments.indexField.getDateArrayOptions();
				break;
			case "double":
				indexFieldOptions = arguments.indexField.getDoubleOptions();
				break;
			case "double-array":
				indexFieldOptions = arguments.indexField.getDoubleArrayOptions();
				break;
			case "int":
				indexFieldOptions = arguments.indexField.getIntOptions();
				break;
			case "int-array":
				indexFieldOptions = arguments.indexField.getIntArrayOptions();
				break;
			case "lat-lon":
				indexFieldOptions = arguments.indexField.getLatLonOptions();
				break;
			case "literal":
				indexFieldOptions = arguments.indexField.getLiteralOptions();
				break;
			case "literal-array":
				indexFieldOptions = arguments.indexField.getLiteralArrayOptions();
				break;
			case "text":
				indexFieldOptions = arguments.indexField.getTextOptions();
				break;
			case "text-array":
				indexFieldOptions = arguments.indexField.getTextArrayOptions();
				break;
		}

		querySetCell(arguments.q, "default_value", indexFieldOptions.getDefaultValue(), arguments.row);
		querySetCell(arguments.q, "return", indexFieldOptions.getReturnEnabled(), arguments.row);
		querySetCell(arguments.q, "search", 1, arguments.row);
		querySetCell(arguments.q, "facet", 0, arguments.row);
		querySetCell(arguments.q, "sort", 0, arguments.row);
		querySetCell(arguments.q, "highlight", 0, arguments.row);
		querySetCell(arguments.q, "analysis_scheme", "", arguments.row);

		if (not listfindnocase("text,text-array",type)){
			querySetCell(arguments.q, "search", indexFieldOptions.getSearchEnabled(), arguments.row);
			querySetCell(arguments.q, "facet", indexFieldOptions.getFacetEnabled(), arguments.row);
		}

		if (listfindnocase("date,double,int,lat-lon,literal,text",type)){
			querySetCell(arguments.q, "sort", indexFieldOptions.getSortEnabled(), arguments.row);
		}

		if (listfindnocase("text,text-array",type)){
			querySetCell(arguments.q, "highlight", indexFieldOptions.getHighlightEnabled(), arguments.row);
			querySetCell(arguments.q, "analysis_scheme", indexFieldOptions.getAnalysisScheme(), arguments.row);
		}
	}

	private any function createIndexFieldObject(required string field, required string type, required string default_value, required boolean return, required boolean search, required boolean facet, required boolean sort, required boolean highlight, required string analysis_scheme){
		var indexField = createobject("java","com.amazonaws.services.cloudsearchv2.model.IndexField").init();
		var indexFieldOptions = {};

		indexField.setIndexFieldName(arguments.field);
		indexField.setIndexFieldType(arguments.type);

		switch (arguments.type){
			case "date":
				indexFieldOptions = createobject("java","com.amazonaws.services.cloudsearchv2.model.DateOptions").init();
				break;
			case "date-array":
				indexFieldOptions = createobject("java","com.amazonaws.services.cloudsearchv2.model.DateArrayOptions").init();
				break;
			case "double":
				indexFieldOptions = createobject("java","com.amazonaws.services.cloudsearchv2.model.DoubleOptions").init();
				break;
			case "double-array":
				indexFieldOptions = createobject("java","com.amazonaws.services.cloudsearchv2.model.DoubleArrayOptions").init();
				break;
			case "int":
				indexFieldOptions = createobject("java","com.amazonaws.services.cloudsearchv2.model.IntOptions").init();
				break;
			case "int-array":
				indexFieldOptions = createobject("java","com.amazonaws.services.cloudsearchv2.model.IntArrayOptions").init();
				break;
			case "lat-lon":
				indexFieldOptions = createobject("java","com.amazonaws.services.cloudsearchv2.model.LatLonOptions").init();
				break;
			case "literal":
				indexFieldOptions = createobject("java","com.amazonaws.services.cloudsearchv2.model.LiteralOptions").init();
				break;
			case "literal-array":
				indexFieldOptions = createobject("java","com.amazonaws.services.cloudsearchv2.model.LiteralArrayOptions").init();
				break;
			case "text":
				indexFieldOptions = createobject("java","com.amazonaws.services.cloudsearchv2.model.TextOptions").init();
				break;
			case "text-array":
				indexFieldOptions = createobject("java","com.amazonaws.services.cloudsearchv2.model.TextArrayOptions").init();
				break;
		}

		if (len(arguments.default_value)){
			if (listFindNoCase("double,double-array",arguments.type)){
				indexFieldOptions.setDefaultValue(javacast("double",arguments.default_value));
			}
			else if (listFindNoCase("int,int-array",arguments.type)){
				indexFieldOptions.setDefaultValue(javacast("int",arguments.default_value));
			}
			else{
				indexFieldOptions.setDefaultValue(arguments.default_value);
			}
		}

		indexFieldOptions.setReturnEnabled(javacast("boolean",arguments.return));

		if (not listfindnocase("text,text-array",arguments.type)){
			indexFieldOptions.setSearchEnabled(javacast("boolean",arguments.search));
			indexFieldOptions.setFacetEnabled(javacast("boolean",arguments.facet));
		}

		if (listfindnocase("date,double,int,lat-lon,literal,text",arguments.type)){
			indexFieldOptions.setSortEnabled(javacast("boolean",arguments.sort));
		}

		if (listfindnocase("text,text-array",arguments.type)){
			indexFieldOptions.setHighlightEnabled(javacast("boolean",arguments.highlight));

			if (len(arguments.analysis_scheme)){
				indexFieldOptions.setAnalysisScheme(arguments.analysis_scheme);
			}
		}

		switch (arguments.type){
			case "date":
				indexField.setDateOptions(indexFieldOptions);
				break;
			case "date-array":
				indexField.setDateArrayOptions(indexFieldOptions);
				break;
			case "double":
				indexField.setDoubleOptions(indexFieldOptions);
				break;
			case "double-array":
				indexField.setDoubleArrayOptions(indexFieldOptions);
				break;
			case "int":
				indexField.setIntOptions(indexFieldOptions);
				break;
			case "int-array":
				indexField.setIntArrayOptions(indexFieldOptions);
				break;
			case "lat-lon":
				indexField.setLatLonOptions(indexFieldOptions);
				break;
			case "literal":
				indexField.setLiteralOptions(indexFieldOptions);
				break;
			case "literal-array":
				indexField.setLiteralArrayOptions(indexFieldOptions);
				break;
			case "text":
				indexField.setTextOptions(indexFieldOptions);
				break;
			case "text-array":
				indexField.setTextArrayOptions(indexFieldOptions);
				break;
		}

		return indexField;
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
			if (listfindnocase("text,text-array",arguments.stIndexFields[key].type)) {
				if (arguments.bBoost){
					boost = " boost=#arguments.stIndexFields[key].weight#";
				}

				arrayAppend(aSubQuery,repeatstring(" ",arguments.indent+1) & "(or field='#arguments.stIndexFields[key].field#'#boost# #textStr#)");
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

}