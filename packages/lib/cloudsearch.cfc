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
		querySetCell(q,"label","Int");

		queryAddRow(q);
		querySetCell(q,"code","int-array");
		querySetCell(q,"label","Int Array");

		queryAddRow(q);
		querySetCell(q,"code","latlon");
		querySetCell(q,"label","Lat, Lon pair");

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

}