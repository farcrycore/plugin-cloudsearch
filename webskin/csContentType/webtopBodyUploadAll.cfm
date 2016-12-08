<cfsetting enablecfoutputonly="true" requesttimeout="10000">

<cfimport taglib="/farcry/core/tags/formtools" prefix="ft" />

<cfif structKeyExists(url, "run")>
	<cfset count = 0 />

	<cfset qTypes = application.fapi.getContentObjects(typename="csContentType",lProperties="objectid,contentType,builtToDate",orderby="builtToDate asc") />

	<cftry>
		<cfloop query="qTypes">
			<cfset stResult = bulkImportIntoCloudSearch(objectid=qTypes.objectid, maxRows=100) />

			<cfif stResult.count>
				<cfset application.fapi.stream(type="json", content={
					"uploaded"=stResult.count,
					"typename"=qTypes.contentType,
					"typelabel"=application.fapi.getContentTypeMetadata(typename=qTypes.contentType, md="displayname", default=qTypes.contentType),
					"more"=true
				}) />
			</cfif>
		</cfloop>

		<cfcatch>
			<cfset stError = application.fc.lib.error.normalizeError(cfcatch) />
			<cfset application.fc.lib.error.logData(stError) />
			<cfset application.fapi.stream(type="json", content={ "error"=stError }) />
		</cfcatch>
	</cftry>

	<cfset application.fapi.stream(type="json", content={
		"uploaded"=0,
		"more"=false
	}) />
</cfif>

<cfoutput>
	<h1>Upload All Documents</h1>
	<textarea id="upload-log" style="width:100%" rows=20></textarea>
	<ft:buttonPanel>
		<ft:button value="Start" onClick="startUpload(); return false;" />
		<ft:button value="Stop" onClick="stopUpload(); return false;" />
		<ft:button value="Clear" onClick="clearLog(); return false;" />
	</ft:buttonPanel>

	<script>
		var status = "stopped";

		document.getElementById("upload-log").value = "";
		function logUploadMessage(message, endline) {
			endline = endline || endline === undefined;
			document.getElementById("upload-log").value += message + (endline ? "\n" : "");
		}
		function startUpload() {
			if (status === "stopped") {
				logUploadMessage("Starting ...");
				status = "running";
				runUpload();
			}
		}
		function stopUpload() {
			if (status === "running") {
				logUploadMessage("Stopping ...");
				status = "stopping";
			}
		}
		function clearLog() {
			document.getElementById("upload-log").value = "";
		}

		function runUpload() {
			if (status === "stopping") {
				logUploadMessage("Stopped");
				status = "stopped";
				return;
			}

			logUploadMessage("Uploading ... ", false);

			$j.getJSON("#application.fapi.fixURL(addvalues='run=1')#", function(data, textStatus, jqXHR) {
				if (data.error) {
					logUploadMessage(data.error.message);
					logUploadMessage(JSON.stringify(data.error));
					status = "stopped";
				}
				else if (data.more) {
					logUploadMessage("" + data.uploaded + " " + data.typelabel + " records");

					setTimeout(runUpload, 1);
				}
				else {
					logUploadMessage("no more records");
					logUploadMessage("Finished");
					status = "stopped";
				}
			});
		}
	</script>
</cfoutput>

<cfsetting enablecfoutputonly="false">