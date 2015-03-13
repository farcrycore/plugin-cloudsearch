component {
	
	public any function init(){

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

	public any function getClient(){
		var domain = application.fapi.getConfig("cloudsearch","domain","");
		var regionname = application.fapi.getConfig("cloudsearch","region","");
		var accessID = application.fapi.getConfig("cloudsearch","accessID","");
		var accessSecret = application.fapi.getConfig("cloudsearch","accessSecret","");

		var credentials = "";
		var regions = "";
		var region = "";
		var tmpClient = "";

		if (not isEnabled()){
			throw(message="The SQS settings for this application have not been set up");
		}

		if (not structkeyexists(this, "client")){
			writeLog(file="cloudsearch",text="Starting SQS client");

			credentials = createobject("java","com.amazonaws.auth.BasicAWSCredentials").init(accessID,accessSecret);
			tmpClient = createobject("java","com.amazonaws.services.cloudsearchv2.AmazonCloudSearchClient").init(credentials);

			regions = createobject("java","com.amazonaws.regions.Regions");
			region = createobject("java","com.amazonaws.regions.Region");
			writeLog(file="cloudsearch",text="Setting region to [#region.getRegion(regions.fromName(regionname)).getName()#]");
			tmpClient.setRegion(region.getRegion(regions.fromName(regionname)));

			this.client = tmpClient;
		}

		return this.client;
	}

	/* CloudSearch API Wrappers */
	public query function getDomains(){
		var csClient = getClient();
		var describeDomainsResult = csClient.describeDomains();
		var domainResult = {};
		var qResult = querynew("id,domain,created,processing,requires_index,deleted,instance_count,instance_type", "varchar,varchar,bit,bit,bit,bit,integer,varchar");

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

	public query function updateIndexField(string domain, required string field, required string type, required string default_value, required boolean return, required boolean search, required boolean facet, required boolean sort, required boolean highlight, required string analysis_scheme){
		var csClient = getClient();
		var defineIndexFieldRequest = createobject("java","com.amazonaws.services.cloudsearchv2.model.DefineIndexFieldRequest").init();
		var indexField = createIndexFieldObject(argumentCollection=arguments);
		var defineIndexFieldResponse = {};
		var indexFieldStatus = {};
		var indexStatus = {};
		var qResult = querynew("field,type,default_value,return,search,facet,sort,highlight,analysis_scheme,pending_deletion,state","varchar,varchar,varchar,bit,bit,bit,bit,bit,varchar,bit,varchar");

		if (not structKeyExists(arguments,"domain") or not len(arguments.domain)){
			arguments.domain = application.fapi.getConfig("cloudsearch","domain","")
		}

		defineIndexFieldRequest.setDomainName(arguments.domain);
		defineIndexFieldRequest.setIndexField(indexField);

		defineIndexFieldResponse = csClient.defineIndexField(defineIndexFieldRequest);

		// create a single-row query for the update result
		indexFieldStatus = defineIndexFieldResponse.getIndexField();
		queryAddRow(qResult);

		indexField = indexFieldStatus.getOptions();
		querySetCell(qResult,"field",indexField.getIndexFieldName());
		querySetCell(qResult,"type",indexField.getIndexFieldType());
		insertIndexFieldOptions(qResult, 1, indexField);

		indexStatus = indexFieldStatus.getStatus();
		querySetCell(qResult,"pending_deletion",indexStatus.getPendingDeletion());
		querySetCell(qResult,"state",indexStatus.getState());

		return qResult;
	}

	public query function deleteIndexField(string domain, required string field){
		var csClient = getClient();
		var deleteIndexFieldRequest = createobject("java","com.amazonaws.services.cloudsearchv2.model.DeleteIndexFieldRequest").init();
		var deleteIndexFieldResponse = {};
		var indexFieldStatus = {};
		var indexStatus = {};
		var qResult = querynew("field,type,default_value,return,search,facet,sort,highlight,analysis_scheme,pending_deletion,state","varchar,varchar,varchar,bit,bit,bit,bit,bit,varchar,bit,varchar");

		if (not structKeyExists(arguments,"domain") or not len(arguments.domain)){
			arguments.domain = application.fapi.getConfig("cloudsearch","domain","")
		}

		deleteIndexFieldRequest.setDomainName(arguments.domain);
		deleteIndexFieldRequest.setIndexFieldName(arguments.field);

		deleteIndexFieldResponse = csClient.deleteIndexField(deleteIndexFieldRequest);

		// create a single-row query for the update result
		indexFieldStatus = deleteIndexFieldResponse.getIndexField();
		queryAddRow(qResult);

		indexField = indexFieldStatus.getOptions();
		querySetCell(qResult,"field",indexField.getIndexFieldName());
		querySetCell(qResult,"type",indexField.getIndexFieldType());
		insertIndexFieldOptions(qResult, 1, indexField);

		indexStatus = indexFieldStatus.getStatus();
		querySetCell(qResult,"pending_deletion",indexStatus.getPendingDeletion());
		querySetCell(qResult,"state",indexStatus.getState());

		return qResult;
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

	/* CloudSearch Utility functions */
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
		querySetCell(arguments.q, "search", indexFieldOptions.getSearchEnabled(), arguments.row);
		querySetCell(arguments.q, "facet", 0, arguments.row);
		querySetCell(arguments.q, "sort", 0, arguments.row);
		querySetCell(arguments.q, "highlight", 0, arguments.row);
		querySetCell(arguments.q, "analysis_scheme", "", arguments.row);

		if (not listfindnocase("text,text-array",type)){
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
		indexFieldOptions.setSearchEnabled(javacast("boolean",arguments.search));

		if (not listfindnocase("text,text-array",arguments.type)){
			indexFieldOptions.setFacetEnabled(javacast("boolean",arguments.facet));
		}

		if (listfindnocase("date,double,int,lat-lon,literal,text",arguments.type)){
			indexFieldOptions.setSortEnabled(javacast("boolean",arguments.sort));
		}

		if (listfindnocase("text,text-array",arguments.type)){
			indexFieldOptions.setHighlightEnabled(javacast("boolean",arguments.highlight));

			if (len(arguments.analysis_scheme)){
				indexFieldOptions.setAnalysisScheme(javacast("boolean",arguments.analysis_scheme));
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


	/* CloudSearch Meta Functions */

	public query function diffIndexFields(query qOldFields, query qNewFields, string fields=""){
		var stOld = {};
		var stNew = {};
		var stField = {};
		var field = "";
		var qResult = querynew("field,type,default_value,return,search,facet,sort,highlight,analysis_scheme,action","varchar,varchar,varchar,bit,bit,bit,bit,bit,varchar,varchar");

		/* Default to AWS config for old, and FarCry config for new */
		if (not structKeyExists(arguments,"qOldFields")){
			arguments.qOldFields = getIndexFields();
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
}